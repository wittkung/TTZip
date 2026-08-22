// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for AES-256, 7z KDF, and ZipCrypto.

use crate::crypto::{aes256, sha256, zipcrypto};
use crate::ffi::helpers::{safe_cstr, safe_slice, safe_slice_mut};
use crate::types::TTZipStatus;
use std::ffi::CStr;
use std::panic::catch_unwind;

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
        if key.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        let src_slice = match unsafe { safe_slice(src, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        let dst_slice = match unsafe { safe_slice_mut(dst, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }

        // SAFETY: key is non-null and valid for 32 bytes
        let key_ref = unsafe { &*(key as *const [u8; 32]) };

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
        if key.is_null() || iv.is_null() || !len.is_multiple_of(16) {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        let src_slice = match unsafe { safe_slice(src, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        let dst_slice = match unsafe { safe_slice_mut(dst, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }

        // SAFETY: key and iv are non-null and point to 32 and 16 valid bytes
        let key_ref = unsafe { &*(key as *const [u8; 32]) };
        let iv_ref = unsafe { &*(iv as *const [u8; 16]) };

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
        if out_key.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        let pass_str = match unsafe { safe_cstr(password) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        let salt_slice = match unsafe { safe_slice(salt, salt_len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };

        let derived = sha256::sha256_7z_kdf(pass_str, salt_slice, num_cycles_power);
        // SAFETY: out_key points to at least 32 valid writable bytes
        unsafe {
            std::ptr::copy_nonoverlapping(derived.as_ptr(), out_key, 32);
        }

        TTZipStatus::Ok.to_i32()
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported ZipCrypto initial keys derivation.
///
/// # Safety
/// - `password` must be a valid null-terminated C-string.
/// - `key0`, `key1`, `key2` must point to writable `u32` variables.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zipcrypto_init_keys(
    password: *const libc::c_char,
    key0: *mut u32,
    key1: *mut u32,
    key2: *mut u32,
) -> i32 {
    let result = catch_unwind(|| {
        if password.is_null() || key0.is_null() || key1.is_null() || key2.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        // SAFETY: password is non-null
        let c_str = unsafe { CStr::from_ptr(password) };
        let bytes = c_str.to_bytes();
        let keys = zipcrypto::ZipCryptoKeys::from_password(bytes);
        unsafe {
            *key0 = keys.key0;
            *key1 = keys.key1;
            *key2 = keys.key2;
        }
        TTZipStatus::Ok.to_i32()
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported hardware-accelerated ZipCrypto stream decryption.
///
/// # Safety
/// - `key0`, `key1`, `key2` must point to readable/writable `u32` key variables.
/// - `src` must point to at least `len` valid readable bytes.
/// - `dst` must point to at least `len` valid writable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zipcrypto_decrypt_stream(
    key0: *mut u32,
    key1: *mut u32,
    key2: *mut u32,
    src: *const u8,
    len: usize,
    dst: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if key0.is_null() || key1.is_null() || key2.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }
        let src_slice = match unsafe { safe_slice(src, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        let dst_slice = match unsafe { safe_slice_mut(dst, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };

        if !std::ptr::eq(src, dst) {
            dst_slice.copy_from_slice(src_slice);
        }

        // SAFETY: key pointers are non-null and valid for mutation
        unsafe {
            zipcrypto::decrypt_stream_fast(&mut *key0, &mut *key1, &mut *key2, dst_slice);
        }
        TTZipStatus::Ok.to_i32()
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported hardware-accelerated ZipCrypto stream encryption.
///
/// # Safety
/// - `key0`, `key1`, `key2` must point to readable/writable `u32` key variables.
/// - `src` must point to at least `len` valid readable bytes.
/// - `dst` must point to at least `len` valid writable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_zipcrypto_encrypt_stream(
    key0: *mut u32,
    key1: *mut u32,
    key2: *mut u32,
    src: *const u8,
    len: usize,
    dst: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if key0.is_null() || key1.is_null() || key2.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        if len == 0 {
            return TTZipStatus::Ok.to_i32();
        }
        let src_slice = match unsafe { safe_slice(src, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };
        let dst_slice = match unsafe { safe_slice_mut(dst, len) } {
            Ok(s) => s,
            Err(st) => return st.to_i32(),
        };

        if !std::ptr::eq(src, dst) {
            dst_slice.copy_from_slice(src_slice);
        }

        // SAFETY: key pointers are non-null and valid for mutation
        unsafe {
            zipcrypto::encrypt_stream_fast(&mut *key0, &mut *key1, &mut *key2, dst_slice);
        }
        TTZipStatus::Ok.to_i32()
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}
