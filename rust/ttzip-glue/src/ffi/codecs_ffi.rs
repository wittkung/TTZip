// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for single-format codecs and charset detection.
//!
//! Every exported entry point contains a `std::panic::catch_unwind` exception barrier
//! to guarantee that internal panics never unwind across foreign language boundaries.

use crate::codecs::chardet::detect_charset;
use crate::codecs::deflate::{
    deflate_compress, deflate_compress_bound, deflate_decompress, gzip_compress, gzip_decompress,
    zlib_compress, zlib_decompress,
};
use crate::codecs::fast_blocks::{
    lz4_compress, lz4_compress_bound, lz4_decompress, lzfse_compress, lzfse_decompress,
    snappy_compress, snappy_decompress, snappy_max_compressed_length, snappy_uncompressed_length,
    snappy_validate,
};
use crate::codecs::lzma2::{
    fl2_compress, fl2_compress_bound, fl2_decompress, fl2_find_decompressed_size,
};
use crate::codecs::zstd::{
    zstd_compress, zstd_compress_advanced, zstd_compress_bound, zstd_decompress,
    zstd_get_decompressed_size, ZstdConfig,
};
use crate::types::TTZipStatus;
use libc::{c_char, size_t};
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

// MARK: - Fast-LZMA2 C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_fl2_compress(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    level: i32,
    nb_threads: u32,
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

        match fl2_compress(in_slice, out_slice, level, nb_threads) {
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
pub extern "C" fn ttzip_rust_fl2_decompress(
    src: *const u8,
    src_len: size_t,
    dst: *mut u8,
    dst_capacity: size_t,
    nb_threads: u32,
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

        match fl2_decompress(in_slice, out_slice, nb_threads) {
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
pub extern "C" fn ttzip_rust_fl2_compress_bound(src_len: size_t) -> size_t {
    fl2_compress_bound(src_len)
}

#[no_mangle]
pub extern "C" fn ttzip_rust_fl2_find_decompressed_size(src: *const u8, src_len: size_t) -> u64 {
    if src.is_null() || src_len == 0 {
        return 0;
    }
    let slice = unsafe { std::slice::from_raw_parts(src, src_len) };
    fl2_find_decompressed_size(slice).unwrap_or(0)
}

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
    snappy_max_compressed_length(src_len)
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

// MARK: - Charset Detector C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_detect_charset(
    data: *const u8,
    data_len: size_t,
    out_buf: *mut c_char,
    out_buf_capacity: size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_buf.is_null() || out_buf_capacity == 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        if data_len > 0 && data.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let in_slice = if data_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(data, data_len) }
        };

        if let Some(charset) = detect_charset(in_slice) {
            let bytes = charset.as_bytes();
            if bytes.len() + 1 > out_buf_capacity {
                return TTZipStatus::ErrPathTooLong;
            }
            unsafe {
                std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf as *mut u8, bytes.len());
                *out_buf.add(bytes.len()) = 0;
            }
            TTZipStatus::Ok
        } else {
            unsafe {
                *out_buf = 0;
            }
            TTZipStatus::Ok
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
