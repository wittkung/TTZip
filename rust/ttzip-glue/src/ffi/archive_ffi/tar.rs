// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI entries for Pure Rust TAR scanning and zero-copy entry extraction.

use crate::archive::tar::reader::TarArchive;
use crate::ffi::helpers::safe_cstr;
use crate::types::{TTZipEntryMetadata, TTZipInspectCallback, TTZipStatus};
use libc::{c_char, c_void};
use std::ffi::CString;
use std::fs;
use std::panic::catch_unwind;
use std::path::Path;

/// C-ABI exported TAR archive entry scanner.
///
/// Scans all entries within a TAR archive (POSIX ustar, GNU, PAX) and invokes `callback`
/// with metadata for each entry. Returning `false` from `callback` halts traversal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_tar_scan_entries(
    archive_path: *const c_char,
    callback: TTZipInspectCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        let cb = match callback {
            Some(f) => f,
            None => return TTZipStatus::ErrInvalidParam,
        };

        let path_str = match unsafe { safe_cstr(archive_path) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        let p = Path::new(path_str);
        if !p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let data = match fs::read(p) {
            Ok(d) => d,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let archive = match TarArchive::open_slice(&data) {
            Ok(a) => a,
            Err(e) => return e,
        };

        for entry in archive.entries() {
            let c_path = match CString::new(entry.path.as_ref()) {
                Ok(c) => c,
                Err(_) => continue,
            };

            let meta = TTZipEntryMetadata {
                path: c_path.as_ptr(),
                uncompressed_size: entry.size,
                compressed_size: entry.size,
                crc32: 0,
                mtime_epoch_secs: entry.mtime_epoch_secs,
                mode: entry.mode,
                is_directory: entry.is_directory,
                is_encrypted: false,
                compression_method: 0,
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

/// C-ABI exported TAR single entry extraction into an in-memory buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_tar_extract_entry(
    archive_path: *const c_char,
    entry_index: usize,
    out_buffer: *mut u8,
    buffer_capacity: usize,
    out_extracted_len: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        let path_str = match unsafe { safe_cstr(archive_path) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        let p = Path::new(path_str);
        if !p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let data = match fs::read(p) {
            Ok(d) => d,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let archive = match TarArchive::open_slice(&data) {
            Ok(a) => a,
            Err(e) => return e,
        };

        let payload = match archive.extract_entry_bytes(entry_index) {
            Ok(bytes) => bytes,
            Err(e) => return e,
        };

        if !out_extracted_len.is_null() {
            // SAFETY: out_extracted_len verified non-null
            unsafe { *out_extracted_len = payload.len() };
        }

        if !out_buffer.is_null() {
            if buffer_capacity < payload.len() {
                return TTZipStatus::ErrOutOfMemory;
            }
            if !payload.is_empty() {
                // SAFETY: out_buffer has capacity >= payload.len() and payload is valid
                unsafe {
                    std::ptr::copy_nonoverlapping(payload.as_ptr(), out_buffer, payload.len());
                }
            }
        }

        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
