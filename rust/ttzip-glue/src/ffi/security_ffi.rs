// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI bindings for path sanitization and security defenses.

use crate::ffi::helpers::safe_cstr;
use crate::security::path_sanitizer::sanitize_path;
use crate::types::TTZipStatus;
use libc::c_char;
use std::panic::catch_unwind;

/// C-ABI representation of path sanitization and audit results.
#[repr(C)]
#[derive(Debug, Clone)]
pub struct TTZipPathSanitizationResult {
    pub normalized_path: [c_char; 4096],
    pub win32_formatted_path: [c_char; 4096],
    pub stripped_ads: [c_char; 1024],
    pub has_traversal_attack: bool,
    pub is_absolute: bool,
    pub is_unc: bool,
    pub is_long_path: bool,
    pub is_windows_reserved: bool,
    pub has_stripped_ads: bool,
}

impl Default for TTZipPathSanitizationResult {
    fn default() -> Self {
        Self {
            normalized_path: [0; 4096],
            win32_formatted_path: [0; 4096],
            stripped_ads: [0; 1024],
            has_traversal_attack: false,
            is_absolute: false,
            is_unc: false,
            is_long_path: false,
            is_windows_reserved: false,
            has_stripped_ads: false,
        }
    }
}

#[inline]
fn copy_str_to_c_buffer(src: &str, dest: &mut [c_char]) {
    let bytes = src.as_bytes();
    let max_len = dest.len().saturating_sub(1);
    let copy_len = bytes.len().min(max_len);
    if copy_len > 0 {
        // SAFETY: dest is a valid mutable slice of c_char, bytes is copy_len initialized bytes
        unsafe {
            std::ptr::copy_nonoverlapping(
                bytes.as_ptr() as *const c_char,
                dest.as_mut_ptr(),
                copy_len,
            );
        }
    }
    dest[copy_len] = 0;
}

/// Sanitizes, normalizes, and audits a path against ZipSlip traversal, Win32 reserved device names,
/// NTFS Alternate Data Streams (ADS), and canonical NFC encoding.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_sanitize_path(
    raw_path: *const c_char,
    out_result: *mut TTZipPathSanitizationResult,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_result.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let path_str = match unsafe { safe_cstr(raw_path) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        let res = sanitize_path(path_str);

        // SAFETY: out_result verified non-null
        let out = unsafe { &mut *out_result };
        *out = TTZipPathSanitizationResult::default();

        copy_str_to_c_buffer(&res.normalized_path, &mut out.normalized_path);
        copy_str_to_c_buffer(&res.win32_formatted_path, &mut out.win32_formatted_path);

        if let Some(ads) = &res.stripped_ads {
            copy_str_to_c_buffer(ads, &mut out.stripped_ads);
            out.has_stripped_ads = true;
        } else {
            out.has_stripped_ads = false;
        }

        out.has_traversal_attack = res.has_traversal_attack;
        out.is_absolute = res.is_absolute;
        out.is_unc = res.is_unc;
        out.is_long_path = res.is_long_path;
        out.is_windows_reserved = res.is_windows_reserved;

        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
