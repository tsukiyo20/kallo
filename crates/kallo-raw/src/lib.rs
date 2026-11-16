//! Camera raw decoding for `kallo`.
//!
//! # The seam
//!
//! A camera raw file is not an image. It is a sensor mosaic plus a small pile
//! of metadata — black level, white balance as shot, the camera's own colour
//! matrix, and a tag saying which way up the camera was held — and turning it
//! into pixels means demosaicing and colour conversion. That work is a decoder,
//! and this crate is where the decoder lives: the rest of the program sees an
//! [`Image`] in scene-referred linear light, the same shape [`kallo_io`]
//! returns for a TIFF.
//!
//! The engine is [`flashraw`] 0.3, which is MIT OR Apache-2.0. The previous
//! engine, `rawler`, was LGPL-2.1 and kept this crate outside the workspace so
//! that a default build carried no copyleft code; that fence is gone with the
//! engine. Swapping decoders is a change to this file and its tests, not to the
//! CLI or the renderer.
//!
//! # What comes out
//!
//! Scene-referred linear sRGB, in the same shape as
//! [`kallo_io::load`]'s linear output, which is what the renderer's
//! spectral front end wants. That is the whole point of reading raw in the
//! first place: a camera JPEG has a tone curve, a white balance and sharpening
//! baked in, so feeding one to a film simulator means simulating film on an
//! image that has already been developed.

#![forbid(unsafe_code)]

use std::path::Path;

use flashraw::{DecodeOptions, Demosaic, FlashRaw, OutputFormat};
use kallo_io::Image;

/// File extensions this crate claims.
///
/// The list is the set of formats the decoder handles, using the extensions
/// those cameras actually write. It exists so the CLI can decide whether a file
/// is a raw by name before trying anything expensive.
pub const EXTENSIONS: &[&str] = &[
    "3fr", "ari", "arw", "cr2", "cr3", "crw", "dcr", "dcs", "dng", "erf", "iiq", "kdc", "mef",
    "mos", "mrw", "nef", "nkd", "nrw", "orf", "pef", "qtk", "raf", "raw", "rw2", "srw", "tfr",
    "x3f",
];

/// Whether a path looks like a camera raw by its extension.
///
/// Case-insensitive, and the file need not exist — this is a routing decision,
/// not a check.
#[must_use]
pub fn handles(path: impl AsRef<Path>) -> bool {
    path.as_ref()
        .extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            let lower = extension.to_ascii_lowercase();
            EXTENSIONS.contains(&lower.as_str())
        })
}

/// Things that can go wrong decoding a raw file.
#[derive(Debug)]
pub enum RawError {
    /// The decoder could not open or develop the file.
    Decode(flashraw::Error),
    /// The decoded pixels did not match the declared dimensions.
    Buffer,
}

impl std::fmt::Display for RawError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Decode(error) => write!(f, "raw decode failed: {error}"),
            Self::Buffer => write!(f, "decoded pixel count does not match the image size"),
        }
    }
}

impl std::error::Error for RawError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Decode(error) => Some(error),
            Self::Buffer => None,
        }
    }
}

/// Decode a camera raw file to scene-referred linear sRGB.
///
/// The steps are the ones a raw developer takes and no more:
///
/// * black level off and the samples normalised to the white level;
/// * demosaic (adaptive on Bayer, so the interpolation follows the edges the
///   sensor did not measure directly);
/// * crop to the active area;
/// * white balance with the as-shot coefficients in the file;
/// * the camera's own colour matrix to sRGB primaries.
///
/// The sRGB transfer curve is deliberately **not** applied. The renderer wants
/// linear light; applying the curve here would put back exactly the tone
/// mapping that reading raw is meant to avoid.
///
/// The file's Exif orientation is applied last, after the develop: the sensor is
/// read the way it lies, and a camera held on its side writes a landscape
/// mosaic with a tag saying which way up it was. The decoder's linear output
/// keeps the sensor orientation and reports it for exactly this reason; the
/// turn is a permutation of whole pixels, so nothing is resampled a second time.
pub fn load(path: impl AsRef<Path>) -> Result<Image, RawError> {
    let frame = decode(path)?;
    let (samples, width, height, orientation) = frame_pixels(&frame)?;
    Ok(image_from(samples, width, height, orientation))
}

