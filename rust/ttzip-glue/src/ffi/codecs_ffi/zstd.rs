// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zstandard C-ABI FFI exports.

use crate::codecs::zstd::{
    zstd_compress, zstd_compress_advanced, zstd_compress_bound, zstd_compress_stream_pipe,
    zstd_decompress, zstd_decompress_stream_pipe, zstd_get_decompressed_size, ZstdConfig,
};
use crate::types::{TTZipProgressCallback, TTZipStatus};
use libc::{c_char, c_void, size_t};
use std::ffi::CStr;
use std::fs::File;
use std::panic::catch_unwind;
use std::path::Path;

// MARK: - Zstandard C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_zstd_compress(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    level: i32,
    out_len: *mut size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_len.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if src_len > 0 && src.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if dst_capacity > 0 && dst.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let in_slice = if src_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(src, src_len) }
        };
        let out_slice = if dst_capacity == 0 {
            &mut []
        } else {
            unsafe { std::slice::from_raw_parts_mut(dst, dst_capacity) }
        };

        match zstd_compress(in_slice, out_slice, level) {
            Ok(written) => {
                unsafe { *out_len = written };
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_zstd_compress_advanced(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    level: i32,
    nb_workers: u32,
    job_size_mb: u32,
    overlap_log: u32,
    window_log: u32,
    enable_ldm: bool,
    out_len: *mut size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_len.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if src_len > 0 && src.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if dst_capacity > 0 && dst.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let in_slice = if src_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(src, src_len) }
        };
        let out_slice = if dst_capacity == 0 {
            &mut []
        } else {
            unsafe { std::slice::from_raw_parts_mut(dst, dst_capacity) }
        };

        let config = ZstdConfig {
            level,
            nb_workers,
            job_size_mb,
            overlap_log,
            window_log,
            enable_ldm,
            enable_checksum: true,
        };

        match zstd_compress_advanced(in_slice, out_slice, &config) {
            Ok(written) => {
                unsafe { *out_len = written };
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_zstd_decompress(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    out_len: *mut size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_len.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if src_len > 0 && src.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        if dst_capacity > 0 && dst.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let in_slice = if src_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(src, src_len) }
        };
        let out_slice = if dst_capacity == 0 {
            &mut []
        } else {
            unsafe { std::slice::from_raw_parts_mut(dst, dst_capacity) }
        };

        match zstd_decompress(in_slice, out_slice) {
            Ok(written) => {
                unsafe { *out_len = written };
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_zstd_compress_bound(src_len: size_t) -> size_t {
    zstd_compress_bound(src_len)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_zstd_get_decompressed_size(src: *const u8, src_len: size_t) -> u64 {
    if src.is_null() || src_len == 0 {
        return 0;
    }
    let slice = unsafe { std::slice::from_raw_parts(src, src_len) };
    zstd_get_decompressed_size(slice).unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zstd_compress_file_stream(
    src_path: *const c_char,
    dst_path: *const c_char,
    level: i32,
    nb_workers: u32,
    job_size_mb: u32,
    overlap_log: u32,
    window_log: u32,
    enable_ldm: bool,
    progress_callback: TTZipProgressCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if src_path.is_null() || dst_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let src_str = match CStr::from_ptr(src_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst_str = match CStr::from_ptr(dst_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let src_p = Path::new(src_str);
        if !src_p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }
        let total_size = src_p.metadata().map(|m| m.len()).unwrap_or(0);

        let dst_p = Path::new(dst_str);
        if let Some(parent) = dst_p.parent() {
            let _ = std::fs::create_dir_all(parent);
        }

        let mut src_file = match File::open(src_p) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let mut dst_file = match File::create(dst_p) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let config = ZstdConfig {
            level,
            nb_workers,
            job_size_mb,
            overlap_log,
            window_log,
            enable_ldm,
            enable_checksum: true,
        };

        let cb_wrapper = progress_callback.map(|cb| {
            let src_cstr = std::ffi::CString::new(src_str).unwrap_or_default();
            move |processed_bytes: u64, _written: u64| -> bool {
                cb(processed_bytes, total_size, src_cstr.as_ptr(), user_data)
            }
        });

        let cb_ref: Option<&dyn Fn(u64, u64) -> bool> = match &cb_wrapper {
            Some(w) => Some(w),
            None => None,
        };

        match zstd_compress_stream_pipe(&mut src_file, &mut dst_file, &config, cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zstd_decompress_file_stream(
    src_path: *const c_char,
    dst_path: *const c_char,
    progress_callback: TTZipProgressCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if src_path.is_null() || dst_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let src_str = match CStr::from_ptr(src_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst_str = match CStr::from_ptr(dst_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let src_p = Path::new(src_str);
        if !src_p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }
        let total_size = src_p.metadata().map(|m| m.len()).unwrap_or(0);

        let dst_p = Path::new(dst_str);
        if let Some(parent) = dst_p.parent() {
            let _ = std::fs::create_dir_all(parent);
        }

        let mut src_file = match File::open(src_p) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let mut dst_file = match File::create(dst_p) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let cb_wrapper = progress_callback.map(|cb| {
            let src_cstr = std::ffi::CString::new(src_str).unwrap_or_default();
            move |processed_bytes: u64, _written: u64| -> bool {
                cb(processed_bytes, total_size, src_cstr.as_ptr(), user_data)
            }
        });

        let cb_ref: Option<&dyn Fn(u64, u64) -> bool> = match &cb_wrapper {
            Some(w) => Some(w),
            None => None,
        };

        match zstd_decompress_stream_pipe(&mut src_file, &mut dst_file, cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

