//! Image loading and saving.
//!
//! The core crate knows nothing about files. This crate is the only place that
//! touches a decoder, which keeps the physics testable without fixtures and
//! makes it obvious where colour management will eventually enter.
//!
//! Files are read as 8/16-bit RGB (the common case: a camera export or a
//! screenshot) and interpreted according to [`InputEncoding`]. On the way out
//! everything is encoded back to sRGB.
//!
//! A file is read the way up it was made: when the camera wrote an Exif
//! orientation instead of turning the pixels, the turn is applied here, so the
//! frame that reaches the model has the shape the photographer composed.

#![forbid(unsafe_code)]

use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::Path;

use image::{GenericImageView as _, ImageDecoder as _, RgbImage};
use kallo_core::{linear_to_srgb, srgb_to_linear};

/// How the values stored in the input file should be interpreted.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputEncoding {
    /// Ordinary display-referred sRGB (PNG, JPEG, most TIFFs). Decoded to linear.
    Srgb,
    /// Already linear light (a float TIFF/EXR exported from a RAW developer).
    /// Values are taken as they are.
    Linear,
}

/// A decoded image, held as linear-light `f64` RGB.
#[derive(Debug, Clone)]
pub struct Image {
    /// Width in pixels.
    pub width: u32,
    /// Height in pixels.
    pub height: u32,
    /// Row-major pixels, three channels, linear light.
    pub pixels: Vec<[f64; 3]>,
}

/// Things that can go wrong while reading or writing an image.
#[derive(Debug)]
pub enum IoError {
    /// The decoder rejected the file.
    Image(image::ImageError),
    /// The buffer length did not match the declared dimensions.
    Buffer,
    /// The PNG encoder rejected a header, a row or its finish.
    Png(png::EncodingError),
    /// The output file could not be opened or written.
    Io(std::io::Error),
}

impl std::fmt::Display for IoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Image(error) => write!(f, "image error: {error}"),
            Self::Buffer => write!(
                f,
                "could not build an output buffer from the rendered pixels"
            ),
            Self::Png(error) => write!(f, "png error: {error}"),
            Self::Io(error) => write!(f, "io error: {error}"),
        }
    }
}

impl std::error::Error for IoError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Image(error) => Some(error),
            Self::Buffer | Self::Png(_) | Self::Io(_) => None,
        }
    }
}

impl From<image::ImageError> for IoError {
    fn from(error: image::ImageError) -> Self {
        Self::Image(error)
    }
}

impl From<std::io::Error> for IoError {
    fn from(error: std::io::Error) -> Self {
        Self::Io(error)
    }
}

/// Read an image from disk and return linear-light pixels.
///
/// The file's Exif orientation is applied. A camera that is held sideways
/// writes a landscape buffer and a number saying which way up it was: a
/// renderer that ignores the number prints a portrait photograph on its side,
/// and everything measured from the frame — its shape, its grain, its
/// enlargements — is measured across the wrong axis.
pub fn load(path: impl AsRef<Path>, encoding: InputEncoding) -> Result<Image, IoError> {
    let reader = image::ImageReader::open(path).map_err(image::ImageError::IoError)?;
    load_reader(reader, encoding)
}

/// The decode itself, over any reader.
///
/// Split from [`load`] so that the reader — a file, or bytes in a test — is the
/// only thing that varies: the limits and the orientation are the same either
/// way.
///
/// The decoder's default limits are a decompression-bomb guard tuned for
/// thumbnails: a 33 MP 16-bit frame — one full-frame camera, unscaled — trips
/// them and is refused as "memory limit exceeded". A renderer whose job is to
/// eat camera files raises them to something a camera can actually produce and
/// leaves the guard in place rather than removing it.
fn load_reader<R>(reader: image::ImageReader<R>, encoding: InputEncoding) -> Result<Image, IoError>
where
    R: std::io::BufRead + std::io::Seek,
{
    let dynamic = decode_reader(reader)?;
    let rgb = dynamic.to_rgb32f();
    let (width, height) = rgb.dimensions();

    let mut pixels = Vec::with_capacity((width as usize) * (height as usize));
    for pixel in rgb.pixels() {
        let [r, g, b] = pixel.0;
        let mut out = [f64::from(r), f64::from(g), f64::from(b)];
        if encoding == InputEncoding::Srgb {
            for channel in &mut out {
                *channel = srgb_to_linear(*channel);
            }
        }
        pixels.push(out);
    }

    Ok(Image {
        width,
        height,
        pixels,
    })
}

