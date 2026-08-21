// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pure Rust Google Brotli block and streaming C-ABI FFI exports.

use crate::codecs::brotli::{
    brotli_compress, brotli_compress_bound, brotli_compress_file, brotli_decompress,
    brotli_decompress_file,
};
use crate::types::{TTZipProgressCallback, TTZipStatus};
use libc::{c_char, c_void, size_t};
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::path::Path;

#[no_mangle]
pub extern "C" fn ttzip_rust_brotli_compress(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    quality: u32,
    lgwin: u32,
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

        match brotli_compress(in_slice, out_slice, quality, lgwin) {
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
pub extern "C" fn ttzip_rust_brotli_decompress(
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

        match brotli_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_brotli_compress_bound(src_len: size_t) -> size_t {
    brotli_compress_bound(src_len)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_brotli_compress_file_stream(
    src_path: *const c_char,
    dst_path: *const c_char,
    quality: u32,
    lgwin: u32,
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

        match brotli_compress_file(src_p, Path::new(dst_str), quality, lgwin, cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_brotli_decompress_file_stream(
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

        match brotli_decompress_file(src_p, Path::new(dst_str), cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
