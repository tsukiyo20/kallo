//! Large Rust buffers are returned to the system as soon as Rust frees them.
//!
//! A camera raw decodes to a linear f32 frame of a few hundred megabytes: one
//! 33-megapixel frame is about 393 MB. The app reads it once to make the
//! window's photograph and the bench's copy, and then the frame is dropped. On
//! macOS the malloc zone keeps a freed block that size resident — `MADV_FREE`,
//! not a leak — until the system is actually under pressure, and Activity
//! Monitor reports those pages as memory the app is using. A bench that has
//! just opened a raw therefore looks like it is holding a gigabyte, and the
//! pages only go away when something else needs the RAM.
//!
//! Allocations of a megabyte or more are therefore mapped directly and unmapped
//! when they are freed, so the pages go back to the system at the moment the
//! decode is finished. Smaller allocations stay on the system allocator, where
//! its free lists are worth more than a system call.
//!
//! Only the app's own Rust allocations go through this: the model's crates and
//! the command line binary are untouched, and the platform's image decoders
//! keep their own memory. Other platforms already return freed large blocks to
//! the system, so this is the macOS answer and nothing else compiles it.

use std::alloc::{GlobalAlloc, Layout, System};
use std::ptr;

/// The smallest block worth a system call of its own.
const LARGE: usize = 1 << 20;

/// What `mmap` returns, and the largest alignment this allocator promises.
const PAGE: usize = 4096;

pub struct LargePageAllocator;

// SAFETY: every method upholds the `GlobalAlloc` contract: `alloc` answers with
// a block of at least `layout.size()` bytes aligned to `layout.align()`, or
// null; `dealloc` is only called with a pointer and layout this allocator
// returned; and `mmap`/`munmap` are page-granular, which is why the size is
// rounded the same way in both directions.
unsafe impl GlobalAlloc for LargePageAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        match mapping(&layout) {
            Some(length) => map(length),
            None => System.alloc(layout),
        }
    }

    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        match mapping(&layout) {
            // Anonymous private memory is zero before it is written.
            Some(length) => map(length),
            None => System.alloc_zeroed(layout),
        }
    }

    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        match mapping(&layout) {
            Some(length) => {
                // SAFETY: the pointer and length are the ones `alloc` mapped
                // for this layout, and it is not used after this call.
                unsafe {
                    libc::munmap(pointer.cast(), length);
                }
            }
            None => System.dealloc(pointer, layout),
        }
    }
}

/// The mapped length for a layout, when this allocator handles it.
fn mapping(layout: &Layout) -> Option<usize> {
    if layout.size() < LARGE || layout.align() > PAGE {
        return None;
    }
    layout
        .size()
        .checked_add(PAGE - 1)
        .map(|size| size & !(PAGE - 1))
}

/// Map zeroed, writable memory whose length is a whole number of pages.
unsafe fn map(length: usize) -> *mut u8 {
    // SAFETY: `mmap` is safe to call with a null address and file descriptor -1
    // for anonymous memory; the result is checked against `MAP_FAILED`.
    let address = unsafe {
        libc::mmap(
            ptr::null_mut(),
            length,
            libc::PROT_READ | libc::PROT_WRITE,
            libc::MAP_PRIVATE | libc::MAP_ANON,
            -1,
            0,
        )
    };
    if address == libc::MAP_FAILED {
        ptr::null_mut()
    } else {
        address.cast::<u8>()
    }
}
