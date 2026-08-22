// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for CRC-32 and Adler-32 checksums.

use crate::crypto::{adler32, crc32};
use std::panic::catch_unwind;
use std::slice;

/// C-ABI exported fast CRC-32 calculator.
///
/// # Safety
/// If `data` is not null and `len > 0`, `data` must point to at least `len` valid readable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_crc32(crc: u32, data: *const u8, len: usize) -> u32 {
    let result = catch_unwind(|| {
        if data.is_null() || len == 0 {
            return crc;
        }
        let slice = unsafe { slice::from_raw_parts(data, len) };
        crc32::crc32_fast(crc, slice)
    });

    result.unwrap_or(crc)
}

/// C-ABI exported fast Adler-32 calculator.
///
/// # Safety
/// If `data` is not null and `len > 0`, `data` must point to at least `len` valid readable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_adler32(adler: u32, data: *const u8, len: usize) -> u32 {
    let result = catch_unwind(|| {
        if data.is_null() || len == 0 {
            return if data.is_null() { 1 } else { adler };
        }
        let slice = unsafe { slice::from_raw_parts(data, len) };
        adler32::adler32_fast(adler, slice)
    });

    result.unwrap_or(adler)
}

/// C-ABI exported fast CRC-64 ECMA calculator.
///
/// # Safety
/// If `data` is not null and `len > 0`, `data` must point to at least `len` valid readable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_crc64(seed: u64, data: *const u8, len: usize) -> u64 {
    let result = catch_unwind(|| {
        if data.is_null() || len == 0 {
            return seed;
        }
        let slice = unsafe { slice::from_raw_parts(data, len) };
        crate::crypto::crc64::crc64(slice, seed)
    });

    result.unwrap_or(seed)
}
