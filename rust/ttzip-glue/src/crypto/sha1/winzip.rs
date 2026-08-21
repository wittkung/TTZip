// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! WinZip AES-256 Key Derivation & Decryption / Verification Pipeline.

use super::hmac::{hmac_sha1_10, pbkdf2_sha1};
use crate::crypto::aes256::aes256_ctr_crypt;
use crate::types::TTZipStatus;
use zeroize::{Zeroize, ZeroizeOnDrop};

/// Derived WinZip AES-256 key material.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct WinZipAes256Keys {
    pub enc_key: [u8; 32],
    pub auth_key: [u8; 32],
    pub pvv: [u8; 2],
}

/// Derives WinZip AES-256 keys (1000 rounds PBKDF2-HMAC-SHA1).
pub fn winzip_aes256_derive_keys(
    password: &str,
    salt: &[u8; 16],
) -> Result<WinZipAes256Keys, TTZipStatus> {
    let mut key_material = [0u8; 66]; // 32 enc + 32 auth + 2 pvv
    pbkdf2_sha1(password.as_bytes(), salt, 1000, &mut key_material)?;

    let mut keys = WinZipAes256Keys {
        enc_key: [0u8; 32],
        auth_key: [0u8; 32],
        pvv: [0u8; 2],
    };

    keys.enc_key.copy_from_slice(&key_material[0..32]);
    keys.auth_key.copy_from_slice(&key_material[32..64]);
    keys.pvv.copy_from_slice(&key_material[64..66]);

    key_material.zeroize();
    Ok(keys)
}

/// Decrypts and authenticates a WinZip AES-256 payload.
///
/// Encrypted payload format: `Salt(16) | PVV(2) | Ciphertext(N) | HMAC-SHA1(10)`
pub fn winzip_aes256_decrypt_and_verify(
    password: &str,
    enc_payload: &[u8],
    dst: &mut [u8],
) -> Result<usize, TTZipStatus> {
    if enc_payload.len() < 28 {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let mut salt = [0u8; 16];
    salt.copy_from_slice(&enc_payload[0..16]);
    let stored_pvv = [enc_payload[16], enc_payload[17]];

    let cipher_len = enc_payload.len() - 28;
    let ciphertext = &enc_payload[18..18 + cipher_len];
    let stored_mac = &enc_payload[18 + cipher_len..];

    let keys = winzip_aes256_derive_keys(password, &salt)?;

    // 1. Password verification check
    if keys.pvv != stored_pvv {
        return Err(TTZipStatus::ErrInvalidPassword);
    }

    // 2. Authentication check
    let computed_mac = hmac_sha1_10(&keys.auth_key, ciphertext);
    if computed_mac != stored_mac {
        return Err(TTZipStatus::ErrInvalidPassword);
    }

    if dst.len() < cipher_len {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    // 3. Hardware AES-256-CTR decryption (initial counter = 1)
    aes256_ctr_crypt(&keys.enc_key, 1, ciphertext, &mut dst[..cipher_len])
        .map_err(|_| TTZipStatus::ErrExtractionFailed)?;

    Ok(cipher_len)
}

/// Encrypts and authenticates plaintext into a full WinZip AES-256 payload.
pub fn winzip_aes256_encrypt_and_tag(
    password: &str,
    salt: &[u8; 16],
    plaintext: &[u8],
    out_payload: &mut Vec<u8>,
) -> Result<(), TTZipStatus> {
    let keys = winzip_aes256_derive_keys(password, salt)?;

    out_payload.reserve(16 + 2 + plaintext.len() + 10);
    out_payload.extend_from_slice(salt);
    out_payload.extend_from_slice(&keys.pvv);

    let cipher_start = out_payload.len();
    out_payload.resize(cipher_start + plaintext.len(), 0);

    aes256_ctr_crypt(&keys.enc_key, 1, plaintext, &mut out_payload[cipher_start..])
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    let tag = hmac_sha1_10(&keys.auth_key, &out_payload[cipher_start..]);
    out_payload.extend_from_slice(&tag);

    Ok(())
}