/// Read a camera raw at no more than [width], in one pass.
///
/// [`load`] builds the whole decoded frame as f64 before [`kallo_io::resize_to_width`]
/// takes the window's copy: a 33-megapixel raw is 786 MB of f64, and the bench
/// wants 760 pixels of it. This averages the decoder's f32 samples straight
/// into the small copy, with the same rectangles and sums the resize would
/// make, so the pixels are the ones [`load`] then [`kallo_io::resize_to_width`]
/// would have produced. The orientation is applied while sampling: the turn is
/// a permutation of whole pixels, and it commutes with an area average.
pub fn load_at_width(path: impl AsRef<Path>, width: u32) -> Result<Image, RawError> {
    let frame = decode(path)?;
    let (samples, source_width, source_height, orientation) = frame_pixels(&frame)?;
    let upright_width = if orientation.swaps_axes() {
        source_height
    } else {
        source_width
    };
    // The same answer as `kallo_io::resize_to_width`: a width the frame already
    // has, or a larger one, is not a resize.
    if width == 0 || width >= upright_width {
        return Ok(image_from(
            samples,
            source_width,
            source_height,
            orientation,
        ));
    }
    Ok(downsample(
        samples,
        source_width,
        source_height,
        orientation,
        width,
    ))
}

/// Decode the file's sensor data into linear-light f32 samples.
fn decode(path: impl AsRef<Path>) -> Result<flashraw::RawFrame, RawError> {
    let raw = FlashRaw::open_path(path).map_err(RawError::Decode)?;
    raw.decode(DecodeOptions {
        output: OutputFormat::LinearRgbF32,
        // `Auto` is adaptive interpolation on a Bayer mosaic. The cost over
        // bilinear is a few tens of milliseconds on a 33 MP frame, and it
        // is the difference between colour detail and zippers.
        demosaic: Demosaic::Auto,
        ..Default::default()
    })
    .map_err(RawError::Decode)
}

/// The decoded samples, checked, with the orientation still to apply.
fn frame_pixels(frame: &flashraw::RawFrame) -> Result<(&[f32], u32, u32, Orientation), RawError> {
    let (width, height) = (frame.width, frame.height);
    let samples = frame.as_f32().ok_or(RawError::Buffer)?;
    if width == 0 || height == 0 || samples.len() != width as usize * height as usize * 3 {
        return Err(RawError::Buffer);
    }
    Ok((
        samples,
        width,
        height,
        Orientation::from_exif(frame.orientation),
    ))
}

/// The whole decoded frame, as linear-light f64, upright.
fn image_from(samples: &[f32], width: u32, height: u32, orientation: Orientation) -> Image {
    let pixels = samples
        .chunks_exact(3)
        .map(|pixel| {
            [
                f64::from(pixel[0]).max(0.0),
                f64::from(pixel[1]).max(0.0),
                f64::from(pixel[2]).max(0.0),
            ]
        })
        .collect();

    let mut image = Image {
        width,
        height,
        pixels,
    };
    turn(&mut image, orientation);
    image
}

