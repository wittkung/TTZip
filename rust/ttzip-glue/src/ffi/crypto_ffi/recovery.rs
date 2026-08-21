// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for in-memory multi-core password recovery.

use crate::crypto::recovery::{
    recover_7z_aes_rayon, recover_winzip_aes_rayon, recover_zipcrypto_rayon,
};
use libc::c_char;
use std::ffi::{CStr, CString};
use std::panic::catch_unwind;

unsafe fn parse_c_string_array<'a>(ptrs: *const *const c_char, count: usize) -> Vec<&'a str> {
    let mut out = Vec::with_capacity(count);
    if ptrs.is_null() || count == 0 {
        return out;
    }
    let slice = std::slice::from_raw_parts(ptrs, count);
    for &p in slice {
        if !p.is_null() {
            if let Ok(s) = CStr::from_ptr(p).to_str() {
                out.push(s);
            }
        }
    }
    out
}

unsafe fn write_out_string(result: Option<String>, out_buf: *mut c_char, capacity: usize) -> bool {
    if let Some(pwd) = result {
        if !out_buf.is_null() && capacity > 0 {
            if let Ok(c_str) = CString::new(pwd) {
                let bytes = c_str.as_bytes_with_nul();
                let copy_len = bytes.len().min(capacity);
                std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, out_buf, copy_len);
                if copy_len > 0 {
                    *out_buf.add(copy_len - 1) = 0;
                }
            }
        }
        true
    } else {
        if !out_buf.is_null() && capacity > 0 {
            *out_buf = 0;
        }
        false
    }
}

/// Recovers ZipCrypto password from dictionary using 12-byte header check byte.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_crypto_recover_zipcrypto(
    passwords: *const *const c_char,
    count: usize,
    enc_header: *const u8,
    check_byte: u8,
    out_found_pwd: *mut c_char,
    out_capacity: usize,
) -> bool {
    let result = catch_unwind(|| {
        if passwords.is_null() || count == 0 || enc_header.is_null() {
            return false;
        }
        let pwd_list = parse_c_string_array(passwords, count);
        let header_slice: &[u8; 12] = &*(enc_header as *const [u8; 12]);
        let found = recover_zipcrypto_rayon(&pwd_list, header_slice, check_byte);
        write_out_string(found, out_found_pwd, out_capacity)
    });
    result.unwrap_or(false)
}

/// Recovers WinZip AES-256 password from dictionary using 16-byte salt and 2-byte PVV.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_crypto_recover_winzip_aes(
    passwords: *const *const c_char,
    count: usize,
    salt: *const u8,
    stored_pvv: *const u8,
    out_found_pwd: *mut c_char,
    out_capacity: usize,
) -> bool {
    let result = catch_unwind(|| {
        if passwords.is_null() || count == 0 || salt.is_null() || stored_pvv.is_null() {
            return false;
        }
        let pwd_list = parse_c_string_array(passwords, count);
        let salt_arr: &[u8; 16] = &*(salt as *const [u8; 16]);
        let pvv_arr: &[u8; 2] = &*(stored_pvv as *const [u8; 2]);
        let found = recover_winzip_aes_rayon(&pwd_list, salt_arr, pvv_arr);
        write_out_string(found, out_found_pwd, out_capacity)
    });
    result.unwrap_or(false)
}

/// Recovers 7z AES password from dictionary using SHA-256 KDF and probe verification.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_crypto_recover_7z_aes(
    passwords: *const *const c_char,
    count: usize,
    salt: *const u8,
    salt_len: usize,
    num_cycles_power: u32,
    probe_cipher: *const u8,
    probe_len: usize,
    expected_magic: *const u8,
    magic_len: usize,
    out_found_pwd: *mut c_char,
    out_capacity: usize,
) -> bool {
    let result = catch_unwind(|| {
        if passwords.is_null() || count == 0 {
            return false;
        }
        let pwd_list = parse_c_string_array(passwords, count);
        let salt_slice = if salt.is_null() || salt_len == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(salt, salt_len)
        };
        let probe_slice = if probe_cipher.is_null() || probe_len == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(probe_cipher, probe_len)
        };
        let magic_slice = if expected_magic.is_null() || magic_len == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(expected_magic, magic_len)
        };

        let found = recover_7z_aes_rayon(
            &pwd_list,
            salt_slice,
            num_cycles_power,
            probe_slice,
            magic_slice,
        );
        write_out_string(found, out_found_pwd, out_capacity)
    });
    result.unwrap_or(false)
}
