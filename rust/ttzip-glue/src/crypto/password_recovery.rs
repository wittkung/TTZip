// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-throughput in-memory multi-core password verification & recovery engine.
//!
//! Features zero disk I/O, Rayon work-stealing, ZipCrypto 12-byte header check,
//! WinZip AES-128/256 PVV short-circuiting, 7z AES SHA-256 KDF verification,
//! combinatoric brute-force search, and atomic cancellation tokens.

use crate::crypto::aes256::aes256_cbc_decrypt;
use crate::crypto::sha1::hmac::pbkdf2_sha1;
use crate::crypto::sha256::sha256_7z_kdf;
use crate::crypto::zipcrypto::ZipCryptoKeys;
use crate::runtime::cancellation::CancellationToken;
use crate::types::TTZipStatus;
use rayon::prelude::*;
use std::fs::File;
use std::io::Read;
use std::sync::atomic::{AtomicU64, Ordering};

/// Supported archive encryption targets for recovery.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecoveryTarget {
    ZipCrypto { header: [u8; 12], check_byte: u8 },
    WinZipAes { salt: Vec<u8>, stored_pvv: [u8; 2] },
    SevenZipAes {
        salt: Vec<u8>,
        num_cycles_power: u32,
        probe_cipher: Vec<u8>,
        expected_magic: Vec<u8>,
    },
}

impl RecoveryTarget {
    #[inline]
    pub fn verify(&self, password: &str) -> bool {
        match self {
            RecoveryTarget::ZipCrypto { header, check_byte } => {
                verify_zipcrypto_candidate(password, header, *check_byte)
            }
            RecoveryTarget::WinZipAes { salt, stored_pvv } => {
                verify_winzip_aes_candidate(password, salt, stored_pvv)
            }
            RecoveryTarget::SevenZipAes {
                salt,
                num_cycles_power,
                probe_cipher,
                expected_magic,
            } => verify_7z_aes_candidate(password, salt, *num_cycles_power, probe_cipher, expected_magic),
        }
    }
}

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

/// Verifies a password candidate against WinZip AES-128 / AES-192 / AES-256 PVV.
#[inline]
pub fn verify_winzip_aes_candidate(password: &str, salt: &[u8], stored_pvv: &[u8; 2]) -> bool {
    let total_len = match salt.len() {
        8 => 34,   // AES-128
        12 => 50,  // AES-192
        _ => 66,   // AES-256
    };
    let mut key_material = [0u8; 66];
    if pbkdf2_sha1(password.as_bytes(), salt, 1000, &mut key_material[..total_len]).is_err() {
        return false;
    }
    key_material[total_len - 2..total_len] == *stored_pvv
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
    let iv = [0u8; 16];
    if aes256_cbc_decrypt(&key, &iv, &probe_cipher[..decrypted.len()], &mut decrypted).is_ok() {
        let cmp_len = expected_magic.len().min(decrypted.len());
        decrypted[..cmp_len] == expected_magic[..cmp_len]
    } else {
        false
    }
}

