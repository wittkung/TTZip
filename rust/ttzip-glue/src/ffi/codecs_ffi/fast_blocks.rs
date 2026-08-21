// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fast blocks (LZ4, Snappy, LZFSE) C-ABI FFI exports.

use crate::codecs::fast_blocks::{
    lz4_compress, lz4_compress_bound, lz4_decompress, lzfse_compress, lzfse_decompress,
};
use crate::types::TTZipStatus;
use libc::size_t;
use std::panic::catch_unwind;

// MARK: - Fast Blocks (LZ4, Snappy, LZFSE) C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_lz4_compress(
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

        match lz4_compress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_lz4_decompress(
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

        match lz4_decompress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_lz4_compress_bound(src_len: size_t) -> size_t {
    lz4_compress_bound(src_len)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_lzfse_compress(
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

        match lzfse_compress(in_slice, out_slice) {
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
pub extern "C" fn ttzip_rust_lzfse_decompress(
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

        match lzfse_decompress(in_slice, out_slice) {
            Ok(written) => {
                unsafe { *out_len = written };
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
