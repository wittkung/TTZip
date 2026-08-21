// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pure Rust Google Brotli block compression, decompression, and buffer bounds.

use crate::types::TTZipStatus;
use brotli::enc::BrotliEncoderParams;
use std::io::{Cursor, Read};

/// Computes worst-case output buffer size for Brotli block compression.
#[inline]
pub fn brotli_compress_bound(src_size: usize) -> usize {
    if src_size == 0 {
        1024
    } else {
        src_size + (src_size >> 2) + 10240
    }
}

/// Compresses a memory block using Brotli into a pre-allocated destination buffer.
pub fn brotli_compress(
    src: &[u8],
    dst: &mut [u8],
    quality: u32,
    lgwin: u32,
) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut params = BrotliEncoderParams::default();
    params.quality = quality.clamp(0, 11) as i32;
    params.lgwin = if lgwin == 0 { 22 } else { lgwin.clamp(10, 24) as i32 };

    let mut cursor_in = Cursor::new(src);
    let mut cursor_out = Cursor::new(dst);

    brotli::BrotliCompress(&mut cursor_in, &mut cursor_out, &params)
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    Ok(cursor_out.position() as usize)
}

/// Decompresses a Brotli compressed block into a pre-allocated destination buffer.
pub fn brotli_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut cursor_in = Cursor::new(src);
    let mut cursor_out = Cursor::new(dst);

    brotli::BrotliDecompress(&mut cursor_in, &mut cursor_out)
        .map_err(|_| TTZipStatus::ErrCorruptHeader)?;

    Ok(cursor_out.position() as usize)
}

/// Compresses a memory slice into a newly allocated `Vec<u8>`.
pub fn brotli_compress_to_vec(
    src: &[u8],
    quality: u32,
    lgwin: u32,
) -> Result<Vec<u8>, TTZipStatus> {
    if src.is_empty() {
        return Ok(Vec::new());
    }
    let bound = brotli_compress_bound(src.len());
    let mut out = vec![0u8; bound];
    let written = brotli_compress(src, &mut out, quality, lgwin)?;
    out.truncate(written);
    Ok(out)
}

/// Decompresses a Brotli slice into a newly allocated `Vec<u8>`.
pub fn brotli_decompress_to_vec(src: &[u8], max_allowed: usize) -> Result<Vec<u8>, TTZipStatus> {
    if src.is_empty() {
        return Ok(Vec::new());
    }
    let mut decompressor = brotli::Decompressor::new(src, 65536);
    let mut out = Vec::new();
    let mut chunk = [0u8; 8192];
    loop {
        match decompressor.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => {
                if out.len() + n > max_allowed {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                out.extend_from_slice(&chunk[..n]);
            }
            Err(_) => return Err(TTZipStatus::ErrCorruptHeader),
        }
    }
    Ok(out)
}
