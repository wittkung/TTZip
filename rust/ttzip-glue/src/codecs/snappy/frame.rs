// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Official Snappy Framing Format (.sz) streaming encoder and decoder.
//!
//! Conforms to the Snappy framing specification with Castagnoli CRC-32C verification.

use crate::types::TTZipStatus;
use snap::read::FrameDecoder;
use snap::write::FrameEncoder;
use std::io::{Cursor, Read, Write};

/// Standard Snappy stream identifier: `[0xFF, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y']`.
pub const SNAPPY_STREAM_IDENTIFIER: [u8; 10] = [0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59];

/// Maximum raw chunk size per Snappy framing specification (64KB).
pub const SNAPPY_MAX_CHUNK_SIZE: usize = 65536;

/// Checks if data begins with standard Snappy stream identifier.
#[inline]
pub fn is_framed_snappy(data: &[u8]) -> bool {
    data.len() >= SNAPPY_STREAM_IDENTIFIER.len()
        && data[..SNAPPY_STREAM_IDENTIFIER.len()] == SNAPPY_STREAM_IDENTIFIER
}

/// Masks CRC32C per Snappy specification: `((crc >> 15) | (crc << 17)) + 0xa282ead8`.
#[inline]
pub fn mask_crc32c(crc: u32) -> u32 {
    crc.rotate_right(15).wrapping_add(0xa282ead8)
}

/// Unmasks CRC32C per Snappy specification.
#[inline]
pub fn unmask_crc32c(masked: u32) -> u32 {
    let rot = masked.wrapping_sub(0xa282ead8);
    rot.rotate_left(15)
}

/// Encodes raw buffer into Snappy framing format (.sz) in memory.
pub fn snappy_frame_encode(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    let mut cursor = Cursor::new(dst);
    {
        let mut encoder = FrameEncoder::new(&mut cursor);
        encoder
            .write_all(src)
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        encoder.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    }
    let written = cursor.position() as usize;
    Ok(written)
}

/// Encodes raw buffer into Snappy framing format (.sz) returning `Vec<u8>`.
pub fn snappy_frame_encode_to_vec(src: &[u8]) -> Result<Vec<u8>, TTZipStatus> {
    let mut out = Vec::with_capacity(src.len() + 64);
    {
        let mut encoder = FrameEncoder::new(&mut out);
        encoder
            .write_all(src)
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        encoder.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    }
    Ok(out)
}

/// Decodes Snappy framing format (.sz) buffer into pre-allocated destination buffer.
pub fn snappy_frame_decode(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    let mut decoder = FrameDecoder::new(src);
    let mut total_read = 0;
    while total_read < dst.len() {
        match decoder.read(&mut dst[total_read..]) {
            Ok(0) => break,
            Ok(n) => total_read += n,
            Err(_) => return Err(TTZipStatus::ErrExtractionFailed),
        }
    }
    Ok(total_read)
}

/// Decodes Snappy framing format (.sz) buffer into `Vec<u8>` with optional max size limit.
pub fn snappy_frame_decode_to_vec(src: &[u8], max_allowed: usize) -> Result<Vec<u8>, TTZipStatus> {
    let mut decoder = FrameDecoder::new(src);
    let mut out = Vec::new();
    let mut buf = [0u8; 8192];
    loop {
        match decoder.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => {
                if out.len() + n > max_allowed {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                out.extend_from_slice(&buf[..n]);
            }
            Err(_) => return Err(TTZipStatus::ErrCorruptHeader),
        }
    }
    Ok(out)
}

/// Computes upper bound on encoded framing stream length.
#[inline]
pub fn snappy_frame_max_encoded_length(src_len: usize) -> usize {
    if src_len == 0 {
        return SNAPPY_STREAM_IDENTIFIER.len();
    }
    let num_chunks = src_len.div_ceil(SNAPPY_MAX_CHUNK_SIZE);
    SNAPPY_STREAM_IDENTIFIER.len() + num_chunks * (8 + crate::codecs::snappy::block::snappy_compress_bound(SNAPPY_MAX_CHUNK_SIZE))
}
