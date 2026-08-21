// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for SPSC and MPMC lock-free ring buffers.

use crate::runtime::ring_buffer::{MpmcRingBuffer, SpscRingBuffer};
use libc::{c_void, size_t};
use std::panic::{catch_unwind, AssertUnwindSafe};

// MARK: - SPSC Ring Buffer FFI

pub type TTZipSpscRingBufferHandle = SpscRingBuffer<*mut c_void>;

#[no_mangle]
pub extern "C" fn ttzip_rust_spsc_ring_buffer_new(capacity: size_t) -> *mut TTZipSpscRingBufferHandle {
    let result = catch_unwind(AssertUnwindSafe(|| {
        Box::into_raw(Box::new(SpscRingBuffer::new(capacity)))
    }));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_push(
    handle: *mut TTZipSpscRingBufferHandle,
    item: *mut c_void,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            false
        } else {
            (*handle).push(item).is_ok()
        }
    }));
    result.unwrap_or(false)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_pop(
    handle: *mut TTZipSpscRingBufferHandle,
) -> *mut c_void {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            std::ptr::null_mut()
        } else {
            (*handle).pop().unwrap_or(std::ptr::null_mut())
        }
    }));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_count(
    handle: *const TTZipSpscRingBufferHandle,
) -> size_t {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).len()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_capacity(
    handle: *const TTZipSpscRingBufferHandle,
) -> size_t {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).capacity()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_is_empty(
    handle: *const TTZipSpscRingBufferHandle,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            true
        } else {
            (*handle).is_empty()
        }
    }));
    result.unwrap_or(true)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_is_full(
    handle: *const TTZipSpscRingBufferHandle,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            false
        } else {
            (*handle).is_full()
        }
    }));
    result.unwrap_or(false)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_spsc_ring_buffer_free(handle: *mut TTZipSpscRingBufferHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    }));
}

// MARK: - MPMC Ring Buffer FFI

pub type TTZipMpmcRingBufferHandle = MpmcRingBuffer<*mut c_void>;

#[no_mangle]
pub extern "C" fn ttzip_rust_mpmc_ring_buffer_new(capacity: size_t) -> *mut TTZipMpmcRingBufferHandle {
    let result = catch_unwind(AssertUnwindSafe(|| {
        Box::into_raw(Box::new(MpmcRingBuffer::new(capacity)))
    }));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_push(
    handle: *mut TTZipMpmcRingBufferHandle,
    item: *mut c_void,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            false
        } else {
            (*handle).push(item).is_ok()
        }
    }));
    result.unwrap_or(false)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_pop(
    handle: *mut TTZipMpmcRingBufferHandle,
) -> *mut c_void {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            std::ptr::null_mut()
        } else {
            (*handle).pop().unwrap_or(std::ptr::null_mut())
        }
    }));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_count(
    handle: *const TTZipMpmcRingBufferHandle,
) -> size_t {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).len()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_capacity(
    handle: *const TTZipMpmcRingBufferHandle,
) -> size_t {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).capacity()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_is_empty(
    handle: *const TTZipMpmcRingBufferHandle,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            true
        } else {
            (*handle).is_empty()
        }
    }));
    result.unwrap_or(true)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_is_full(
    handle: *const TTZipMpmcRingBufferHandle,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            false
        } else {
            (*handle).is_full()
        }
    }));
    result.unwrap_or(false)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_mpmc_ring_buffer_free(handle: *mut TTZipMpmcRingBufferHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    }));
}
