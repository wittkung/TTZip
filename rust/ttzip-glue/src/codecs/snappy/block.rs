// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pure Rust Google Snappy block compression, decompression, and length probe.
//!
//! Uses zero-copy buffer operations backed by the `snap::raw` engine.

use crate::types::TTZipStatus;
use snap::raw::{decompress_len, max_compress_len, Decoder, Encoder};

/// Computes upper bound on compressed bytes for a given raw input size.
#[inline]
pub fn snappy_compress_bound(src_size: usize) -> usize {
    max_compress_len(src_size)
}

/// Parses uncompressed length from a raw Snappy varint header.
pub fn snappy_uncompressed_length(src: &[u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    decompress_len(src).map_err(|_| TTZipStatus::ErrCorruptHeader)
}

/// Validates integrity of a Snappy compressed buffer without decompressing.
pub fn snappy_validate(src: &[u8]) -> bool {
    if src.is_empty() {
        return true;
    }
    match decompress_len(src) {
        Ok(expected_len) => {
            let mut dec = Decoder::new();
            let mut out = vec![0u8; expected_len];
            dec.decompress(src, &mut out).is_ok()
        }
        Err(_) => false,
    }
}

/// Compresses a memory block using pure Rust Google Snappy raw format.
pub fn snappy_compress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut enc = Encoder::new();
    enc.compress(src, dst).map_err(|_| TTZipStatus::ErrCompressionFailed)
}

/// Decompresses a raw Snappy compressed block into a pre-allocated destination buffer.
pub fn snappy_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut dec = Decoder::new();
    dec.decompress(src, dst).map_err(|_| TTZipStatus::ErrCorruptHeader)
}

/// Compresses a memory slice into a newly allocated `Vec<u8>`.
pub fn snappy_compress_to_vec(src: &[u8]) -> Result<Vec<u8>, TTZipStatus> {
    if src.is_empty() {
        return Ok(Vec::new());
    }
    let mut enc = Encoder::new();
    enc.compress_vec(src).map_err(|_| TTZipStatus::ErrCompressionFailed)
}

/// Decompresses a raw Snappy slice into a newly allocated `Vec<u8>`.
pub fn snappy_decompress_to_vec(src: &[u8]) -> Result<Vec<u8>, TTZipStatus> {
    if src.is_empty() {
        return Ok(Vec::new());
    }
    let mut dec = Decoder::new();
    dec.decompress_vec(src).map_err(|_| TTZipStatus::ErrCorruptHeader)
}
