// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Scalar implementation and constants for the traditional PKZIP 3-Key stream cipher.

pub const ZIPCRYPTO_KEY0_INIT: u32 = 0x12345678;
pub const ZIPCRYPTO_KEY1_INIT: u32 = 0x23456789;
pub const ZIPCRYPTO_KEY2_INIT: u32 = 0x34567890;
pub const ZIPCRYPTO_MULT: u32 = 134775813; // 0x08088405

/// Precomputed standard IEEE 802.3 CRC32 table (polynomial 0xEDB88320).
const fn make_crc_table() -> [u32; 256] {
    let mut table = [0u32; 256];
    let mut i = 0;
    while i < 256 {
        let mut crc = i as u32;
        let mut j = 0;
        while j < 8 {
            crc = if (crc & 1) != 0 {
                (crc >> 1) ^ 0xEDB88320
            } else {
                crc >> 1
            };
            j += 1;
        }
        table[i] = crc;
        i += 1;
    }
    table
}

pub static CRC32_TABLE: [u32; 256] = make_crc_table();

/// Computes single-byte CRC32 step using table lookup.
#[inline(always)]
pub fn crc32_byte(crc: u32, byte: u8) -> u32 {
    (crc >> 8) ^ CRC32_TABLE[((crc ^ (byte as u32)) & 0xFF) as usize]
}

/// Generates a single keystream byte from `key2`.
#[inline(always)]
pub fn decrypt_byte_key(key2: u32) -> u8 {
    let temp = (key2 as u16) | 2;
    ((temp as u32 * ((temp as u32) ^ 1)) >> 8) as u8
}

/// Performs a single key state update with plaintext byte `plain_byte`.
#[inline(always)]
pub fn update_keys(key0: &mut u32, key1: &mut u32, key2: &mut u32, plain_byte: u8) {
    *key0 = crc32_byte(*key0, plain_byte);
    *key1 = (*key1).wrapping_add(*key0 & 0xFF).wrapping_mul(ZIPCRYPTO_MULT).wrapping_add(1);
    *key2 = crc32_byte(*key2, (*key1 >> 24) as u8);
}
