//! One photograph, decoded once.
//!
//! The window shows the photograph at [`WINDOW_WIDTH`] pixels; the bench
//! develops the same photograph at 760. They are the same read, and a camera
//! file is expensive: a 33-megapixel raw is nearly 800 MB as f64 if the whole
//! frame is kept, and the bench only ever wanted a few hundred thousand
//! pixels of it. The first caller decodes the window's copy; the second finds
//! it here and takes what it needs, so the file is read once per photograph.
//!
//! The entry belongs to a file, not to a call: the path, the file's own
//! modification time and its size say when it must be read again. The cache is
//! one photograph deep — the one on the bench — and keeps its f64 image, a few
//! tens of megabytes, beside the session that uses it.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::SystemTime;

use kallo_io::{Image, InputEncoding};

/// The width the app shows the photograph at.
///
/// The darkroom asks for 1600 (`decodePhotograph(file, width: 1600)`) and the
/// bench's session for 760. Decoding the window's copy first means the bench is
/// a resize, not a second read; the number is stated here because this is where
/// the two asks meet.
const WINDOW_WIDTH: u32 = 1600;

struct Reading {
    path: PathBuf,
    modified: Option<SystemTime>,
    len: u64,
    encoding: InputEncoding,
    image: Arc<Image>,
}

static LAST: OnceLock<Mutex<Option<Reading>>> = OnceLock::new();

/// The photograph at the wider of [width] and the window's width.
///
/// A caller asking for the bench's 760 gets the window's 1600-pixel copy and
/// resizes it; a caller asking for a new photograph reads it at the window's
/// width and replaces the entry.
pub(crate) fn read(path: &Path, encoding: InputEncoding, width: u32) -> Result<Arc<Image>, String> {
    let metadata = std::fs::metadata(path).map_err(|error| error.to_string())?;
    let modified = metadata.modified().ok();
    let len = metadata.len();
    let wanted = if kallo_api::handles_raw(path) {
        // The window cannot read a camera raw itself: the model's copy is both
        // the photograph on the wall and the negative on the bench.
        width.max(WINDOW_WIDTH)
    } else {
        // The window's own decoder reads an ordinary photograph, so only the
        // bench asks the model for a copy, and it asks for its own width.
        width
    };

    let slot = LAST.get_or_init(|| Mutex::new(None));
    // The lock covers the read: two callers that begin together — the window's
    // photograph and the bench's session do — would otherwise decode the same
    // camera file twice, which is exactly the work this exists to avoid.
    let mut last = slot.lock().unwrap_or_else(|error| error.into_inner());
    if let Some(reading) = last.as_ref() {
        if reading.path == path
            && reading.modified == modified
            && reading.len == len
            && reading.encoding == encoding
            && reading.image.width >= width
        {
            return Ok(Arc::clone(&reading.image));
        }
    }

    let image = Arc::new(
        kallo_api::read_input_at_width(path, encoding, wanted)
            .map_err(|error| error.to_string())?,
    );
    *last = Some(Reading {
        path: path.to_path_buf(),
        modified,
        len,
        encoding,
        image: Arc::clone(&image),
    });
    Ok(image)
}
