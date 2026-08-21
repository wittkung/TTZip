// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for NEON-accelerated ZIP/TAR corrupt archive repair.

use crate::archive::repair::{repair_damaged_tar, repair_damaged_zip};
use crate::types::TTZipStatus;
use libc::c_char;
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::path::Path;

/// Repairs damaged ZIP archive and writes rebuilt archive to destination.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_repair_zip(
    damaged_path: *const c_char,
    repaired_path: *const c_char,
    out_salvaged_count: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if damaged_path.is_null() || repaired_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let src_str = match CStr::from_ptr(damaged_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst_str = match CStr::from_ptr(repaired_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match repair_damaged_zip(Path::new(src_str), Path::new(dst_str)) {
            Ok(count) => {
                if !out_salvaged_count.is_null() {
                    *out_salvaged_count = count;
                }
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Repairs damaged TAR archive and writes rebuilt archive to destination.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_repair_tar(
    damaged_path: *const c_char,
    repaired_path: *const c_char,
    out_salvaged_count: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if damaged_path.is_null() || repaired_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let src_str = match CStr::from_ptr(damaged_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst_str = match CStr::from_ptr(repaired_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match repair_damaged_tar(Path::new(src_str), Path::new(dst_str)) {
            Ok(count) => {
                if !out_salvaged_count.is_null() {
                    *out_salvaged_count = count;
                }
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Auto-detects format and repairs damaged archive.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_repair_auto(
    damaged_path: *const c_char,
    repaired_path: *const c_char,
    out_salvaged_count: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if damaged_path.is_null() || repaired_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let src_str = match CStr::from_ptr(damaged_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let lower = src_str.to_lowercase();
        if lower.ends_with(".tar") || lower.ends_with(".tar.gz") || lower.ends_with(".tgz") {
            ttzip_rust_archive_repair_tar(damaged_path, repaired_path, out_salvaged_count)
        } else {
            let zip_res = ttzip_rust_archive_repair_zip(damaged_path, repaired_path, out_salvaged_count);
            if zip_res == TTZipStatus::Ok {
                TTZipStatus::Ok
            } else {
                ttzip_rust_archive_repair_tar(damaged_path, repaired_path, out_salvaged_count)
            }
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
