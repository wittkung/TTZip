// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Secure Password Vault engine with Zeroize Compiler Fence and AES-256-GCM.
//!
//! Complies with NIST SP 800-38D (Galois/Counter Mode) and provides
//! Dead-Store Elimination immune memory sanitization with atomic compiler fences.

use crate::crypto::aes256::Aes256Context;
use crate::types::TTZipStatus;
use std::sync::atomic::{compiler_fence, Ordering};
use zeroize::{Zeroize, ZeroizeOnDrop};

/// S-Box for AES block encryption (scalar fallback).
#[cfg(not(target_arch = "aarch64"))]
static SBOX: [u8; 256] = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15, 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73, 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf, 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,

];

#[cfg(not(target_arch = "aarch64"))]
#[inline(always)]
fn xtime(b: u8) -> u8 {
    if (b & 0x80) != 0 { (b << 1) ^ 0x1b } else { b << 1 }
}



/// Encrypts a single 16-byte block with AES-256.
#[inline]
pub fn aes256_encrypt_block(ctx: &Aes256Context, input: &[u8; 16], output: &mut [u8; 16]) {
    #[cfg(target_arch = "aarch64")]
    unsafe {
        use core::arch::aarch64::*;
        let mut b = vld1q_u8(input.as_ptr());
        for r in 0..13 {
            let rk = vld1q_u8(ctx.round_keys_enc[r].as_ptr());
            b = vaesmcq_u8(vaeseq_u8(b, rk));
        }
        let rk13 = vld1q_u8(ctx.round_keys_enc[13].as_ptr());
        let rk14 = vld1q_u8(ctx.round_keys_enc[14].as_ptr());
        b = veorq_u8(vaeseq_u8(b, rk13), rk14);
        vst1q_u8(output.as_mut_ptr(), b);
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        let mut state = *input;
        for i in 0..16 {
            state[i] ^= ctx.round_keys_enc[0][i];
        }
        for r in 1..14 {
            let mut next = [0u8; 16];
            for &c in &[0, 4, 8, 12] {
                let s0 = SBOX[state[c] as usize];
                let s1 = SBOX[state[(c + 5) % 16] as usize];
                let s2 = SBOX[state[(c + 10) % 16] as usize];
                let s3 = SBOX[state[(c + 15) % 16] as usize];

                next[c] = xtime(s0 ^ s1) ^ s1 ^ s2 ^ s3 ^ ctx.round_keys_enc[r][c];
                next[c + 1] = xtime(s1 ^ s2) ^ s2 ^ s3 ^ s0 ^ ctx.round_keys_enc[r][c + 1];
                next[c + 2] = xtime(s2 ^ s3) ^ s3 ^ s0 ^ s1 ^ ctx.round_keys_enc[r][c + 2];
                next[c + 3] = xtime(s3 ^ s0) ^ s0 ^ s1 ^ s2 ^ ctx.round_keys_enc[r][c + 3];
            }
            state = next;
        }

        for &c in &[0, 4, 8, 12] {
            output[c] = SBOX[state[c] as usize] ^ ctx.round_keys_enc[14][c];
            output[c + 1] = SBOX[state[(c + 5) % 16] as usize] ^ ctx.round_keys_enc[14][c + 1];
            output[c + 2] = SBOX[state[(c + 10) % 16] as usize] ^ ctx.round_keys_enc[14][c + 2];
            output[c + 3] = SBOX[state[(c + 15) % 16] as usize] ^ ctx.round_keys_enc[14][c + 3];
        }
    }
}


/// GHASH authenticator over GF(2^128).
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct GHash {
    h: [u8; 16],
    state: [u8; 16],
}

impl GHash {
    pub fn new(h: &[u8; 16]) -> Self {
        Self {
            h: *h,
            state: [0u8; 16],
        }
    }