/// The frame at [width], averaged while it is still the decoder's samples.
///
/// The arithmetic is [`kallo_io::resize_to_width`]'s, pixel for pixel: the same
/// source rectangle per destination pixel, summed in the same row-major order
/// of the upright frame, with the orientation mapped back to the sensor as each
/// pixel is read.
fn downsample(
    samples: &[f32],
    width: u32,
    height: u32,
    orientation: Orientation,
    target_width: u32,
) -> Image {
    let (upright_width, upright_height) = if orientation.swaps_axes() {
        (height, width)
    } else {
        (width, height)
    };
    let scale = f64::from(upright_width) / f64::from(target_width);
    let target_height = ((f64::from(upright_height) / scale).round() as u32).max(1);
    let stride = width as usize;
    let mut pixels = Vec::with_capacity((target_width * target_height) as usize);

    for y in 0..target_height {
        let top = f64::from(y) * f64::from(upright_height) / f64::from(target_height);
        let bottom = f64::from(y + 1) * f64::from(upright_height) / f64::from(target_height);
        let y0 = (top.floor() as u32).min(upright_height - 1);
        let y1 = (bottom.ceil() as u32).clamp(y0 + 1, upright_height);
        for x in 0..target_width {
            let left = f64::from(x) * f64::from(upright_width) / f64::from(target_width);
            let right = f64::from(x + 1) * f64::from(upright_width) / f64::from(target_width);
            let x0 = (left.floor() as u32).min(upright_width - 1);
            let x1 = (right.ceil() as u32).clamp(x0 + 1, upright_width);

            let mut sum = [0.0f64; 3];
            let mut count = 0.0f64;
            for source_y in y0..y1 {
                for source_x in x0..x1 {
                    let (sensor_x, sensor_y) =
                        sensor_at(orientation, source_x, source_y, width, height);
                    let at = (sensor_y as usize * stride + sensor_x as usize) * 3;
                    sum[0] += f64::from(samples[at]).max(0.0);
                    sum[1] += f64::from(samples[at + 1]).max(0.0);
                    sum[2] += f64::from(samples[at + 2]).max(0.0);
                    count += 1.0;
                }
            }
            pixels.push([sum[0] / count, sum[1] / count, sum[2] / count]);
        }
    }

    Image {
        width: target_width,
        height: target_height,
        pixels,
    }
}

/// The sensor pixel under an upright pixel.
///
/// This is [`turn`] read backwards: the orientation is a permutation, so the
/// average can read the sensor directly instead of turning a second full-size
/// frame first.
fn sensor_at(orientation: Orientation, x: u32, y: u32, width: u32, height: u32) -> (u32, u32) {
    match orientation {
        Orientation::Normal => (x, y),
        Orientation::HorizontalFlip => (width - 1 - x, y),
        Orientation::Rotate180 => (width - 1 - x, height - 1 - y),
        Orientation::VerticalFlip => (x, height - 1 - y),
        Orientation::Transpose => (y, x),
        Orientation::Rotate90 => (y, height - 1 - x),
        Orientation::Transverse => (width - 1 - y, height - 1 - x),
        Orientation::Rotate270 => (width - 1 - y, x),
    }
}

/// How the camera was held, from the file's own Exif.
///
/// The eight values the tag can take, kept here rather than borrowed from the
/// decoder so that the turn is the crate's own rule and survives the next
/// engine swap.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Orientation {
    Normal,
    HorizontalFlip,
    Rotate180,
    VerticalFlip,
    Transpose,
    Rotate90,
    Transverse,
    Rotate270,
}

impl Orientation {
    /// The Exif value, 1 through 8. Anything else means the file did not say.
    fn from_exif(orientation: flashraw::Orientation) -> Self {
        match orientation {
            flashraw::Orientation::Normal => Self::Normal,
            flashraw::Orientation::FlipH => Self::HorizontalFlip,
            flashraw::Orientation::Rotate180 => Self::Rotate180,
            flashraw::Orientation::FlipV => Self::VerticalFlip,
            flashraw::Orientation::Transpose => Self::Transpose,
            flashraw::Orientation::Rotate90 => Self::Rotate90,
            flashraw::Orientation::Transverse => Self::Transverse,
            flashraw::Orientation::Rotate270 => Self::Rotate270,
        }
    }

    /// Whether the turn puts the sensor's rows where the upright columns go.
    fn swaps_axes(self) -> bool {
        matches!(
            self,
            Self::Transpose | Self::Rotate90 | Self::Transverse | Self::Rotate270
        )
    }
}

/// Turn and flip the decoded picture to the way the camera was held.
///
/// Every case is a permutation of whole pixels: nothing is resampled. A raw is
/// light, and light does not want interpolating twice.
fn turn(image: &mut Image, orientation: Orientation) {
    match orientation {
        Orientation::Normal => {}
        Orientation::HorizontalFlip => mirror(image, true),
        Orientation::Rotate180 => {
            mirror(image, true);
            mirror(image, false);
        }
        Orientation::VerticalFlip => mirror(image, false),
        Orientation::Transpose => transpose(image),
        // Rotate 90° clockwise to display: the stored rows become columns,
        // then the result is mirrored.
        Orientation::Rotate90 => {
            transpose(image);
            mirror(image, true);
        }
        Orientation::Transverse => {
            transpose(image);
            mirror(image, true);
            mirror(image, false);
        }
        Orientation::Rotate270 => {
            transpose(image);
            mirror(image, false);
        }
    }
}