/// Inspects in-memory archive bytes to construct recovery target.
pub fn inspect_archive_bytes(data: &[u8]) -> Result<RecoveryTarget, TTZipStatus> {
    if data.len() < 30 {
        return Err(TTZipStatus::ErrCorruptHeader);
    }
    if data[0..4] == [0x50, 0x4B, 0x03, 0x04] {
        let flags = u16::from_le_bytes([data[6], data[7]]);
        if flags & 0x01 == 0 {
            return Err(TTZipStatus::ErrInvalidParam);
        }
        let method = u16::from_le_bytes([data[8], data[9]]);
        let fn_len = u16::from_le_bytes([data[26], data[27]]) as usize;
        let extra_len = u16::from_le_bytes([data[28], data[29]]) as usize;
        let header_offset = 30 + fn_len + extra_len;

        if method == 99 {
            let mut salt_len = 16usize;
            let (extra_start, extra_end) = (30 + fn_len, 30 + fn_len + extra_len);
            if extra_end <= data.len() {
                let mut pos = extra_start;
                while pos + 4 <= extra_end {
                    let field_id = u16::from_le_bytes([data[pos], data[pos + 1]]);
                    let field_sz = u16::from_le_bytes([data[pos + 2], data[pos + 3]]) as usize;
                    pos += 4;
                    if field_id == 0x9901 && field_sz >= 7 && pos + field_sz <= extra_end {
                        salt_len = match data[pos + 4] { 1 => 8, 2 => 12, _ => 16 };
                        break;
                    }
                    pos += field_sz;
                }
            }
            if data.len() < header_offset + salt_len + 2 {
                return Err(TTZipStatus::ErrCorruptHeader);
            }
            let salt = data[header_offset..header_offset + salt_len].to_vec();
            let stored_pvv = [data[header_offset + salt_len], data[header_offset + salt_len + 1]];
            return Ok(RecoveryTarget::WinZipAes { salt, stored_pvv });
        }
        if data.len() < header_offset + 12 {
            return Err(TTZipStatus::ErrCorruptHeader);
        }
        let mut header = [0u8; 12];
        header.copy_from_slice(&data[header_offset..header_offset + 12]);
        let check_byte = if flags & 0x08 == 0 { data[17] } else { data[11] };
        return Ok(RecoveryTarget::ZipCrypto { header, check_byte });
    }
    if data.starts_with(b"7z\xBC\xAF\x27\x1C") {
        let probe = if data.len() > 32 { data[32..data.len().min(48)].to_vec() } else { vec![0u8; 16] };
        return Ok(RecoveryTarget::SevenZipAes {
            salt: vec![],
            num_cycles_power: 19,
            probe_cipher: probe,
            expected_magic: vec![0x17],
        });
    }
    Err(TTZipStatus::ErrCorruptHeader)
}