/// The decoder's own frame, upright.
///
/// The limits and the orientation are the same for every read, whether the
/// caller wants the whole frame or a window's copy of it.
fn decode_reader<R>(reader: image::ImageReader<R>) -> Result<image::DynamicImage, IoError>
where
    R: std::io::BufRead + std::io::Seek,
{
    let mut reader = reader
        .with_guessed_format()
        .map_err(image::ImageError::IoError)?;
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(65_535);
    limits.max_image_height = Some(65_535);
    limits.max_alloc = Some(8 * 1024 * 1024 * 1024);
    reader.limits(limits.clone());

    // The orientation is metadata, and the decoder is the only thing that reads
    // it: a `DynamicImage` has already forgotten which way the camera was
    // pointing. It is asked for before the pixels so the turn happens on the
    // way in, and the rest of the pipeline only ever sees an upright frame.
    //
    // `ImageReader::decode` would skip the tag; its two steps are spelled out
    // instead: the buffer is reserved against `max_alloc` before it is
    // allocated, and the decoder is given the reserved limits — exactly what
    // the shortcut does, with the turn applied in between.
    let mut decoder = reader.into_decoder()?;
    let orientation = decoder.orientation()?;
    limits.reserve(decoder.total_bytes())?;
    decoder.set_limits(limits)?;
    let mut dynamic = image::DynamicImage::from_decoder(decoder)?;
    dynamic.apply_orientation(orientation);
    Ok(dynamic)
}

/// Read an image from disk at no more than [width], in one pass.
///
/// This is [`load`] followed by [`resize_to_width`], without the full-size f64
/// frame in between: the decoder's pixels are sampled per destination pixel and
/// only the small copy is ever built. A 33-megapixel camera file is 786 MB as
/// an f64 `Image`; the same file at the width of a window is two or three
/// megabytes, and the average is the one [`resize_to_width`] makes.
pub fn load_at_width(
    path: impl AsRef<Path>,
    encoding: InputEncoding,
    width: u32,
) -> Result<Image, IoError> {
    let reader = image::ImageReader::open(path).map_err(image::ImageError::IoError)?;
    load_reader_at_width(reader, encoding, width)
}

/// [`load_at_width`] over any reader.
fn load_reader_at_width<R>(
    reader: image::ImageReader<R>,
    encoding: InputEncoding,
    width: u32,
) -> Result<Image, IoError>
where
    R: std::io::BufRead + std::io::Seek,
{
    let dynamic = decode_reader(reader)?;
    let (source_width, source_height) = dynamic.dimensions();
    // The same answer as `resize_to_width`: asking for the width the file has,
    // or a larger one, is not a resize.
    if width == 0 || source_width == 0 || source_height == 0 || width >= source_width {
        return Ok(full_image(&dynamic, encoding));
    }
    Ok(resized(&dynamic, encoding, width))
}

/// The whole frame, as linear-light f64.
fn full_image(dynamic: &image::DynamicImage, encoding: InputEncoding) -> Image {
    let (width, height) = dynamic.dimensions();
    let source = Source::of(dynamic);
    let mut pixels = Vec::with_capacity((width as usize) * (height as usize));
    for y in 0..height {
        for x in 0..width {
            pixels.push(to_linear(source.at(x, y), encoding));
        }
    }
    Image {
        width,
        height,
        pixels,
    }
}

