// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Cryptographic routines for SHA-1, HMAC-SHA1, PBKDF2-SHA1, and WinZip AES-256.
//!
//! Compliant with RFC 3174 (SHA-1), RFC 2104 / RFC 2202 (HMAC-SHA1), RFC 2898 / RFC 6070 (PBKDF2),
//! and WinZip AES AE-1 / AE-2 encryption specification.

use crate::crypto::aes256::aes256_ctr_crypt;
use crate::types::TTZipStatus;
use zeroize::{Zeroize, ZeroizeOnDrop};

// ============================================================================
// 1. Fast Streaming SHA-1 Implementation (RFC 3174)
// ============================================================================

const SHA1_INITIAL_H: [u32; 5] = [
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0,
];

#[inline(always)]
fn rol(val: u32, bits: u32) -> u32 {
    (val << bits) | (val >> (32 - bits))
}

#[inline(always)]
fn sha1_compress_block(state: &mut [u32; 5], block: &[u8; 64]) {
    let mut w = [0u32; 80];

    for i in 0..16 {
        w[i] = u32::from_be_bytes([
            block[i * 4],
            block[i * 4 + 1],
            block[i * 4 + 2],
            block[i * 4 + 3],
        ]);
    }

    for i in 16..80 {
        w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }

    let mut a = state[0];
    let mut b = state[1];
    let mut c = state[2];
    let mut d = state[3];
    let mut e = state[4];

    // Rounds 0..19
    for i in 0..20 {
        let f = (b & c) | ((!b) & d);
        let k = 0x5A827999;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 20..39
    for i in 20..40 {
        let f = b ^ c ^ d;
        let k = 0x6ED9EBA1;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 40..59
    for i in 40..60 {
        let f = (b & c) | (b & d) | (c & d);
        let k = 0x8F1BBCDC;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 60..79
    for i in 60..80 {
        let f = b ^ c ^ d;
        let k = 0xCA62C1D6;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    state[0] = state[0].wrapping_add(a);
    state[1] = state[1].wrapping_add(b);
    state[2] = state[2].wrapping_add(c);
    state[3] = state[3].wrapping_add(d);
    state[4] = state[4].wrapping_add(e);

    w.zeroize();
}

/// Fast stack-allocated streaming SHA-1 hasher.
#[derive(Clone)]
pub struct FastSha1 {
    state: [u32; 5],
    buffer: [u8; 64],
    buf_len: usize,
    total_len: u64,
}

impl Default for FastSha1 {
    fn default() -> Self {
        Self::new()
    }
}

impl FastSha1 {
    pub const fn new() -> Self {
        Self {
            state: SHA1_INITIAL_H,
            buffer: [0u8; 64],
            buf_len: 0,
            total_len: 0,
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.total_len += data.len() as u64;

        if self.buf_len > 0 {
            let take = (64 - self.buf_len).min(data.len());
            self.buffer[self.buf_len..self.buf_len + take].copy_from_slice(&data[..take]);
            self.buf_len += take;
            data = &data[take..];

            if self.buf_len == 64 {
                let block = self.buffer;
                sha1_compress_block(&mut self.state, &block);
                self.buf_len = 0;
            }
        }

        while data.len() >= 64 {
            let mut block = [0u8; 64];
            block.copy_from_slice(&data[..64]);
            sha1_compress_block(&mut self.state, &block);
            data = &data[64..];
        }

        if !data.is_empty() {
            self.buffer[..data.len()].copy_from_slice(data);
            self.buf_len = data.len();
        }
    }

    pub fn finalize(mut self) -> [u8; 20] {
        let bit_len = self.total_len * 8;
        self.buffer[self.buf_len] = 0x80;
        self.buf_len += 1;

        if self.buf_len > 56 {
            self.buffer[self.buf_len..64].fill(0);
            let block = self.buffer;
            sha1_compress_block(&mut self.state, &block);
            self.buf_len = 0;
        }

        self.buffer[self.buf_len..56].fill(0);
        self.buffer[56..64].copy_from_slice(&bit_len.to_be_bytes());
        let block = self.buffer;
        sha1_compress_block(&mut self.state, &block);

        let mut out = [0u8; 20];
        for i in 0..5 {
            out[i * 4..i * 4 + 4].copy_from_slice(&self.state[i].to_be_bytes());
        }
        out
    }
}

/// Computes SHA-1 hash for an entire slice.
#[inline]
pub fn sha1(data: &[u8]) -> [u8; 20] {
    let mut h = FastSha1::new();
    h.update(data);
    h.finalize()
}

// ============================================================================
// 2. HMAC-SHA1 and Truncated 10-byte MAC (RFC 2104)
// ============================================================================

/// Computes standard 20-byte HMAC-SHA1.
pub fn hmac_sha1(key: &[u8], data: &[u8]) -> [u8; 20] {
    let mut k_pad = [0u8; 64];
    if key.len() > 64 {
        let digest = sha1(key);
        k_pad[..20].copy_from_slice(&digest);
    } else {
        k_pad[..key.len()].copy_from_slice(key);
    }

    let mut k_ipad = [0x36u8; 64];
    let mut k_opad = [0x5cu8; 64];
    for i in 0..64 {
        k_ipad[i] ^= k_pad[i];
        k_opad[i] ^= k_pad[i];
    }

    let mut inner = FastSha1::new();
    inner.update(&k_ipad);
    inner.update(data);
    let inner_hash = inner.finalize();

    let mut outer = FastSha1::new();
    outer.update(&k_opad);
    outer.update(&inner_hash);
    let result = outer.finalize();

    k_pad.zeroize();
    k_ipad.zeroize();
    k_opad.zeroize();

    result
}

/// Computes truncated 10-byte HMAC-SHA1 tag for WinZip AES.
#[inline]
pub fn hmac_sha1_10(key: &[u8], data: &[u8]) -> [u8; 10] {
    let full = hmac_sha1(key, data);
    let mut out = [0u8; 10];
    out.copy_from_slice(&full[..10]);
    out
}

// ============================================================================
// 3. PBKDF2-HMAC-SHA1 Key Derivation (RFC 2898 / RFC 6070)
// ============================================================================

/// Derives key material using PBKDF2-HMAC-SHA1.
pub fn pbkdf2_sha1(
    password: &[u8],
    salt: &[u8],
    rounds: u32,
    out_key: &mut [u8],
) -> Result<(), TTZipStatus> {
    if password.is_empty() && salt.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }
    if rounds == 0 || out_key.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let mut k_pad = [0u8; 64];
    if password.len() > 64 {
        let digest = sha1(password);
        k_pad[..20].copy_from_slice(&digest);
    } else {
        k_pad[..password.len()].copy_from_slice(password);
    }

    let mut k_ipad = [0x36u8; 64];
    let mut k_opad = [0x5cu8; 64];
    for i in 0..64 {
        k_ipad[i] ^= k_pad[i];
        k_opad[i] ^= k_pad[i];
    }

    // Pre-calculate inner and outer context base states
    let mut base_inner = FastSha1::new();
    base_inner.update(&k_ipad);

    let mut base_outer = FastSha1::new();
    base_outer.update(&k_opad);

    let key_len = out_key.len();
    let blocks_needed = (key_len + 19) / 20;

    let mut u_digest = [0u8; 20];
    let mut t_digest = [0u8; 20];

    for block_idx in 1..=blocks_needed as u32 {
        let be_block = block_idx.to_be_bytes();

        let mut inner = base_inner.clone();
        inner.update(salt);
        inner.update(&be_block);
        let inner_hash = inner.finalize();

        let mut outer = base_outer.clone();
        outer.update(&inner_hash);
        u_digest = outer.finalize();

        t_digest.copy_from_slice(&u_digest);

        for _ in 1..rounds {
            let mut inner = base_inner.clone();
            inner.update(&u_digest);
            let inner_hash = inner.finalize();

            let mut outer = base_outer.clone();
            outer.update(&inner_hash);
            u_digest = outer.finalize();

            for k in 0..20 {
                t_digest[k] ^= u_digest[k];
            }
        }

        let offset = (block_idx as usize - 1) * 20;
        let copy_len = (offset + 20).min(key_len) - offset;
        out_key[offset..offset + copy_len].copy_from_slice(&t_digest[..copy_len]);
    }

    k_pad.zeroize();
    k_ipad.zeroize();
    k_opad.zeroize();
    u_digest.zeroize();
    t_digest.zeroize();

    Ok(())
}

// ============================================================================
// 4. WinZip AES-256 Key Derivation & Decryption / Verification Pipeline
// ============================================================================

/// Derived WinZip AES-256 key material.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct WinZipAes256Keys {
    pub enc_key: [u8; 32],
    pub auth_key: [u8; 32],
    pub pvv: [u8; 2],
}

/// Derives WinZip AES-256 keys (1000 rounds PBKDF2-HMAC-SHA1).
pub fn winzip_aes256_derive_keys(password: &str, salt: &[u8; 16]) -> Result<WinZipAes256Keys, TTZipStatus> {
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
        return Err(TTZipStatus::ErrCorruptHeader);
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sha1_nist_vectors() {
        // "abc"
        let hash = sha1(b"abc");
        assert_eq!(
            hex::encode(hash),
            "a9993e364706816aba3e25717850c26c9cd0d89d"
        );

        // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        let hash2 = sha1(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
        assert_eq!(
            hex::encode(hash2),
            "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
        );
    }

    #[test]
    fn test_hmac_sha1_rfc2202() {
        let key = [0x0bu8; 20];
        let data = b"Hi There";
        let mac = hmac_sha1(&key, data);
        assert_eq!(
            hex::encode(mac),
            "b617318655057264e28bc0b6fb378c8ef146be00"
        );
    }

    #[test]
    fn test_pbkdf2_sha1_rfc6070() {
        let password = b"password";
        let salt = b"salt";
        let mut key = [0u8; 20];
        pbkdf2_sha1(password, salt, 1, &mut key).unwrap();
        assert_eq!(
            hex::encode(key),
            "0c60c80f961f0e71f3a9b524af6012062fe037a6"
        );

        pbkdf2_sha1(password, salt, 2, &mut key).unwrap();
        assert_eq!(
            hex::encode(key),
            "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957"
        );
    }

    #[test]
    fn test_winzip_aes256_roundtrip() {
        let password = "SecretPassword123!";
        let salt = [0x55u8; 16];
        let plaintext = b"Hello WinZip AES-256 Hardware Encrypted Stream! Testing 1234567890.";

        let mut payload = Vec::new();
        winzip_aes256_encrypt_and_tag(password, &salt, plaintext, &mut payload).unwrap();
        assert_eq!(payload.len(), 16 + 2 + plaintext.len() + 10);

        let mut decrypted = vec![0u8; plaintext.len()];
        let dec_len = winzip_aes256_decrypt_and_verify(password, &payload, &mut decrypted).unwrap();
        assert_eq!(dec_len, plaintext.len());
        assert_eq!(&decrypted, plaintext);

        // Wrong password check
        let err = winzip_aes256_decrypt_and_verify("WrongPassword", &payload, &mut decrypted);
        assert_eq!(err, Err(TTZipStatus::ErrInvalidPassword));
    }
}