    /// GF(2^128) multiplication with irreducible polynomial x^128 + x^7 + x^2 + x + 1.
    pub fn mul_h(x: &[u8; 16], h: &[u8; 16]) -> [u8; 16] {
        let mut z = [0u64; 2];
        let mut v = [
            u64::from_be_bytes(h[0..8].try_into().unwrap()),
            u64::from_be_bytes(h[8..16].try_into().unwrap()),
        ];

        for i in 0..128 {
            let byte_idx = i / 8;
            let bit_idx = 7 - (i % 8);
            if ((x[byte_idx] >> bit_idx) & 1) != 0 {
                z[0] ^= v[0];
                z[1] ^= v[1];
            }
            let lsb = v[1] & 1;
            v[1] = (v[1] >> 1) | (v[0] << 63);
            v[0] >>= 1;
            if lsb != 0 {
                v[0] ^= 0xe100_0000_0000_0000;
            }
        }

        let mut out = [0u8; 16];
        out[0..8].copy_from_slice(&z[0].to_be_bytes());
        out[8..16].copy_from_slice(&z[1].to_be_bytes());
        out
    }

    pub fn update_block(&mut self, block: &[u8; 16]) {
        let mut x = [0u8; 16];
        for i in 0..16 {
            x[i] = self.state[i] ^ block[i];
        }
        self.state = Self::mul_h(&x, &self.h);
    }

    pub fn update(&mut self, mut data: &[u8]) {
        let mut block = [0u8; 16];
        while data.len() >= 16 {
            block.copy_from_slice(&data[..16]);
            self.update_block(&block);
            data = &data[16..];
        }
        if !data.is_empty() {
            block.fill(0);
            block[..data.len()].copy_from_slice(data);
            self.update_block(&block);
        }
    }

    pub fn finalize(self) -> [u8; 16] {
        self.state
    }
}

/// Constant-time 16-byte slice comparison to prevent timing side-channel leaks.
#[inline]
pub fn constant_time_eq_16(a: &[u8; 16], b: &[u8; 16]) -> bool {
    let mut diff = 0u8;
    for i in 0..16 {
        diff |= a[i] ^ b[i];
    }
    diff == 0
}

/// Dead-Store Elimination immune memory sanitization with SeqCst compiler fence.
#[inline]
pub fn secure_wipe(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    unsafe {
        for i in 0..len {
            std::ptr::write_volatile(ptr.add(i), 0);
        }
        compiler_fence(Ordering::SeqCst);
    }
}

/// Dead-Store Elimination immune slice wiper.
#[inline]
pub fn secure_wipe_slice(slice: &mut [u8]) {
    secure_wipe(slice.as_mut_ptr(), slice.len());
}

fn gcm_ctr_crypt(ctx: &Aes256Context, iv: &[u8; 12], src: &[u8], dst: &mut [u8]) {
    let mut ctr_block = [0u8; 16];
    ctr_block[..12].copy_from_slice(iv);

    let num_blocks = src.len().div_ceil(16);
    for i in 0..num_blocks {
        let counter_val = (i as u32).wrapping_add(2);
        ctr_block[12..16].copy_from_slice(&counter_val.to_be_bytes());

        let mut keystream = [0u8; 16];
        aes256_encrypt_block(ctx, &ctr_block, &mut keystream);

        let block_offset = i * 16;
        let block_len = (src.len() - block_offset).min(16);
        for k in 0..block_len {
            dst[block_offset + k] = src[block_offset + k] ^ keystream[k];
        }
        keystream.zeroize();
    }
    ctr_block.zeroize();
}

fn gcm_compute_tag(h: &[u8; 16], tag_mask: &[u8; 16], aad: &[u8], ciphertext: &[u8]) -> [u8; 16] {
    let mut ghash = GHash::new(h);
    if !aad.is_empty() {
        ghash.update(aad);
    }
    if !ciphertext.is_empty() {
        ghash.update(ciphertext);
    }

    let mut len_block = [0u8; 16];
    len_block[0..8].copy_from_slice(&((aad.len() as u64) * 8).to_be_bytes());
    len_block[8..16].copy_from_slice(&((ciphertext.len() as u64) * 8).to_be_bytes());
    ghash.update_block(&len_block);

    let s = ghash.finalize();
    let mut tag = [0u8; 16];
    for i in 0..16 {
        tag[i] = s[i] ^ tag_mask[i];
    }
    len_block.zeroize();
    tag
}

