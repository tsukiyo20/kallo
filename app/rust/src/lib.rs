//! The app's window onto `kallo-api`.
//!
//! Everything below this crate is the model; everything above it is the
//! interface. This file is the seam, and it is deliberately thin: a job in, a
//! report out, with progress where a job takes long enough to watch.

pub mod api;

/// The app's own large Rust buffers go back to the system when they are freed.
#[cfg(target_os = "macos")]
mod allocator;

#[cfg(target_os = "macos")]
#[global_allocator]
static ALLOCATOR: allocator::LargePageAllocator = allocator::LargePageAllocator;

mod frb_generated;
