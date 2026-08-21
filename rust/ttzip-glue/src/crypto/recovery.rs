// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-throughput in-memory multi-core password verification pipeline.
//!
//! Features zero disk I/O, Rayon multi-threaded worker dispatch, ZipCrypto 12-byte verification,
//! WinZip AES 2-byte PVV short-circuiting, and 7z AES SHA-256 KDF verification.

use crate::crypto::aes256::aes256_cbc_decrypt;
use crate::crypto::sha1::winzip_aes256_derive_keys;
use crate::crypto::sha256::sha256_7z_kdf;
use crate::crypto::zipcrypto::ZipCryptoKeys;
use rayon::prelude::*;

/// Verifies a password candidate against a 12-byte traditional ZipCrypto header.
#[inline]
pub fn verify_zipcrypto_candidate(password: &str, enc_header: &[u8; 12], check_byte: u8) -> bool {
    let mut keys = ZipCryptoKeys::from_password(password.as_bytes());
    let mut last_dec = 0u8;
    for &b in enc_header {
        last_dec = keys.decrypt_byte(b);
    }
    last_dec == check_byte
}

/// Verifies a password candidate against a WinZip AES-256 16-byte salt and 2-byte PVV.
#[inline]
pub fn verify_winzip_aes_candidate(password: &str, salt: &[u8; 16], stored_pvv: &[u8; 2]) -> bool {
    if let Ok(keys) = winzip_aes256_derive_keys(password, salt) {
        keys.pvv == *stored_pvv
    } else {
        false
    }
}

/// Verifies a password candidate against 7-Zip SHA-256 KDF and probe ciphertext.
pub fn verify_7z_aes_candidate(
    password: &str,
    salt: &[u8],
    num_cycles_power: u32,
    probe_cipher: &[u8],
    expected_magic: &[u8],
) -> bool {
    let key = sha256_7z_kdf(password, salt, num_cycles_power);
    if probe_cipher.is_empty() || expected_magic.is_empty() {
        return true;
    }

    if probe_cipher.len() < 16 {
        return false;
    }

    let mut decrypted = vec![0u8; (probe_cipher.len() / 16) * 16];
    let iv = [0u8; 16]; // 7z AES uses zero or stored IV for header stream
    if aes256_cbc_decrypt(&key, &iv, &probe_cipher[..decrypted.len()], &mut decrypted).is_ok() {
        let cmp_len = expected_magic.len().min(decrypted.len());
        decrypted[..cmp_len] == expected_magic[..cmp_len]
    } else {
        false
    }
}

/// Recovers ZipCrypto password across multi-threaded Rayon worker pool.
pub fn recover_zipcrypto_rayon(
    passwords: &[&str],
    enc_header: &[u8; 12],
    check_byte: u8,
) -> Option<String> {
    passwords
        .par_iter()
        .find_any(|&&pwd| verify_zipcrypto_candidate(pwd, enc_header, check_byte))
        .map(|&s| s.to_string())
}

/// Recovers WinZip AES-256 password across multi-threaded Rayon worker pool.
pub fn recover_winzip_aes_rayon(
    passwords: &[&str],
    salt: &[u8; 16],
    stored_pvv: &[u8; 2],
) -> Option<String> {
    passwords
        .par_iter()
        .find_any(|&&pwd| verify_winzip_aes_candidate(pwd, salt, stored_pvv))
        .map(|&s| s.to_string())
}

/// Recovers 7z AES password across multi-threaded Rayon worker pool.
pub fn recover_7z_aes_rayon(
    passwords: &[&str],
    salt: &[u8],
    num_cycles_power: u32,
    probe_cipher: &[u8],
    expected_magic: &[u8],
) -> Option<String> {
    passwords
        .par_iter()
        .find_any(|&&pwd| {
            verify_7z_aes_candidate(pwd, salt, num_cycles_power, probe_cipher, expected_magic)
        })
        .map(|&s| s.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zipcrypto_verification_pipeline() {
        let correct_pwd = "SecretPassword123";
        let mut keys = ZipCryptoKeys::from_password(correct_pwd.as_bytes());

        let plain_header = [1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x5A];
        let mut enc_header = [0u8; 12];
        for i in 0..12 {
            enc_header[i] = keys.encrypt_byte(plain_header[i]);
        }

        let dict = vec!["admin", "123456", "SecretPassword123", "password"];
        let found = recover_zipcrypto_rayon(&dict, &enc_header, 0x5A);
        assert_eq!(found.as_deref(), Some(correct_pwd));

        let fail = recover_zipcrypto_rayon(&["wrong1", "wrong2"], &enc_header, 0x5A);
        assert!(fail.is_none());
    }

    #[test]
    fn test_winzip_aes_pvv_short_circuit() {
        let correct_pwd = "MyWinZipSecret2026";
        let salt = [0x42u8; 16];
        let keys = winzip_aes256_derive_keys(correct_pwd, &salt).expect("derive");

        let dict = vec!["root", "toor", "MyWinZipSecret2026", "guest"];
        let found = recover_winzip_aes_rayon(&dict, &salt, &keys.pvv);
        assert_eq!(found.as_deref(), Some(correct_pwd));
    }
}
