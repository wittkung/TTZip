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

pub mod hmac;
pub mod scalar;
pub mod winzip;

pub use hmac::{hmac_sha1, hmac_sha1_10, pbkdf2_sha1};
pub use scalar::sha1_compress_block;
pub use winzip::{
    winzip_aes256_decrypt_and_verify, winzip_aes256_derive_keys, winzip_aes256_encrypt_and_tag,
    WinZipAes256Keys,
};

#[cfg(test)]
mod tests;

use scalar::SHA1_INITIAL_H;

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