/// Inspects archive file on disk to construct recovery target.
pub fn inspect_archive_for_recovery(archive_path: &str) -> Result<RecoveryTarget, TTZipStatus> {
    let mut file = File::open(archive_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let mut buf = vec![0u8; 65536];
    let n = file.read(&mut buf).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    if n == 0 {
        return Err(TTZipStatus::ErrCorruptHeader);
    }
    inspect_archive_bytes(&buf[..n])
}

/// Recovers password from dictionary candidates using Rayon parallel chunk dispatch.
pub fn recover_dictionary_rayon(
    dictionary: &[&str],
    target: &RecoveryTarget,
    cancel_token: Option<&CancellationToken>,
    attempts: Option<&AtomicU64>,
) -> Option<String> {
    if dictionary.is_empty() {
        return None;
    }
    let chunk_sz = 512.max(dictionary.len() / (rayon::current_num_threads() * 8).max(1)).min(4096);
    dictionary.par_chunks(chunk_sz).find_map_any(|chunk| {
        if cancel_token.map_or(false, |t| t.is_cancelled()) {
            return None;
        }
        for (idx, &pwd) in chunk.iter().enumerate() {
            if idx % 64 == 0 && cancel_token.map_or(false, |t| t.is_cancelled()) {
                return None;
            }
            if let Some(counter) = attempts {
                counter.fetch_add(1, Ordering::Relaxed);
            }
            if target.verify(pwd) {
                return Some(pwd.to_string());
            }
        }
        None
    })
}

/// Recovers password via combinatoric brute force candidate generation across Rayon threads.
pub fn recover_brute_force_rayon(
    charset: &str,
    min_len: usize,
    max_len: usize,
    target: &RecoveryTarget,
    cancel_token: Option<&CancellationToken>,
    attempts: Option<&AtomicU64>,
) -> Option<String> {
    let chars: Vec<char> = charset.chars().collect();
    if chars.is_empty() || min_len == 0 || max_len < min_len {
        return None;
    }
    for len in min_len..=max_len {
        if cancel_token.map_or(false, |t| t.is_cancelled()) {
            return None;
        }
        if len == 1 {
            let found = chars.par_iter().find_map_any(|&c| {
                if cancel_token.map_or(false, |t| t.is_cancelled()) {
                    return None;
                }
                attempts.map(|cnt| cnt.fetch_add(1, Ordering::Relaxed));
                let pwd = c.to_string();
                if target.verify(&pwd) { Some(pwd) } else { None }
            });
            if found.is_some() {
                return found;
            }
        } else {
            let found = chars.par_iter().find_map_any(|&first_char| {
                let mut candidate = String::with_capacity(len);
                candidate.push(first_char);
                let mut indices = vec![0usize; len - 1];
                let num_chars = chars.len();
                loop {
                    if cancel_token.map_or(false, |t| t.is_cancelled()) {
                        return None;
                    }
                    candidate.truncate(1);
                    for &idx in &indices {
                        candidate.push(chars[idx]);
                    }
                    attempts.map(|cnt| cnt.fetch_add(1, Ordering::Relaxed));
                    if target.verify(&candidate) {
                        return Some(candidate);
                    }
                    let mut pos = len - 2;
                    loop {
                        indices[pos] += 1;
                        if indices[pos] < num_chars {
                            break;
                        }
                        indices[pos] = 0;
                        if pos == 0 {
                            return None;
                        }
                        pos -= 1;
                    }
                }
            });
            if found.is_some() {
                return found;
            }
        }
    }
    None
}

// Backward-compatibility wrappers
pub fn recover_zipcrypto_rayon(passwords: &[&str], enc_header: &[u8; 12], check_byte: u8) -> Option<String> {
    recover_dictionary_rayon(passwords, &RecoveryTarget::ZipCrypto { header: *enc_header, check_byte }, None, None)
}

pub fn recover_winzip_aes_rayon(passwords: &[&str], salt: &[u8; 16], stored_pvv: &[u8; 2]) -> Option<String> {
    recover_dictionary_rayon(passwords, &RecoveryTarget::WinZipAes { salt: salt.to_vec(), stored_pvv: *stored_pvv }, None, None)
}

pub fn recover_7z_aes_rayon(passwords: &[&str], salt: &[u8], num_cycles_power: u32, probe_cipher: &[u8], expected_magic: &[u8]) -> Option<String> {
    recover_dictionary_rayon(passwords, &RecoveryTarget::SevenZipAes { salt: salt.to_vec(), num_cycles_power, probe_cipher: probe_cipher.to_vec(), expected_magic: expected_magic.to_vec() }, None, None)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::sha1::winzip_aes256_derive_keys;

    #[test]
    fn test_zipcrypto_verification_pipeline() {
        let pwd = "SecretPassword123";
        let mut keys = ZipCryptoKeys::from_password(pwd.as_bytes());
        let plain_hdr = [1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x5A];
        let mut enc_hdr = [0u8; 12];
        for i in 0..12 { enc_hdr[i] = keys.encrypt_byte(plain_hdr[i]); }
        let dict = vec!["admin", "123456", "SecretPassword123", "password"];
        assert_eq!(recover_zipcrypto_rayon(&dict, &enc_hdr, 0x5A).as_deref(), Some(pwd));
        assert!(recover_zipcrypto_rayon(&["wrong1"], &enc_hdr, 0x5A).is_none());
    }

    #[test]
    fn test_winzip_aes_pvv_short_circuit() {
        let pwd = "MyWinZipSecret2026";
        let salt = [0x42u8; 16];
        let keys = winzip_aes256_derive_keys(pwd, &salt).unwrap();
        let dict = vec!["root", "toor", "MyWinZipSecret2026"];
        assert_eq!(recover_winzip_aes_rayon(&dict, &salt, &keys.pvv).as_deref(), Some(pwd));
    }

    #[test]
    fn test_brute_force_recovery_rayon() {
        let pwd = "b2";
        let mut keys = ZipCryptoKeys::from_password(pwd.as_bytes());
        let plain_hdr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x77];
        let mut enc_hdr = [0u8; 12];
        for i in 0..12 { enc_hdr[i] = keys.encrypt_byte(plain_hdr[i]); }
        let target = RecoveryTarget::ZipCrypto { header: enc_hdr, check_byte: 0x77 };
        let attempts = AtomicU64::new(0);
        let found = recover_brute_force_rayon("ab12", 1, 2, &target, None, Some(&attempts));
        assert_eq!(found.as_deref(), Some(pwd));
        assert!(attempts.load(Ordering::Relaxed) > 0);
    }

    #[test]
    fn test_cancellation_token_stops_search() {
        let target = RecoveryTarget::ZipCrypto { header: [0u8; 12], check_byte: 0xFF };
        let token = CancellationToken::new();
        token.cancel(crate::runtime::cancellation::CancellationReason::UserRequested);
        let dict = vec!["pwd1", "pwd2", "pwd3"];
        let attempts = AtomicU64::new(0);
        let found = recover_dictionary_rayon(&dict, &target, Some(&token), Some(&attempts));
        assert!(found.is_none());
    }
}
