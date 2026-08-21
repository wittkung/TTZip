// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI entries for Pure Rust ZIP scanning.

use crate::types::{TTZipEntryMetadata, TTZipInspectCallback, TTZipStatus};
use crate::zip::reader::ZipArchive;
use libc::{c_char, c_void};
use std::ffi::{CStr, CString};
use std::fs;
use std::panic::catch_unwind;
use std::path::Path;

/// C-ABI exported ZIP archive entry scanner.
///
/// Scans all Central Directory entries (standard ZIP and Zip64) and invokes `callback`
/// with metadata for each entry. Returning `false` from `callback` halts traversal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zip_scan_entries(
    archive_path: *const c_char,
    callback: TTZipInspectCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let cb = match callback {
            Some(f) => f,
            None => return TTZipStatus::ErrInvalidParam,
        };

        let path_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let p = Path::new(path_str);
        if !p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let data = match fs::read(p) {
            Ok(d) => d,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let archive = match ZipArchive::open_slice(&data) {
            Ok(a) => a,
            Err(e) => return e,
        };

        for entry in archive.entries() {
            let c_path = match CString::new(entry.rel_path.as_str()) {
                Ok(c) => c,
                Err(_) => continue,
            };

            let meta = TTZipEntryMetadata {
                path: c_path.as_ptr(),
                uncompressed_size: entry.uncompressed_size,
                compressed_size: entry.compressed_size,
                crc32: entry.crc32,
                mtime_epoch_secs: entry.mtime_epoch_secs,
                mode: entry.mode,
                is_directory: entry.is_directory,
                is_encrypted: entry.is_encrypted,
                compression_method: entry.actual_method,
            };

            let should_continue = cb(&meta, user_data);
            if !should_continue {
                break;
            }
        }

        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