/// The frame at [width], averaged while it is still the decoder's pixels.
///
/// The arithmetic is [`resize_to_width`]'s, pixel for pixel: the same source
/// rectangle per destination pixel, summed in the same row-major order, so a
/// caller cannot tell which path made the copy.
fn resized(dynamic: &image::DynamicImage, encoding: InputEncoding, width: u32) -> Image {
    let (source_width, source_height) = dynamic.dimensions();
    let source = Source::of(dynamic);
    let scale = f64::from(source_width) / f64::from(width);
    let height = ((f64::from(source_height) / scale).round() as u32).max(1);
    let mut pixels = Vec::with_capacity((width as usize) * (height as usize));

    for y in 0..height {
        let top = f64::from(y) * f64::from(source_height) / f64::from(height);
        let bottom = f64::from(y + 1) * f64::from(source_height) / f64::from(height);
        let y0 = (top.floor() as u32).min(source_height - 1);
        let y1 = (bottom.ceil() as u32).clamp(y0 + 1, source_height);
        for x in 0..width {
            let left = f64::from(x) * f64::from(source_width) / f64::from(width);
            let right = f64::from(x + 1) * f64::from(source_width) / f64::from(width);
            let x0 = (left.floor() as u32).min(source_width - 1);
            let x1 = (right.ceil() as u32).clamp(x0 + 1, source_width);

            let mut sum = [0.0f64; 3];
            let mut count = 0.0f64;
            for source_y in y0..y1 {
                for source_x in x0..x1 {
                    let pixel = to_linear(source.at(source_x, source_y), encoding);
                    sum[0] += pixel[0];
                    sum[1] += pixel[1];
                    sum[2] += pixel[2];
                    count += 1.0;
                }
            }
            pixels.push([sum[0] / count, sum[1] / count, sum[2] / count]);
        }
    }

    Image {
        width,
        height,
        pixels,
    }
}

/// A decoded frame, sampled one pixel at a time.
///
/// The decoder keeps the file's own channels — 8-bit RGB, 16-bit RGBA, float —
/// and [`load`] converts the whole thing to f32 before it converts again to
/// f64. This reads the channels where they are, in the conversion
/// `DynamicImage::to_rgb32f` would make.
struct Source<'a> {
    pixels: Pixels<'a>,
    width: usize,
}

