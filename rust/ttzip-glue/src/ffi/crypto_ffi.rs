// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for TTZip hardware-accelerated crypto & checksum algorithms.

use crate::crypto::{adler32, aes256, crc32, sha256};
use crate::types::TTZipStatus;
use std::ffi::CStr;
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

/// C-ABI exported hardware AES-256-CTR encrypt / decrypt.
///
/// # Safety
/// - `key` must point to 32 bytes of valid readable memory.
/// - `src` must point to `len` bytes of valid readable memory.
/// - `dst` must point to `len` bytes of valid writable memory.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_aes256_ctr(
    key: *const u8,
    initial_counter: u64,
    src: *const u8,
    len: usize,
    dst: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if key.is_null() || src.is_null() || dst.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }

        let key_ref = unsafe { &*(key as *const [u8; 32]) };
        let src_slice = unsafe { slice::from_raw_parts(src, len) };
        let dst_slice = unsafe { slice::from_raw_parts_mut(dst, len) };

        match aes256::aes256_ctr_crypt(key_ref, initial_counter, src_slice, dst_slice) {
            Ok(()) => TTZipStatus::Ok.to_i32(),
            Err(_) => TTZipStatus::ErrInvalidParam.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported hardware AES-256-CBC decrypt.
///
/// # Safety
/// - `key` must point to 32 bytes of valid readable memory.
/// - `iv` must point to 16 bytes of valid readable memory.
/// - `src` must point to `len` bytes of valid readable memory (`len % 16 == 0`).
/// - `dst` must point to `len` bytes of valid writable memory.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_aes256_cbc_decrypt(
    key: *const u8,
    iv: *const u8,
    src: *const u8,
    len: usize,
    dst: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if key.is_null() || iv.is_null() || src.is_null() || dst.is_null() || len % 16 != 0 {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }

        let key_ref = unsafe { &*(key as *const [u8; 32]) };
        let iv_ref = unsafe { &*(iv as *const [u8; 16]) };
        let src_slice = unsafe { slice::from_raw_parts(src, len) };
        let dst_slice = unsafe { slice::from_raw_parts_mut(dst, len) };

        match aes256::aes256_cbc_decrypt(key_ref, iv_ref, src_slice, dst_slice) {
            Ok(()) => TTZipStatus::Ok.to_i32(),
            Err(_) => TTZipStatus::ErrInvalidParam.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported 7z SHA-256 KDF key derivation.
///
/// # Safety
/// - `password` must be a valid null-terminated C-string.
/// - If `salt_len > 0`, `salt` must point to `salt_len` readable bytes.
/// - `out_key` must point to 32 writable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_7z_kdf_sha256(
    password: *const libc::c_char,
    salt: *const u8,
    salt_len: usize,
    num_cycles_power: u32,
    out_key: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if password.is_null() || out_key.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let c_str = unsafe { CStr::from_ptr(password) };
        let pass_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam.to_i32(),
        };

        let salt_slice = if salt.is_null() || salt_len == 0 {
            &[][..]
        } else {
            unsafe { slice::from_raw_parts(salt, salt_len) }
        };

        let derived = sha256::sha256_7z_kdf(pass_str, salt_slice, num_cycles_power);
        unsafe {
            std::ptr::copy_nonoverlapping(derived.as_ptr(), out_key, 32);
        }

        TTZipStatus::Ok.to_i32()
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}
