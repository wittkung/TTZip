// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for filesystem security and APFS optimizations.

use crate::fs::apfs::{
    apfs_clone_file, apfs_fcopyfile_clone, apfs_preallocate, is_mac_junk_file, ttzip_remove_path_fast,
};
use crate::fs::safe_extract::sanitize_and_validate_path;
use crate::types::TTZipStatus;
use libc::c_char;
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::path::Path;

/// Validates entry path against destination directory to prevent ZipSlip traversal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_validate_path(
    dest_dir: *const c_char,
    entry_path: *const c_char,
    out_sanitized: *mut c_char,
    out_capacity: usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if dest_dir.is_null() || entry_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let dest_str = match CStr::from_ptr(dest_dir).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let entry_str = match CStr::from_ptr(entry_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match sanitize_and_validate_path(Path::new(dest_str), entry_str) {
            Ok(valid_path) => {
                if !out_sanitized.is_null() && out_capacity > 0 {
                    let path_str = valid_path.to_string_lossy();
                    let bytes = path_str.as_bytes();
                    if bytes.len() + 1 > out_capacity {
                        return TTZipStatus::ErrPathTooLong;
                    }
                    std::ptr::copy_nonoverlapping(
                        bytes.as_ptr() as *const c_char,
                        out_sanitized,
                        bytes.len(),
                    );
                    *out_sanitized.add(bytes.len()) = 0;
                }
                TTZipStatus::Ok
            }
            Err(e) => e,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Preallocates contiguous physical extent space on APFS filesystems.
#[no_mangle]
pub extern "C" fn ttzip_rust_apfs_preallocate(fd: i32, target_size: i64) -> i32 {
    let result = catch_unwind(|| match apfs_preallocate(fd, target_size) {
        Ok(()) => 0,
        Err(_) => -1,
    });
    result.unwrap_or(-1)
}

/// Clones a file using APFS Copy-on-Write (CoW).
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_apfs_clone_file(
    src: *const c_char,
    dst: *const c_char,
    overwrite: bool,
) -> i32 {
    let result = catch_unwind(|| {
        if src.is_null() || dst.is_null() {
            return -1;
        }

        let src_str = match CStr::from_ptr(src).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let dst_str = match CStr::from_ptr(dst).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };

        match apfs_clone_file(Path::new(src_str), Path::new(dst_str), overwrite) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Clones file descriptor range via APFS `fcopyfile`.
#[no_mangle]
pub extern "C" fn ttzip_rust_apfs_clone_range(in_fd: i32, out_fd: i32) -> i32 {
    let result = catch_unwind(|| match apfs_fcopyfile_clone(in_fd, out_fd) {
        Ok(()) => 0,
        Err(_) => -1,
    });
    result.unwrap_or(-1)
}

/// Returns true if the path points to a macOS junk metadata artifact.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_is_mac_junk(path: *const c_char) -> bool {
    let result = catch_unwind(|| {
        if path.is_null() {
            return false;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        is_mac_junk_file(s)
    });
    result.unwrap_or(false)
}

/// Fast file or directory removal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_remove_path_fast(path: *const c_char) -> i32 {
    let result = catch_unwind(|| {
        if path.is_null() {
            return -1;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };
        match ttzip_remove_path_fast(Path::new(s)) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}
