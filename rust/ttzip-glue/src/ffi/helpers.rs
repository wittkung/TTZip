// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-overhead safe C-ABI memory slice and pointer bridge helpers.
//!
//! Enforces null-pointer defense, non-zero slice validation, and exception boundary translation.

use crate::types::TTZipStatus;
use libc::c_char;
use std::ffi::CStr;
use std::slice;

/// Safely constructs an immutable byte slice from a C raw pointer and length.
///
/// # Safety
/// If `len > 0`, `ptr` must point to at least `len` valid, initialized bytes.
#[inline(always)]
pub unsafe fn safe_slice<'a>(ptr: *const u8, len: usize) -> Result<&'a [u8], TTZipStatus> {
    if len == 0 {
        Ok(&[])
    } else if ptr.is_null() {
        Err(TTZipStatus::ErrInvalidParam)
    } else {
        // SAFETY: Caller ensures ptr is valid for len bytes; len > 0 and ptr != null
        Ok(unsafe { slice::from_raw_parts(ptr, len) })
    }
}

/// Safely constructs a mutable byte slice from a C raw pointer and length.
///
/// # Safety
/// If `len > 0`, `ptr` must point to at least `len` valid, writable bytes.
#[inline(always)]
pub unsafe fn safe_slice_mut<'a>(ptr: *mut u8, len: usize) -> Result<&'a mut [u8], TTZipStatus> {
    if len == 0 {
        Ok(&mut [])
    } else if ptr.is_null() {
        Err(TTZipStatus::ErrInvalidParam)
    } else {
        // SAFETY: Caller ensures ptr is valid for len writable bytes; len > 0 and ptr != null
        Ok(unsafe { slice::from_raw_parts_mut(ptr, len) })
    }
}

/// Safely dereferences and converts a C null-terminated string into a UTF-8 `&str`.
///
/// # Safety
/// `ptr` must point to a valid null-terminated C string.
#[inline(always)]
pub unsafe fn safe_cstr<'a>(ptr: *const c_char) -> Result<&'a str, TTZipStatus> {
    if ptr.is_null() {
        Err(TTZipStatus::ErrInvalidParam)
    } else {
        // SAFETY: Caller ensures ptr points to a valid null-terminated C string
        let cstr = unsafe { CStr::from_ptr(ptr) };
        cstr.to_str().map_err(|_| TTZipStatus::ErrInvalidParam)
    }
}
