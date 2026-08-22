// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for Secure Password Vault with AES-256-GCM and memory zeroization.

use crate::crypto::vault;
use crate::ffi::helpers::{safe_slice, safe_slice_mut};
use crate::types::TTZipStatus;
use std::panic::catch_unwind;

/// C-ABI exported AES-256-GCM vault encryption.
///
/// # Safety
/// - `key` must point to 32 bytes of valid readable memory.
/// - `iv` must point to 12 bytes of valid readable memory.
/// - If `src_len > 0`, `src` must point to `src_len` readable bytes.
/// - If `aad_len > 0`, `aad` must point to `aad_len` readable bytes.
/// - `out_cipher` must point to `src_len` writable bytes.
/// - `out_tag` must point to 16 writable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vault_encrypt_key(
    key: *const u8,
    iv: *const u8,
    src: *const u8,
    src_len: usize,
    aad: *const u8,
    aad_len: usize,
    out_cipher: *mut u8,
    out_tag: *mut u8,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if key.is_null() || iv.is_null() || out_tag.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let src_slice = match unsafe { safe_slice(src, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let aad_slice = match unsafe { safe_slice(aad, aad_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let cipher_slice = match unsafe { safe_slice_mut(out_cipher, src_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        // SAFETY: key, iv, and out_tag are verified non-null and correctly sized
        let key_ref = unsafe { &*(key as *const [u8; 32]) };
        let iv_ref = unsafe { &*(iv as *const [u8; 12]) };
        let tag_ref = unsafe { &mut *(out_tag as *mut [u8; 16]) };

        match vault::aes256_gcm_encrypt(key_ref, iv_ref, src_slice, aad_slice, cipher_slice, tag_ref) {
            Ok(()) => TTZipStatus::Ok,
            Err(e) => e,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI exported AES-256-GCM vault decryption.
///
/// # Safety
/// - `key` must point to 32 bytes of valid readable memory.
/// - `iv` must point to 12 bytes of valid readable memory.
/// - If `cipher_len > 0`, `cipher` must point to `cipher_len` readable bytes.
/// - If `aad_len > 0`, `aad` must point to `aad_len` readable bytes.
/// - `tag` must point to 16 readable bytes.
/// - `out_plain` must point to `cipher_len` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vault_decrypt_key(
    key: *const u8,
    iv: *const u8,
    cipher: *const u8,
    cipher_len: usize,
    aad: *const u8,
    aad_len: usize,
    tag: *const u8,
    out_plain: *mut u8,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if key.is_null() || iv.is_null() || tag.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let cipher_slice = match unsafe { safe_slice(cipher, cipher_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let aad_slice = match unsafe { safe_slice(aad, aad_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let plain_slice = match unsafe { safe_slice_mut(out_plain, cipher_len) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        // SAFETY: key, iv, and tag are verified non-null and correctly sized
        let key_ref = unsafe { &*(key as *const [u8; 32]) };
        let iv_ref = unsafe { &*(iv as *const [u8; 12]) };
        let tag_ref = unsafe { &*(tag as *const [u8; 16]) };

        match vault::aes256_gcm_decrypt(key_ref, iv_ref, cipher_slice, aad_slice, tag_ref, plain_slice) {
            Ok(()) => TTZipStatus::Ok,
            Err(e) => e,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI exported secure memory wipe with SeqCst compiler fence.
///
/// # Safety
/// - `ptr` must be valid for writes of `len` bytes, or null if `len == 0`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vault_wipe(ptr: *mut u8, len: usize) {
    let _ = catch_unwind(|| {
        vault::secure_wipe(ptr, len);
    });
}
