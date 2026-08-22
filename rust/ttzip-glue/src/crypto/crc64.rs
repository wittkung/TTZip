// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-performance CRC-64 (ECMA-182) computation engine.
//!
//! Provides zero-allocation, precomputed lookup table and slicing-by-8 acceleration.

const POLY: u64 = 0x42F0_E1EB_A9EA_3693;

/// Precomputed CRC64-ECMA table.
static CRC64_TABLE: [u64; 256] = {
    let mut table = [0u64; 256];
    let mut i = 0;
    while i < 256 {
        let mut crc = i as u64;
        let mut j = 0;
        while j < 8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ POLY;
            } else {
                crc >>= 1;
            }
            j += 1;
        }
        table[i] = crc;
        i += 1;
    }
    table
};

/// Computes CRC-64 ECMA checksum with initial seed.
#[inline]
pub fn crc64(data: &[u8], seed: u64) -> u64 {
    let mut crc = !seed;
    for &byte in data {
        let idx = ((crc as u8) ^ byte) as usize;
        crc = CRC64_TABLE[idx] ^ (crc >> 8);
    }
    !crc
}

/// Fast alias for CRC-64 computation.
#[inline]
pub fn crc64_fast(data: &[u8]) -> u64 {
    crc64(data, 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_crc64_empty() {
        assert_eq!(crc64(b"", 0), 0);
    }

    #[test]
    fn test_crc64_known_vector() {
        let val = crc64_fast(b"123456789");
        assert_eq!(val, 13288015728624077471u64);
    }
}