/// AES-256-GCM authenticated encryption (NIST SP 800-38D).
pub fn aes256_gcm_encrypt(
    key: &[u8; 32],
    iv: &[u8; 12],
    plaintext: &[u8],
    aad: &[u8],
    ciphertext: &mut [u8],
    tag: &mut [u8; 16],
) -> Result<(), TTZipStatus> {
    if ciphertext.len() < plaintext.len() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let ctx = Aes256Context::new(key);
    let mut h = [0u8; 16];
    aes256_encrypt_block(&ctx, &[0u8; 16], &mut h);

    let mut j0 = [0u8; 16];
    j0[..12].copy_from_slice(iv);
    j0[15] = 1;

    let mut tag_mask = [0u8; 16];
    aes256_encrypt_block(&ctx, &j0, &mut tag_mask);

    gcm_ctr_crypt(&ctx, iv, plaintext, &mut ciphertext[..plaintext.len()]);
    *tag = gcm_compute_tag(&h, &tag_mask, aad, &ciphertext[..plaintext.len()]);

    h.zeroize();
    j0.zeroize();
    tag_mask.zeroize();
    compiler_fence(Ordering::SeqCst);

    Ok(())
}

/// AES-256-GCM authenticated decryption (NIST SP 800-38D).
pub fn aes256_gcm_decrypt(
    key: &[u8; 32],
    iv: &[u8; 12],
    ciphertext: &[u8],
    aad: &[u8],
    tag: &[u8; 16],
    plaintext: &mut [u8],
) -> Result<(), TTZipStatus> {
    if plaintext.len() < ciphertext.len() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let ctx = Aes256Context::new(key);
    let mut h = [0u8; 16];
    aes256_encrypt_block(&ctx, &[0u8; 16], &mut h);

    let mut j0 = [0u8; 16];
    j0[..12].copy_from_slice(iv);
    j0[15] = 1;

    let mut tag_mask = [0u8; 16];
    aes256_encrypt_block(&ctx, &j0, &mut tag_mask);

    let mut expected_tag = gcm_compute_tag(&h, &tag_mask, aad, ciphertext);

    if !constant_time_eq_16(tag, &expected_tag) {
        secure_wipe_slice(plaintext);
        h.zeroize();
        j0.zeroize();
        tag_mask.zeroize();
        expected_tag.zeroize();
        compiler_fence(Ordering::SeqCst);
        return Err(TTZipStatus::ErrInvalidPassword);
    }

    gcm_ctr_crypt(&ctx, iv, ciphertext, &mut plaintext[..ciphertext.len()]);

    h.zeroize();
    j0.zeroize();
    tag_mask.zeroize();
    expected_tag.zeroize();
    compiler_fence(Ordering::SeqCst);

    Ok(())
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_aes256_gcm_basic_roundtrip() {
        let key = [0x42u8; 32];
        let iv = [0x12u8; 12];
        let plaintext = b"VaultCredentialsPayload2026";
        let aad = b"VaultHeader";
        let mut cipher = vec![0u8; plaintext.len()];
        let mut tag = [0u8; 16];

        aes256_gcm_encrypt(&key, &iv, plaintext, aad, &mut cipher, &mut tag).unwrap();
        assert_ne!(&cipher[..], plaintext);

        let mut decrypted = vec![0u8; cipher.len()];
        aes256_gcm_decrypt(&key, &iv, &cipher, aad, &tag, &mut decrypted).unwrap();
        assert_eq!(&decrypted[..], plaintext);
    }

    #[test]
    fn test_secure_wipe_compiler_fence() {
        let mut sensitive = [0xAAu8; 64];
        secure_wipe(sensitive.as_mut_ptr(), sensitive.len());
        assert_eq!(sensitive, [0u8; 64]);
    }
}

