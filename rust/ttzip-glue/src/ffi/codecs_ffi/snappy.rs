// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pure Rust Google Snappy block and framing C-ABI FFI exports.

use crate::codecs::snappy::{
    is_framed_snappy, snappy_compress, snappy_compress_bound, snappy_compress_file,
    snappy_decompress, snappy_decompress_file, snappy_frame_decode, snappy_frame_encode,
    snappy_frame_max_encoded_length, snappy_uncompressed_length, snappy_validate,
};
use crate::types::{TTZipProgressCallback, TTZipStatus};
use libc::{c_char, c_void, size_t};
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::path::Path;

#[no_mangle]
pub extern "C" fn ttzip_rust_snappy_compress(
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

        match snappy_compress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_snappy_decompress(
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

        match snappy_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_snappy_max_compressed_length(src_len: size_t) -> size_t {
    snappy_compress_bound(src_len)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_snappy_uncompressed_length(
    src: *const u8,
    src_len: size_t,
    out_len: *mut size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_len.is_null() || (src_len > 0 && src.is_null()) {
            return TTZipStatus::ErrInvalidParam;
        }
        let in_slice = if src_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(src, src_len) }
        };
        match snappy_uncompressed_length(in_slice) {
            Ok(len) => {
                unsafe { *out_len = len };
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_snappy_validate(src: *const u8, src_len: size_t) -> bool {
    if src.is_null() && src_len > 0 {
        return false;
    }
    let in_slice = if src_len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(src, src_len) }
    };
    snappy_validate(in_slice)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_snappy_frame_encode(
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

        match snappy_frame_encode(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_snappy_frame_decode(
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

        match snappy_frame_decode(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_snappy_frame_max_encoded_length(src_len: size_t) -> size_t {
    snappy_frame_max_encoded_length(src_len)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_snappy_is_framed(src: *const u8, src_len: size_t) -> bool {
    if src.is_null() || src_len == 0 {
        return false;
    }
    let slice = unsafe { std::slice::from_raw_parts(src, src_len) };
    is_framed_snappy(slice)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_snappy_compress_file_stream(
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

        match snappy_compress_file(src_p, Path::new(dst_str), cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_snappy_decompress_file_stream(
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

        match snappy_decompress_file(src_p, Path::new(dst_str), cb_ref) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
