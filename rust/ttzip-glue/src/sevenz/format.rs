// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip (7z) binary format definitions, Varint encoding/decoding, and Signature Header.

use crate::crypto::crc32::crc32_fast;
use crate::types::TTZipStatus;

pub const SEVENZ_SIGNATURE: [u8; 6] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]; // '7', 'z', 0xBC, 0xAF, 0x27, 0x1C

// 7z Property Tags (IDs)
pub const K_END: u8 = 0x00;
pub const K_HEADER: u8 = 0x01;
pub const K_ARCHIVE_PROPERTIES: u8 = 0x02;
pub const K_ADDITIONAL_STREAMS_INFO: u8 = 0x03;
pub const K_MAIN_STREAMS_INFO: u8 = 0x04;
pub const K_FILES_INFO: u8 = 0x05;
pub const K_PACK_INFO: u8 = 0x06;
pub const K_UNPACK_INFO: u8 = 0x07;
pub const K_SUB_STREAMS_INFO: u8 = 0x08;
pub const K_SIZE: u8 = 0x09;
pub const K_CRC: u8 = 0x0A;
pub const K_FOLDER: u8 = 0x0B;
pub const K_CODERS_UNPACK_SIZE: u8 = 0x0C;
pub const K_NUM_UNPACK_STREAM: u8 = 0x0D;
pub const K_EMPTY_STREAM: u8 = 0x0E;
pub const K_EMPTY_FILE: u8 = 0x0F;
pub const K_ANTI: u8 = 0x10;
pub const K_NAME: u8 = 0x11;
pub const K_CTIME: u8 = 0x12;
pub const K_ATIME: u8 = 0x13;
pub const K_MTIME: u8 = 0x14;
pub const K_WIN_ATTRIBUTES: u8 = 0x15;
pub const K_COMMENT: u8 = 0x16;
pub const K_ENCODED_HEADER: u8 = 0x17;

// 7z Coder Method IDs
pub const METHOD_COPY: u64 = 0x00;
pub const METHOD_LZMA: u64 = 0x030101;
pub const METHOD_LZMA2: u64 = 0x21;
pub const METHOD_DEFLATE: u64 = 0x040108;
pub const METHOD_AES: u64 = 0x06F10701;

/// Parsed 7z Signature Header (32 bytes at offset 0).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SevenZSignatureHeader {
    pub major_version: u8,
    pub minor_version: u8,
    pub start_header_crc: u32,
    pub next_header_offset: u64,
    pub next_header_size: u64,
    pub next_header_crc: u32,
}

impl SevenZSignatureHeader {
    /// Parses the 32-byte 7z signature header from mapped buffer.
    pub fn parse(mapped: &[u8]) -> Result<Self, TTZipStatus> {
        if mapped.len() < 32 {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        if &mapped[0..6] != SEVENZ_SIGNATURE {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        let major_version = mapped[6];
        let minor_version = mapped[7];
        let start_header_crc = u32::from_le_bytes(mapped[8..12].try_into().unwrap());
        let next_header_offset = u64::from_le_bytes(mapped[12..20].try_into().unwrap());
        let next_header_size = u64::from_le_bytes(mapped[20..28].try_into().unwrap());
        let next_header_crc = u32::from_le_bytes(mapped[28..32].try_into().unwrap());

        // Validate start header CRC (over bytes 12..32)
        let computed_start_crc = crc32_fast(0, &mapped[12..32]);
        if computed_start_crc != start_header_crc {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        Ok(Self {
            major_version,
            minor_version,
            start_header_crc,
            next_header_offset,
            next_header_size,
            next_header_crc,
        })
    }

    /// Serializes 32-byte signature header with accurate start_header_crc.
    pub fn serialize(&self) -> [u8; 32] {
        let mut header = [0u8; 32];
        header[0..6].copy_from_slice(&SEVENZ_SIGNATURE);
        header[6] = self.major_version;
        header[7] = self.minor_version;

        header[12..20].copy_from_slice(&self.next_header_offset.to_le_bytes());
        header[20..28].copy_from_slice(&self.next_header_size.to_le_bytes());
        header[28..32].copy_from_slice(&self.next_header_crc.to_le_bytes());

        let start_crc = crc32_fast(0, &header[12..32]);
        header[8..12].copy_from_slice(&start_crc.to_le_bytes());

        header
    }
}

/// Reads a 7z variable-length integer (Varint) from slice.
/// Returns `(value, bytes_consumed)` or `None` if slice is too short.
pub fn read_varint(buf: &[u8]) -> Option<(u64, usize)> {
    if buf.is_empty() {
        return None;
    }

    let first = buf[0];
    let k = (!first).leading_zeros() as usize; // Number of leading 1 bits in first (0..=8)

    if k == 0 {
        return Some((first as u64, 1));
    }
    if k > 8 || buf.len() < 1 + k {
        return None;
    }

    if k == 8 {
        let val = u64::from_le_bytes(buf[1..9].try_into().unwrap());
        return Some((val, 9));
    }

    let mask = 0xFF >> (k + 1);
    let high_part = ((first & mask) as u64) << (k * 8);

    let mut low_part = 0u64;
    for i in 0..k {
        low_part |= (buf[1 + i] as u64) << (i * 8);
    }

    Some((high_part | low_part, 1 + k))
}

/// Writes a 7z variable-length integer (Varint) to a vector.
pub fn write_varint(val: u64, out: &mut Vec<u8>) {
    if val < 0x80 {
        out.push(val as u8);
        return;
    }

    for extra_bytes in 1..=8 {
        let max_val = if extra_bytes == 8 {
            u64::MAX
        } else {
            let high_bits_count = 7 - extra_bytes;
            (1u64 << (8 * extra_bytes + high_bits_count)) - 1
        };

        if val <= max_val || extra_bytes == 8 {
            let first_mask = ((0xFFu16 << (8 - extra_bytes)) & 0xFF) as u8;
            let high_val = if extra_bytes == 8 {
                0
            } else {
                (val >> (8 * extra_bytes)) as u8
            };
            out.push(first_mask | high_val);
            for i in 0..extra_bytes {
                out.push((val >> (i * 8)) as u8);
            }
            return;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_7z_varint_roundtrip() {
        let test_values = [
            0u64, 1, 127, 128, 255, 256, 16383, 16384, 65535, 65536,
            0xFFFFFF, 0xFFFFFFFF, 0x123456789ABCDEF0,
        ];

        for &val in &test_values {
            let mut encoded = Vec::new();
            write_varint(val, &mut encoded);
            assert!(!encoded.is_empty());

            let (decoded, consumed) = read_varint(&encoded).expect("varint decode failed");
            assert_eq!(decoded, val);
            assert_eq!(consumed, encoded.len());
        }
    }

    #[test]
    fn test_7z_signature_header_serialize_and_parse() {
        let sig = SevenZSignatureHeader {
            major_version: 0,
            minor_version: 4,
            start_header_crc: 0, // Calculated automatically
            next_header_offset: 1024,
            next_header_size: 256,
            next_header_crc: 0x12345678,
        };

        let raw = sig.serialize();
        let parsed = SevenZSignatureHeader::parse(&raw).expect("parse sig header failed");
        assert_eq!(parsed.major_version, 0);
        assert_eq!(parsed.minor_version, 4);
        assert_eq!(parsed.next_header_offset, 1024);
        assert_eq!(parsed.next_header_size, 256);
        assert_eq!(parsed.next_header_crc, 0x12345678);
    }
}
