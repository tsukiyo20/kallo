//! Reading the photograph: an ordinary image, or a camera raw.

use std::path::Path;

use kallo_io::{Image, InputEncoding, load, load_at_width};

use crate::error::Error;

/// Read the input, from a camera raw when it is one and the build has a
/// decoder.
///
/// A raw file is scene-referred linear by construction, so `--input-encoding`
/// does not apply to it: the value is taken as the file's own, and a user who
/// asked for `srgb` on a `.nef` is not obeyed, because obeying would apply a
/// transfer curve to data that never had one. Every command that reads a
/// photograph reads it through here for that reason.
pub fn read_input(path: &Path, encoding: InputEncoding) -> Result<Image, Error> {
    #[cfg(feature = "raw")]
    if kallo_raw::handles(path) {
        return kallo_raw::load(path).map_err(|source| Error::Raw {
            path: path.to_path_buf(),
            message: source.to_string(),
        });
    }
    #[cfg(not(feature = "raw"))]
    if looks_like_raw(path) {
        return Err(Error::Raw {
            path: path.to_path_buf(),
            message: "this build has no raw decoder; rebuild with `--features raw`, or \
                      convert the file and pass --input-encoding linear"
                .to_string(),
        });
    }
    load(path, encoding).map_err(|source| Error::Read {
        path: path.to_path_buf(),
        source,
    })
}

/// Read the input at no more than [width], in one pass.
///
/// The bench and the gallery want a window-sized copy, not a camera-sized one,
/// and a 33-megapixel file is 786 MB as the f64 [`Image`] [`read_input`] makes.
/// This is the same photograph at the width asked for: the decoder's own bytes,
/// averaged down while they are still the decoder's, with the arithmetic
/// [`kallo_io::resize_to_width`] would have used.
pub fn read_input_at_width(
    path: &Path,
    encoding: InputEncoding,
    width: u32,
) -> Result<Image, Error> {
    #[cfg(feature = "raw")]
    if kallo_raw::handles(path) {
        return kallo_raw::load_at_width(path, width).map_err(|source| Error::Raw {
            path: path.to_path_buf(),
            message: source.to_string(),
        });
    }
    #[cfg(not(feature = "raw"))]
    if looks_like_raw(path) {
        return Err(Error::Raw {
            path: path.to_path_buf(),
            message: "this build has no raw decoder; rebuild with `--features raw`, or \
                      convert the file and pass --input-encoding linear"
                .to_string(),
        });
    }
    load_at_width(path, encoding, width).map_err(|source| Error::Read {
        path: path.to_path_buf(),
        source,
    })
}

/// Whether `path` is a camera raw this build can read.
///
/// The decoder owns the answer, so this is the one extension list in the
/// program that matters. An interface asks before it hands the bytes to a
/// window's decoder — that decoder reads JPEG, PNG and not a sensor's mosaic,
/// and "unsupported image format" is a poor answer to someone who passed a
/// camera file.
pub fn handles_raw(path: &Path) -> bool {
    #[cfg(feature = "raw")]
    {
        kallo_raw::handles(path)
    }
    #[cfg(not(feature = "raw"))]
    {
        let _ = path;
        false
    }
}

/// A short list of raw extensions, and only for the error message: without the
/// `raw` feature there is no decoder to ask, and "unsupported image format" is
/// a poor answer to someone who passed a camera file.
#[cfg(not(feature = "raw"))]
const RAW_EXTENSIONS: &[&str] = &[
    "3fr", "arw", "cr2", "cr3", "dng", "iiq", "nef", "nrw", "orf", "pef", "raf", "rw2", "srw",
];

#[cfg(not(feature = "raw"))]
fn looks_like_raw(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| RAW_EXTENSIONS.contains(&extension.to_ascii_lowercase().as_str()))
}

#[cfg(test)]
mod tests {
    use super::handles_raw;
    use std::path::Path;

    /// The decoder's own list, asked by name. A camera writes the extension in
    /// capitals as often as not, and a file that does not exist is still a
    /// routing question, not a read.
    #[cfg(feature = "raw")]
    #[test]
    fn a_camera_raw_is_named_by_the_decoder() {
        assert!(handles_raw(Path::new("DSC03315.ARW")));
        assert!(handles_raw(Path::new("scan.dng")));
        assert!(handles_raw(Path::new("frame.cr3")));
        assert!(!handles_raw(Path::new("print.png")));
        assert!(!handles_raw(Path::new("photograph")));
    }

    /// Without the decoder there is nothing to hand a raw to, and the answer is
    /// no rather than a build that pretends.
    #[cfg(not(feature = "raw"))]
    #[test]
    fn without_the_decoder_no_file_is_a_raw() {
        assert!(!handles_raw(Path::new("DSC03315.ARW")));
    }
}
