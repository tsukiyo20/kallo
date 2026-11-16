//! The small copy of a picture.
//!
//! The gallery and the rack do not need a 26-megapixel file; they need the
//! paper at 512 pixels. Flutter's decoder can be asked for a target width, but
//! a PNG is still decoded at its own size before it is scaled, which leaves a
//! large buffer behind for every print on a wall. The model's image reader
//! already knows how to decode at camera sizes; this is the one place that
//! turns one into a small file and lets the buffer go.
//!
//! The darkroom's photograph is the same question with a harder format. A
//! camera raw is not an image the window's decoder reads at all — it is a
//! sensor mosaic with metadata, and the model is the only decoder in the
//! program that knows it. So the function says which files those are, and
//! develops them to a PNG the window can read.

use std::path::Path;

use image::{DynamicImage, GenericImageView as _, ImageDecoder as _, ImageFormat, ImageReader};
use kallo_io::{InputEncoding, resize_to_width, save};

/// Whether a file is a camera raw the model reads.
///
/// The extension list lives in the decoder, and this is the same answer through
/// the bridge. A window should ask before it hands the bytes to its own
/// decoder: reading a 500 MB mosaic only to be told "unsupported image format"
/// is a worse answer than never reading it.
pub fn is_camera_raw(path: String) -> bool {
    kallo_api::handles_raw(Path::new(&path))
}

/// Write a thumbnail of [input] to [output], no wider than [width].
///
/// The shape is kept. A source narrower than [width] is not enlarged: the
/// gallery is a wall, not an upscaler. The result is PNG because it is a print
/// on paper and the cache may keep it for a long time.
pub fn make_thumbnail(input: String, output: String, width: u32) -> Result<(), String> {
    if width == 0 {
        return Err("a thumbnail needs a width".to_owned());
    }
    if kallo_api::handles_raw(Path::new(&input)) {
        return make_raw_thumbnail(&input, &output, width);
    }
    let reader = ImageReader::open(&input)
        .map_err(|error| error.to_string())?
        .with_guessed_format()
        .map_err(|error| error.to_string())?;

    // The same camera-sized limits as the model's reader. The default is tuned
    // for icons and refuses a full-frame photograph.
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(65_535);
    limits.max_image_height = Some(65_535);
    limits.max_alloc = Some(512 * 1024 * 1024);
    let mut decoder = reader.into_decoder().map_err(|error| error.to_string())?;
    let orientation = decoder.orientation().map_err(|error| error.to_string())?;
    limits
        .reserve(decoder.total_bytes())
        .map_err(|error| error.to_string())?;
    decoder
        .set_limits(limits)
        .map_err(|error| error.to_string())?;
    let mut image = DynamicImage::from_decoder(decoder).map_err(|error| error.to_string())?;
    image.apply_orientation(orientation);

    let (source_width, source_height) = image.dimensions();
    if source_width == 0 || source_height == 0 {
        return Err("the print has no pixels".to_owned());
    }
    let target_width = width.min(source_width);
    let target_height = ((u64::from(source_height) * u64::from(target_width)
        + u64::from(source_width) / 2)
        / u64::from(source_width))
    .max(1) as u32;
    let thumbnail = image.thumbnail(target_width, target_height);
    thumbnail
        .save_with_format(Path::new(&output), ImageFormat::Png)
        .map_err(|error| error.to_string())
}

/// A camera raw thumbnail: the model develops the file, the window reads a PNG.
///
/// A raw is scene-referred linear light, and `kallo_api::read_input` is the
/// program's one route from a file to it. The small copy is encoded with the
/// same sRGB curve as a print (`kallo_io::save`), because the photograph in the
/// window is the picture the bench will develop — a camera's own JPEG preview
/// has a look baked in, and developing that look a second time is how a film
/// simulation stops being one.
///
/// The decode itself is camera-sized, because that is what a decoder does; only
/// the resized frame is encoded, so the PNG written here never holds the whole
/// photograph.
fn make_raw_thumbnail(input: &str, output: &str, width: u32) -> Result<(), String> {
    let photograph = kallo_api::read_input(Path::new(input), InputEncoding::Srgb)
        .map_err(|error| error.to_string())?;
    let thumbnail = resize_to_width(&photograph, width);
    save(output, &thumbnail).map_err(|error| error.to_string())
}
