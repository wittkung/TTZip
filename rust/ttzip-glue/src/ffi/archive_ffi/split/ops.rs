// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI entries for one-shot multi-volume slicing and reassembly.

use crate::archive::split::{
    SplitVolumeWriter, VirtualMultiVolumeReader, VolumeNamingScheme,
};
use crate::types::{TTZipProgressCallback, TTZipStatus};
use libc::{c_char, c_void};
use std::ffi::CStr;
use std::fs::File;
use std::io::{Read, Write};
use std::panic::catch_unwind;
use std::path::Path;

/// Slices an existing monolithic archive file into multi-volume segments in-process.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_file(
    src_path: *const c_char,
    dst_base_path: *const c_char,
    volume_size_bytes: u64,
    naming_scheme: i32,
    clean_on_failure: bool,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if src_path.is_null() || dst_base_path.is_null() || volume_size_bytes == 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        let src_str = match CStr::from_ptr(src_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst_str = match CStr::from_ptr(dst_base_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let src_p = Path::new(src_str);
        if !src_p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let mut file = match File::open(src_p) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let scheme = VolumeNamingScheme::from(naming_scheme);
        let mut writer = match SplitVolumeWriter::new(dst_str, volume_size_bytes, scheme) {
            Ok(w) => w.with_clean_on_failure(clean_on_failure),
            Err(_) => return TTZipStatus::ErrCompressionFailed,
        };

        let mut buffer = vec![0u8; 4 * 1024 * 1024]; // 4 MB buffer
        loop {
            let n = match file.read(&mut buffer) {
                Ok(n) => n,
                Err(_) => {
                    writer.cancel_and_cleanup();
                    return TTZipStatus::ErrOpenFailed;
                }
            };
            if n == 0 {
                break;
            }
            if writer.write_all(&buffer[..n]).is_err() {
                writer.cancel_and_cleanup();
                return TTZipStatus::ErrCompressionFailed;
            }
        }

        if writer.close().is_err() {
            return TTZipStatus::ErrCompressionFailed;
        }

        TTZipStatus::Ok
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Reassembles / joins multi-volume split files into a single unified output archive file.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_join_split_volumes(
    first_volume_path: *const c_char,
    output_path: *const c_char,
    progress_callback: TTZipProgressCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if first_volume_path.is_null() || output_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let first_str = match CStr::from_ptr(first_volume_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let out_str = match CStr::from_ptr(output_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let mut reader = match VirtualMultiVolumeReader::open_from_any_volume(first_str) {
            Ok(r) => r,
            Err(_) => return TTZipStatus::ErrFileNotFound,
        };

        let total_size = reader.total_size();
        let mut out_file = match File::create(out_str) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let mut buffer = vec![0u8; 4 * 1024 * 1024];
        let mut total_copied = 0u64;

        loop {
            let n = match reader.read(&mut buffer) {
                Ok(n) => n,
                Err(_) => return TTZipStatus::ErrOpenFailed,
            };
            if n == 0 {
                break;
            }
            if out_file.write_all(&buffer[..n]).is_err() {
                return TTZipStatus::ErrCompressionFailed;
            }
            total_copied += n as u64;

            if let Some(cb) = progress_callback {
                let should_continue = cb(total_copied, total_size, first_volume_path, user_data);
                if !should_continue {
                    return TTZipStatus::Cancelled;
                }
            }
        }

        let _ = out_file.flush();
        TTZipStatus::Ok
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}
