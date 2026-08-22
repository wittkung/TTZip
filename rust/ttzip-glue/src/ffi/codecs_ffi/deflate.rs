// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! DEFLATE / zlib / gzip C-ABI FFI exports.

use crate::codecs::deflate::{
    deflate_compress, deflate_compress_bound, deflate_decompress, gzip_compress, gzip_decompress,
    zlib_compress, zlib_decompress,
};
use crate::ffi::helpers::{safe_slice, safe_slice_mut};
use crate::types::TTZipStatus;
use libc::size_t;
use std::panic::catch_unwind;

// MARK: - DEFLATE / zlib / gzip C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_deflate_compress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match deflate_compress(in_slice, out_slice, level) {
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
pub extern "C" fn ttzip_rust_deflate_decompress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match deflate_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_zlib_compress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match zlib_compress(in_slice, out_slice, level) {
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
pub extern "C" fn ttzip_rust_zlib_decompress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match zlib_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_gzip_compress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match gzip_compress(in_slice, out_slice, level) {
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
pub extern "C" fn ttzip_rust_gzip_decompress(
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
        let in_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let out_slice = match unsafe { safe_slice_mut(dst, dst_capacity) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match gzip_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_deflate_compress_bound(src_len: size_t, level: i32) -> size_t {
    deflate_compress_bound(src_len, level)
}
