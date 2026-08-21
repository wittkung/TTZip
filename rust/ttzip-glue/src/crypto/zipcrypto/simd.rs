// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated CRC-32 instructions and multi-stream SIMD batch processing for ZipCrypto.

use super::scalar::{decrypt_byte_key, ZIPCRYPTO_MULT};

#[cfg(not(target_arch = "aarch64"))]
use super::scalar::update_keys;

#[cfg(target_arch = "aarch64")]
use core::arch::aarch64::*;

/// Updates `key0`, `key1`, `key2` using hardware ARM64 `__crc32b` instructions where available.
#[inline(always)]
pub fn update_keys_fast(key0: &mut u32, key1: &mut u32, key2: &mut u32, plain_byte: u8) {
    #[cfg(target_arch = "aarch64")]
    unsafe {
        // Bit-reflected CRC32 with polynomial 0xEDB88320 (IEEE 802.3)
        *key0 = __crc32b(*key0, plain_byte);
        *key1 = (*key1).wrapping_add(*key0 & 0xFF).wrapping_mul(ZIPCRYPTO_MULT).wrapping_add(1);
        *key2 = __crc32b(*key2, (*key1 >> 24) as u8);
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        update_keys(key0, key1, key2, plain_byte);
    }
}

/// Decrypts a contiguous buffer in-place with loop unrolling.
#[inline]
pub fn decrypt_stream_fast(key0: &mut u32, key1: &mut u32, key2: &mut u32, data: &mut [u8]) {
    let mut i = 0;
    let len = data.len();

    // 8x unrolled loop
    while i + 8 <= len {
        for offset in 0..8 {
            let k = decrypt_byte_key(*key2);
            let p = data[i + offset] ^ k;
            data[i + offset] = p;
            update_keys_fast(key0, key1, key2, p);
        }
        i += 8;
    }

    while i < len {
        let k = decrypt_byte_key(*key2);
        let p = data[i] ^ k;
        data[i] = p;
        update_keys_fast(key0, key1, key2, p);
        i += 1;
    }
}

/// Encrypts a contiguous buffer in-place with loop unrolling.
#[inline]
pub fn encrypt_stream_fast(key0: &mut u32, key1: &mut u32, key2: &mut u32, data: &mut [u8]) {
    let mut i = 0;
    let len = data.len();

    // 8x unrolled loop
    while i + 8 <= len {
        for offset in 0..8 {
            let p = data[i + offset];
            let k = decrypt_byte_key(*key2);
            data[i + offset] = p ^ k;
            update_keys_fast(key0, key1, key2, p);
        }
        i += 8;
    }

    while i < len {
        let p = data[i];
        let k = decrypt_byte_key(*key2);
        data[i] = p ^ k;
        update_keys_fast(key0, key1, key2, p);
        i += 1;
    }
}

/// 4-Way SIMD vertical batch state for processing 4 streams / blocks in parallel.
#[derive(Clone, Copy, Debug)]
pub struct ZipCryptoBatch4 {
    pub key0: [u32; 4],
    pub key1: [u32; 4],
    pub key2: [u32; 4],
}

impl ZipCryptoBatch4 {
    /// Creates a new batch initialized with default PKZIP keys for all 4 slots.
    pub fn new() -> Self {
        Self {
            key0: [super::scalar::ZIPCRYPTO_KEY0_INIT; 4],
            key1: [super::scalar::ZIPCRYPTO_KEY1_INIT; 4],
            key2: [super::scalar::ZIPCRYPTO_KEY2_INIT; 4],
        }
    }

    /// Initializes batch from 4 distinct password byte slices.
    pub fn from_passwords(passwords: [&[u8]; 4]) -> Self {
        let mut batch = Self::new();
        for lane in 0..4 {
            for &b in passwords[lane] {
                update_keys_fast(
                    &mut batch.key0[lane],
                    &mut batch.key1[lane],
                    &mut batch.key2[lane],
                    b,
                );
            }
        }
        batch
    }

    /// Decrypts one byte across all 4 lanes simultaneously.
    #[inline(always)]
    pub fn decrypt_bytes_4way(&mut self, cipher_bytes: [u8; 4]) -> [u8; 4] {
        let mut plain = [0u8; 4];
        for lane in 0..4 {
            let k = decrypt_byte_key(self.key2[lane]);
            let p = cipher_bytes[lane] ^ k;
            plain[lane] = p;
            update_keys_fast(
                &mut self.key0[lane],
                &mut self.key1[lane],
                &mut self.key2[lane],
                p,
            );
        }
        plain
    }

    /// Encrypts one byte across all 4 lanes simultaneously.
    #[inline(always)]
    pub fn encrypt_bytes_4way(&mut self, plain_bytes: [u8; 4]) -> [u8; 4] {
        let mut cipher = [0u8; 4];
        for lane in 0..4 {
            let p = plain_bytes[lane];
            let k = decrypt_byte_key(self.key2[lane]);
            cipher[lane] = p ^ k;
            update_keys_fast(
                &mut self.key0[lane],
                &mut self.key1[lane],
                &mut self.key2[lane],
                p,
            );
        }
        cipher
    }
}