/// Mirror the picture across its centre: left to right, or top to bottom.
fn mirror(image: &mut Image, horizontal: bool) {
    let width = image.width as usize;
    let height = image.height as usize;
    if horizontal {
        for row in 0..height {
            image.pixels[row * width..(row + 1) * width].reverse();
        }
    } else {
        for row in 0..height / 2 {
            let top = row * width;
            let bottom = (height - 1 - row) * width;
            for column in 0..width {
                image.pixels.swap(top + column, bottom + column);
            }
        }
    }
}

/// Turn the picture on its side: the rows become the columns.
fn transpose(image: &mut Image) {
    let width = image.width as usize;
    let height = image.height as usize;
    let mut pixels = vec![[0.0f64; 3]; width * height];
    for row in 0..height {
        for column in 0..width {
            pixels[column * height + row] = image.pixels[row * width + column];
        }
    }
    image.width = height as u32;
    image.height = width as u32;
    image.pixels = pixels;
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every turn the tag can ask for, as a permutation of whole pixels.
    #[test]
    fn the_orientation_is_a_turn_of_whole_pixels() {
        // Three wide and two tall, each pixel's index for a value: a portrait
        // frame is that picture with the camera on its side.
        let cases: &[(Orientation, (u32, u32), [f64; 6])] = &[
            (Orientation::Normal, (3, 2), [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]),
            (
                Orientation::HorizontalFlip,
                (3, 2),
                [2.0, 1.0, 0.0, 5.0, 4.0, 3.0],
            ),
            (
                Orientation::Rotate180,
                (3, 2),
                [5.0, 4.0, 3.0, 2.0, 1.0, 0.0],
            ),
            (
                Orientation::VerticalFlip,
                (3, 2),
                [3.0, 4.0, 5.0, 0.0, 1.0, 2.0],
            ),
            (
                Orientation::Transpose,
                (2, 3),
                [0.0, 3.0, 1.0, 4.0, 2.0, 5.0],
            ),
            (
                Orientation::Rotate90,
                (2, 3),
                [3.0, 0.0, 4.0, 1.0, 5.0, 2.0],
            ),
            (
                Orientation::Transverse,
                (2, 3),
                [5.0, 2.0, 4.0, 1.0, 3.0, 0.0],
            ),
            (
                Orientation::Rotate270,
                (2, 3),
                [2.0, 5.0, 1.0, 4.0, 0.0, 3.0],
            ),
        ];
        for &(orientation, (width, height), expected) in cases {
            let mut image = Image {
                width: 3,
                height: 2,
                pixels: (0..6)
                    .map(|index| {
                        let value = index as f64;
                        [value; 3]
                    })
                    .collect(),
            };
            turn(&mut image, orientation);
            assert_eq!(
                (image.width, image.height),
                (width, height),
                "{orientation:?}"
            );
            let turned: Vec<f64> = image.pixels.iter().map(|pixel| pixel[0]).collect();
            assert_eq!(turned, expected, "{orientation:?}");
        }
    }

    #[test]
    fn the_extensions_are_recognised_in_any_case() {
        assert!(handles("DSC03315.ARW"));
        assert!(handles("DSCF0989.RAF"));
        assert!(handles("shot.cr3"));
        assert!(!handles("portrait.jpg"));
        assert!(!handles("no-extension"));
    }

    /// Decode a real raw when one is pointed at.
    ///
    /// The fixtures are camera files, they are large, and they are not
    /// redistributable, so none of them live in the repository. Set
    /// `KALLO_RAW_FIXTURE` to one to run this.
    #[test]
    fn a_raw_file_decodes_to_linear_pixels() {
        let Ok(path) = std::env::var("KALLO_RAW_FIXTURE") else {
            return;
        };
        let image = load(&path).expect("decode");
        assert!(image.width > 0 && image.height > 0);
        assert_eq!(
            image.pixels.len(),
            image.width as usize * image.height as usize
        );
        let mean: f64 = image.pixels.iter().map(|p| p[0]).sum::<f64>() / image.pixels.len() as f64;
        // Scene-referred linear light: a normally exposed frame sits near 18 %
        // grey in its green channel. This is a sanity check on the pipeline
        // rather than a measurement, hence the generous window.
        assert!((0.01..1.0).contains(&mean), "implausible mean {mean}");
        assert!(
            image.pixels.iter().all(|p| p.iter().all(|c| c.is_finite())),
            "non-finite pixel"
        );
    }

    /// A fixture the camera stored on its side comes out the way up.
    ///
    /// Set `KALLO_RAW_FIXTURE_TURNED` to a raw whose orientation tag is 6
    /// or 8 — a copy of a fixture with that one tag rewritten is enough — and
    /// the picture must be taller than it is wide.
    #[test]
    fn a_turned_fixture_is_read_the_way_up() {
        let Ok(path) = std::env::var("KALLO_RAW_FIXTURE_TURNED") else {
            return;
        };
        let image = load(&path).expect("decode");
        assert!(
            image.height > image.width,
            "a file the camera held on its side must come out portrait: {}x{}",
            image.width,
            image.height
        );
    }

    /// The sensor samples for a small synthetic frame, with values both sides
    /// of zero so the clamp is exercised.
    fn sensor(width: u32, height: u32) -> Vec<f32> {
        let mut samples = Vec::with_capacity((width * height * 3) as usize);
        for y in 0..height {
            for x in 0..width {
                for channel in 0..3u32 {
                    let index = y * width * 3 + x * 3 + channel;
                    samples.push((index % 19) as f32 / 8.0 - 0.5);
                }
            }
        }
        samples
    }

    /// A raw read at a width must be the raw read and then resized.
    ///
    /// Every orientation, because the average is taken on the upright frame
    /// while the samples are read from the sensor's own layout.
    #[test]
    fn reading_at_a_width_is_reading_then_resizing() {
        let (width, height) = (7u32, 5u32);
        let samples = sensor(width, height);
        let orientations = [
            Orientation::Normal,
            Orientation::HorizontalFlip,
            Orientation::Rotate180,
            Orientation::VerticalFlip,
            Orientation::Transpose,
            Orientation::Rotate90,
            Orientation::Transverse,
            Orientation::Rotate270,
        ];
        for orientation in orientations {
            let full = image_from(&samples, width, height, orientation);
            let upright_width = if orientation.swaps_axes() {
                height
            } else {
                width
            };
            // Asking for a width the frame already has is a copy, not a
            // resize; the one-pass path leaves that to `image_from`.
            let expected = kallo_io::resize_to_width(&full, upright_width + 3);
            assert_eq!((full.width, full.height), (expected.width, expected.height));
            for target in 1..upright_width {
                let expected = kallo_io::resize_to_width(&full, target);
                let actual = downsample(&samples, width, height, orientation, target);
                assert_eq!(
                    (actual.width, actual.height),
                    (expected.width, expected.height),
                    "{orientation:?} at {target}"
                );
                for (index, (expected, actual)) in
                    expected.pixels.iter().zip(&actual.pixels).enumerate()
                {
                    assert_eq!(
                        actual, expected,
                        "{orientation:?} at {target}: pixel {index}"
                    );
                }
            }
        }
    }

    /// The same check against a real camera file when one is pointed at.
    ///
    /// Set `KALLO_RAW_FIXTURE` to run it; the fixture is large and not
    /// redistributable, so it does not live in the repository.
    #[test]
    fn a_raw_read_at_a_width_is_the_raw_then_resized() {
        let Ok(path) = std::env::var("KALLO_RAW_FIXTURE") else {
            return;
        };
        let full = load(&path).expect("decode");
        for width in [760u32, 1600, 2048] {
            let expected = kallo_io::resize_to_width(&full, width);
            let actual = load_at_width(&path, width).expect("decode at a width");
            assert_eq!(
                (actual.width, actual.height),
                (expected.width, expected.height),
                "at {width}"
            );
            for (index, (expected, actual)) in
                expected.pixels.iter().zip(&actual.pixels).enumerate()
            {
                assert_eq!(actual, expected, "at {width}: pixel {index}");
            }
        }
    }
}