enum Pixels<'a> {
    Rgb8(&'a [u8]),
    Rgba8(&'a [u8]),
    Luma8(&'a [u8]),
    LumaA8(&'a [u8]),
    Rgb16(&'a [u16]),
    Rgba16(&'a [u16]),
    Luma16(&'a [u16]),
    LumaA16(&'a [u16]),
    Rgb32F(&'a [f32]),
    Rgba32F(&'a [f32]),
}

impl<'a> Source<'a> {
    fn of(dynamic: &'a image::DynamicImage) -> Self {
        use image::DynamicImage as Decoded;
        let pixels = match dynamic {
            Decoded::ImageLuma8(image) => Pixels::Luma8(image.as_raw()),
            Decoded::ImageLumaA8(image) => Pixels::LumaA8(image.as_raw()),
            Decoded::ImageRgb8(image) => Pixels::Rgb8(image.as_raw()),
            Decoded::ImageRgba8(image) => Pixels::Rgba8(image.as_raw()),
            Decoded::ImageLuma16(image) => Pixels::Luma16(image.as_raw()),
            Decoded::ImageLumaA16(image) => Pixels::LumaA16(image.as_raw()),
            Decoded::ImageRgb16(image) => Pixels::Rgb16(image.as_raw()),
            Decoded::ImageRgba16(image) => Pixels::Rgba16(image.as_raw()),
            Decoded::ImageRgb32F(image) => Pixels::Rgb32F(image.as_raw()),
            Decoded::ImageRgba32F(image) => Pixels::Rgba32F(image.as_raw()),
            // `DynamicImage` is non-exhaustive; the decoder in this crate
            // produces only the layouts above.
            _ => unreachable!("a decoded image has one of the known layouts"),
        };
        Self {
            pixels,
            width: dynamic.width() as usize,
        }
    }

    /// One upright pixel, as the three f32 channels the model reads.
    #[inline]
    fn at(&self, x: u32, y: u32) -> [f32; 3] {
        let at = y as usize * self.width + x as usize;
        match &self.pixels {
            Pixels::Rgb8(channels) => {
                let at = at * 3;
                [
                    sample8(channels[at]),
                    sample8(channels[at + 1]),
                    sample8(channels[at + 2]),
                ]
            }
            Pixels::Rgba8(channels) => {
                let at = at * 4;
                [
                    sample8(channels[at]),
                    sample8(channels[at + 1]),
                    sample8(channels[at + 2]),
                ]
            }
            Pixels::Luma8(channels) => {
                let grey = luma8(channels[at]);
                [grey; 3]
            }
            Pixels::LumaA8(channels) => {
                let grey = luma8(channels[at * 2]);
                [grey; 3]
            }
            Pixels::Rgb16(channels) => {
                let at = at * 3;
                [
                    sample16(channels[at]),
                    sample16(channels[at + 1]),
                    sample16(channels[at + 2]),
                ]
            }
            Pixels::Rgba16(channels) => {
                let at = at * 4;
                [
                    sample16(channels[at]),
                    sample16(channels[at + 1]),
                    sample16(channels[at + 2]),
                ]
            }
            Pixels::Luma16(channels) => {
                let grey = luma16(channels[at]);
                [grey; 3]
            }
            Pixels::LumaA16(channels) => {
                let grey = luma16(channels[at * 2]);
                [grey; 3]
            }
            Pixels::Rgb32F(channels) => {
                let at = at * 3;
                [channels[at], channels[at + 1], channels[at + 2]]
            }
            Pixels::Rgba32F(channels) => {
                let at = at * 4;
                [channels[at], channels[at + 1], channels[at + 2]]
            }
        }
    }
}

/// An 8-bit sample as the image crate converts it to f32.
#[inline]
fn sample8(value: u8) -> f32 {
    (value as f32 / u8::MAX as f32).clamp(0.0, 1.0)
}

/// A 16-bit sample as the image crate converts it to f32.
#[inline]
fn sample16(value: u16) -> f32 {
    (value as f32 / u16::MAX as f32).clamp(0.0, 1.0)
}

/// A grey sample as the image crate converts it to f32.
///
/// Grey is expanded to RGB through the decoder's colour-space fallback, and
/// that path multiplies by a reciprocal rather than dividing: the last bit of
/// a luma pixel differs from the last bit of the same value in an RGB file,
/// and this read must match the decoder's own answer, not a tidier one.
#[inline]
fn luma8(value: u8) -> f32 {
    const RECIPROCAL: f32 = 1.0 / u8::MAX as f32;
    value as f32 * RECIPROCAL
}

/// A 16-bit grey sample, as the same fallback converts it.
#[inline]
fn luma16(value: u16) -> f32 {
    const RECIPROCAL: f32 = 1.0 / u16::MAX as f32;
    value as f32 * RECIPROCAL
}

/// One source pixel in linear light, as [`load`] would have stored it.
#[inline]
fn to_linear(pixel: [f32; 3], encoding: InputEncoding) -> [f64; 3] {
    let mut out = [
        f64::from(pixel[0]),
        f64::from(pixel[1]),
        f64::from(pixel[2]),
    ];
    if encoding == InputEncoding::Srgb {
        for channel in &mut out {
            *channel = srgb_to_linear(*channel);
        }
    }
    out
}

/// Resample an image to a width, keeping its shape.
///
/// An area average and not a bilinear tap: shrinking is the case that matters
/// here — a camera file meeting a window — and a tap at a scale of five skips
/// four pixels in every five. Averaging what each destination pixel covers is
/// the filter that answers the question the pixel asks: how much light was in
/// this patch of the frame.
///
/// The pixels are linear light, so they average the way light does. Asking for
/// a width the image already has, or a larger one, returns it unchanged: this
/// is a resize down, and nothing here invents detail.
#[must_use]
pub fn resize_to_width(image: &Image, width: u32) -> Image {
    if width == 0 || image.width == 0 || image.height == 0 || width >= image.width {
        return image.clone();
    }
    let scale = f64::from(image.width) / f64::from(width);
    let height = ((f64::from(image.height) / scale).round() as u32).max(1);
    let mut pixels = vec![[0.0f64; 3]; (width * height) as usize];

    for y in 0..height {
        let top = f64::from(y) * f64::from(image.height) / f64::from(height);
        let bottom = f64::from(y + 1) * f64::from(image.height) / f64::from(height);
        let y0 = (top.floor() as u32).min(image.height - 1);
        let y1 = (bottom.ceil() as u32).clamp(y0 + 1, image.height);
        for x in 0..width {
            let left = f64::from(x) * f64::from(image.width) / f64::from(width);
            let right = f64::from(x + 1) * f64::from(image.width) / f64::from(width);
            let x0 = (left.floor() as u32).min(image.width - 1);
            let x1 = (right.ceil() as u32).clamp(x0 + 1, image.width);

            let mut sum = [0.0f64; 3];
            let mut count = 0.0f64;
            for source_y in y0..y1 {
                let row = (source_y * image.width) as usize;
                for source_x in x0..x1 {
                    let pixel = image.pixels[row + source_x as usize];
                    sum[0] += pixel[0];
                    sum[1] += pixel[1];
                    sum[2] += pixel[2];
                    count += 1.0;
                }
            }
            pixels[(y * width + x) as usize] = [sum[0] / count, sum[1] / count, sum[2] / count];
        }
    }

    Image {
        width,
        height,
        pixels,
    }
}

/// Encode linear-light pixels to packed sRGB, three channels per pixel.
///
/// This is the same conversion [`save`] writes: a preview that hands pixels to
/// a window and a print that writes a PNG must be the same colour, or the
/// person is choosing a time from a picture the print will not match.
#[must_use]
pub fn to_rgb8(image: &Image) -> Vec<u8> {
    let mut buffer = Vec::with_capacity(image.pixels.len() * 3);
    for pixel in &image.pixels {
        for channel in pixel {
            let encoded = linear_to_srgb(*channel);
            buffer.push((encoded * 255.0).round().clamp(0.0, 255.0) as u8);
        }
    }
    buffer
}

/// Encode linear-light pixels to sRGB with an opaque alpha channel.
///
/// A window's texture wants four channels; the model has three and no
/// transparency, because a print is paper and there is nothing behind it.
#[must_use]
pub fn to_rgba8(image: &Image) -> Vec<u8> {
    let rgb = to_rgb8(image);
    let mut buffer = Vec::with_capacity(rgb.len() / 3 * 4);
    for pixel in rgb.chunks_exact(3) {
        buffer.extend_from_slice(pixel);
        buffer.push(255);
    }
    buffer
}

/// Encode linear-light pixels to sRGB and write them to disk.
///
/// The container is chosen from the file extension, so `out.png` and
/// `out.tiff` both work.
pub fn save(path: impl AsRef<Path>, image: &Image) -> Result<(), IoError> {
    let buffer = to_rgb8(image);
    let rgb = RgbImage::from_raw(image.width, image.height, buffer).ok_or(IoError::Buffer)?;
    rgb.save(path)?;
    Ok(())
}

/// [`save`], reporting how much of the file has been written.
///
/// A PNG is encoded a row at a time — the same rows [`save`] would hand the
/// image crate — so the fraction is about bytes actually written and not about
/// elapsed time. A container without a row-level hook falls back to [`save`]
/// and reports completion once.
pub fn save_with_progress(
    path: impl AsRef<Path>,
    image: &Image,
    progress: &mut dyn FnMut(f32),
) -> Result<(), IoError> {
    let path = path.as_ref();
    let png = path
        .extension()
        .and_then(std::ffi::OsStr::to_str)
        .is_some_and(|extension| extension.eq_ignore_ascii_case("png"));
    if !png {
        save(path, image)?;
        progress(1.0);
        return Ok(());
    }
    save_png_with_progress(path, image, progress)
}

/// A PNG written row by row, so the caller can move while its file is made.
fn save_png_with_progress(
    path: &Path,
    image: &Image,
    progress: &mut dyn FnMut(f32),
) -> Result<(), IoError> {
    let file = File::create(path)?;
    let mut encoder = png::Encoder::new(BufWriter::new(file), image.width, image.height);
    encoder.set_color(png::ColorType::Rgb);
    encoder.set_depth(png::BitDepth::Eight);
    // The image crate saves a PNG at its default (fast) compression with the
    // adaptive filter; a print written here must be the same kind of file.
    encoder.set_compression(png::Compression::Fast);
    encoder.set_filter(png::Filter::Adaptive);
    let mut writer = encoder.write_header().map_err(IoError::Png)?;
    let mut stream = writer.stream_writer().map_err(IoError::Png)?;
    let stride = image.width as usize * 3;
    let mut row = Vec::with_capacity(stride);
    for y in 0..image.height as usize {
        row.clear();
        for pixel in &image.pixels[y * image.width as usize..(y + 1) * image.width as usize] {
            for channel in pixel {
                let encoded = linear_to_srgb(*channel);
                row.push((encoded * 255.0).round().clamp(0.0, 255.0) as u8);
            }
        }
        stream.write_all(&row)?;
        progress(0.2 + 0.79 * (y as f32 + 1.0) / image.height as f32);
    }
    stream.finish().map_err(IoError::Png)?;
    writer.finish().map_err(IoError::Png)?;
    progress(1.0);
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::*;

    /// A camera's portrait JPEG: a landscape buffer, an Exif tag saying which
    /// way up it was held.
    ///
    /// Eight columns dark on the left and bright on the right, four rows, so
    /// that the turn is visible in the shape and in which end of the frame the
    /// light is on.
    fn oriented_jpeg(orientation: u16) -> Vec<u8> {
        const WIDTH: u32 = 8;
        const HEIGHT: u32 = 4;
        let mut pixels = Vec::with_capacity((WIDTH * HEIGHT * 3) as usize);
        for _ in 0..HEIGHT {
            for x in 0..WIDTH {
                let value = if x < WIDTH / 2 { 0 } else { 255 };
                pixels.extend_from_slice(&[value, value, value]);
            }
        }
        let mut jpeg = Vec::new();
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut jpeg, 100)
            .encode(&pixels, WIDTH, HEIGHT, image::ExtendedColorType::Rgb8)
            .expect("encode");

        // The shortest Exif a camera writes: a little-endian TIFF header and one
        // IFD entry, `Orientation` (0x0112), type SHORT, one value.
        let mut tiff = Vec::new();
        tiff.extend_from_slice(b"II");
        tiff.extend_from_slice(&42u16.to_le_bytes());
        tiff.extend_from_slice(&8u32.to_le_bytes());
        tiff.extend_from_slice(&1u16.to_le_bytes());
        tiff.extend_from_slice(&0x0112u16.to_le_bytes());
        tiff.extend_from_slice(&3u16.to_le_bytes());
        tiff.extend_from_slice(&1u32.to_le_bytes());
        tiff.extend_from_slice(&orientation.to_le_bytes());
        tiff.extend_from_slice(&[0, 0]);
        tiff.extend_from_slice(&0u32.to_le_bytes());

        let mut payload = b"Exif\x00\x00".to_vec();
        payload.extend_from_slice(&tiff);
        let length = u16::try_from(payload.len() + 2).expect("a short segment");

        // APP1 goes immediately after the start-of-image marker, where a camera
        // puts it and where the decoder looks.
        let mut out = Vec::with_capacity(jpeg.len() + payload.len() + 4);
        out.extend_from_slice(&jpeg[..2]);
        out.extend_from_slice(&[0xFF, 0xE1]);
        out.extend_from_slice(&length.to_be_bytes());
        out.extend_from_slice(&payload);
        out.extend_from_slice(&jpeg[2..]);
        out
    }

    fn read(jpeg: &[u8]) -> Image {
        let reader = image::ImageReader::new(Cursor::new(jpeg))
            .with_guessed_format()
            .expect("guess the format");
        load_reader(reader, InputEncoding::Srgb).expect("decode")
    }

    #[test]
    fn a_portrait_photograph_is_read_the_way_up() {
        // 6 is "rotate 90° clockwise to display", the tag a camera held on its
        // side writes.
        let upright = read(&oriented_jpeg(6));
        assert_eq!((upright.width, upright.height), (4, 8));

        // Turning the buffer clockwise brings the dark left half to the top.
        // The rows on either side of the seam are left to the codec.
        for y in 0..8u32 {
            for x in 0..4u32 {
                let value = upright.pixels[(y * 4 + x) as usize][0];
                match y {
                    0..=1 => assert!(value < 0.05, "row {y} should be dark, was {value}"),
                    6..=7 => assert!(value > 0.7, "row {y} should be bright, was {value}"),
                    _ => {}
                }
            }
        }
    }

    #[test]
    fn a_file_that_is_already_the_way_up_is_left_alone() {
        let plain = read(&oriented_jpeg(1));
        assert_eq!((plain.width, plain.height), (8, 4));
    }

    #[test]
    fn a_resize_keeps_the_shape_and_the_light() {
        let image = Image {
            width: 6,
            height: 4,
            pixels: vec![[0.5, 0.25, 1.0]; 24],
        };
        let half = resize_to_width(&image, 3);
        assert_eq!((half.width, half.height), (3, 2));
        assert_eq!(half.pixels.len(), 6);
        for pixel in &half.pixels {
            assert!((pixel[0] - 0.5).abs() < 1e-9);
            assert!((pixel[1] - 0.25).abs() < 1e-9);
            assert!((pixel[2] - 1.0).abs() < 1e-9);
        }
    }

    #[test]
    fn a_resize_down_averages_and_a_resize_up_does_nothing() {
        let image = Image {
            width: 4,
            height: 2,
            pixels: [[
                [0.0, 0.0, 0.0],
                [1.0, 1.0, 1.0],
                [0.0, 0.0, 0.0],
                [1.0, 1.0, 1.0],
            ]; 2]
                .concat(),
        };
        let half = resize_to_width(&image, 2);
        // Two columns of black and white averaged into one of mid grey, twice.
        for pixel in &half.pixels {
            assert!((pixel[0] - 0.5).abs() < 1e-9, "{pixel:?}");
        }
        let same = resize_to_width(&image, 4);
        assert_eq!((same.width, same.height), (4, 2));
        assert_eq!(same.pixels, image.pixels);
        let bigger = resize_to_width(&image, 9);
        assert_eq!((bigger.width, bigger.height), (4, 2));
    }

    #[test]
    fn encoding_flag_round_trips_mid_grey() {
        let linear = srgb_to_linear(0.5);
        assert!((linear_to_srgb(linear) - 0.5).abs() < 1e-9);
    }
    #[test]
    fn a_png_written_with_progress_reads_back_and_reaches_the_end() {
        let image = Image {
            width: 3,
            height: 2,
            pixels: vec![
                [0.0, 0.1, 0.2],
                [0.3, 0.4, 0.5],
                [0.6, 0.7, 0.8],
                [0.2, 0.3, 0.4],
                [0.5, 0.6, 0.7],
                [0.8, 0.9, 1.0],
            ],
        };
        let path = std::env::temp_dir().join(format!(
            "kallo-save-progress-{}-{}.png",
            std::process::id(),
            line!()
        ));
        let mut steps = Vec::new();
        save_with_progress(&path, &image, &mut |fraction| steps.push(fraction))
            .expect("the png is written");
        assert!(!steps.is_empty(), "a written file reports its rows");
        assert!(
            steps.windows(2).all(|pair| pair[0] <= pair[1]),
            "the rows are reported in order: {steps:?}"
        );
        assert_eq!(steps.last().copied(), Some(1.0));

        let loaded = load(&path, InputEncoding::Srgb).expect("the png reads back");
        assert_eq!((loaded.width, loaded.height), (image.width, image.height));
        for (expected, actual) in to_rgb8(&image).iter().zip(to_rgb8(&loaded)) {
            assert!(
                expected.abs_diff(actual) <= 1,
                "a row survived the encoder: {expected} against {actual}"
            );
        }
        let _ = std::fs::remove_file(path);
    }

    /// A file read at a width must be the file read and then resized.
    ///
    /// The one-pass read is an optimisation, not a second sampler: a window
    /// that drew a different average would be looking at another photograph.
    /// The fixtures cover the channel layouts a camera actually writes.
    #[test]
    fn reading_at_a_width_is_reading_then_resizing() {
        let folder = std::env::temp_dir().join(format!(
            "kallo-read-at-width-{}-{}",
            std::process::id(),
            line!()
        ));
        std::fs::create_dir_all(&folder).expect("a scratch folder");

        let rgb8 = image::RgbImage::from_fn(6, 5, |x, y| {
            image::Rgb([
                (x * 41 + y * 7) as u8,
                (x * 13 + y * 29 + 50) as u8,
                (x * 3 + y * 37 + 100) as u8,
            ])
        });
        let rgba8 = image::RgbaImage::from_fn(6, 5, |x, y| {
            image::Rgba([
                (x * 53 + y * 3) as u8,
                (x * 11 + y * 19 + 40) as u8,
                (x * 7 + y * 47 + 90) as u8,
                (x * 17 + y * 23) as u8,
            ])
        });
        let luma8 =
            image::GrayImage::from_fn(6, 5, |x, y| image::Luma([(x * 31 + y * 43 + 7) as u8]));
        let rgb16 = image::ImageBuffer::<image::Rgb<u16>, Vec<u16>>::from_fn(6, 5, |x, y| {
            image::Rgb([
                (x * 1009 + y * 71) as u16,
                (x * 337 + y * 2019 + 4000) as u16,
                (x * 7 + y * 655) as u16,
            ])
        });
        let rgba16 = image::ImageBuffer::<image::Rgba<u16>, Vec<u16>>::from_fn(6, 5, |x, y| {
            image::Rgba([
                (x * 2003 + y * 61) as u16,
                (x * 409 + y * 3079 + 900) as u16,
                (x * 19 + y * 857) as u16,
                (x * 211 + y * 3) as u16,
            ])
        });
        let fixtures: [(&str, image::DynamicImage); 5] = [
            ("rgb8.png", image::DynamicImage::ImageRgb8(rgb8)),
            ("rgba8.png", image::DynamicImage::ImageRgba8(rgba8)),
            ("luma8.png", image::DynamicImage::ImageLuma8(luma8)),
            ("rgb16.png", image::DynamicImage::ImageRgb16(rgb16)),
            ("rgba16.png", image::DynamicImage::ImageRgba16(rgba16)),
        ];

        for (name, fixture) in fixtures {
            let path = folder.join(name);
            fixture.save(&path).expect("the fixture is written");
            for encoding in [InputEncoding::Srgb, InputEncoding::Linear] {
                let full = load(&path, encoding).expect("the fixture reads");
                for width in [1, 2, 3, 5, 6, 13] {
                    let expected = resize_to_width(&full, width);
                    let actual = load_at_width(&path, encoding, width)
                        .expect("the fixture reads at a width");
                    assert_eq!(
                        (actual.width, actual.height),
                        (expected.width, expected.height),
                        "{name} at {width}, {encoding:?}"
                    );
                    assert_eq!(
                        actual.pixels.len(),
                        expected.pixels.len(),
                        "{name} at {width}, {encoding:?}"
                    );
                    for (index, (expected, actual)) in
                        expected.pixels.iter().zip(&actual.pixels).enumerate()
                    {
                        assert_eq!(
                            actual, expected,
                            "{name} at {width}, {encoding:?}: pixel {index}"
                        );
                    }
                }
            }
        }

        let _ = std::fs::remove_dir_all(&folder);
    }

    /// The orientation is applied before the average, as it is on a full read.
    #[test]
    fn reading_a_turned_photograph_at_a_width_is_the_way_up() {
        let jpeg = oriented_jpeg(6);
        let upright = read(&jpeg);
        for width in [1, 2, 3, 4, 8, 11] {
            let reader = image::ImageReader::new(Cursor::new(jpeg.as_slice()))
                .with_guessed_format()
                .expect("guess the format");
            let small = load_reader_at_width(reader, InputEncoding::Srgb, width)
                .expect("decode at a width");
            let expected = resize_to_width(&upright, width);
            assert_eq!(
                (small.width, small.height),
                (expected.width, expected.height),
                "at {width}"
            );
            for (index, (expected, actual)) in expected.pixels.iter().zip(&small.pixels).enumerate()
            {
                assert_eq!(actual, expected, "at {width}: pixel {index}");
            }
        }
    }
}
