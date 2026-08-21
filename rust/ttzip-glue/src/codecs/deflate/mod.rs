// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper and thread-local handle pool for `libdeflate`.
//!
//! Provides ultra-fast, zero-copy DEFLATE (RFC 1951), zlib (RFC 1950), and gzip (RFC 1952)
//! compression and decompression with safe lifecycle management and hardware acceleration.

pub mod compressor;
pub mod decompressor;
mod ffi;
mod pool;

#[cfg(test)]
mod tests;

pub use compressor::DeflateCompressor;
pub use decompressor::DeflateDecompressor;
pub use ffi::LibdeflateResult;
pub use pool::*;

use crate::types::TTZipStatus;

// MARK: - High-Level Zero-Copy Helpers

/// Zero-copy raw DEFLATE compression using thread-local pooled compressor.
pub fn deflate_compress(src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
    with_thread_local_compressor(level, |c| c.compress(src, dst))
}

/// Zero-copy raw DEFLATE decompression using thread-local pooled decompressor.
pub fn deflate_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    with_thread_local_decompressor(|d| d.decompress(src, dst))
}

/// Zero-copy zlib compression using thread-local pooled compressor.
pub fn zlib_compress(src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
    with_thread_local_compressor(level, |c| c.zlib_compress(src, dst))
}

/// Zero-copy zlib decompression using thread-local pooled decompressor.
pub fn zlib_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    with_thread_local_decompressor(|d| d.zlib_decompress(src, dst))
}

/// Zero-copy gzip compression using thread-local pooled compressor.
pub fn gzip_compress(src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
    with_thread_local_compressor(level, |c| c.gzip_compress(src, dst))
}

/// Zero-copy gzip decompression using thread-local pooled decompressor.
pub fn gzip_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    with_thread_local_decompressor(|d| d.gzip_decompress(src, dst))
}

/// Upper bound calculation for raw DEFLATE compression.
pub fn deflate_compress_bound(in_len: usize, level: i32) -> usize {
    with_thread_local_compressor(level, |c| Ok(c.compress_bound(in_len)))
        .unwrap_or(in_len + (in_len / 7) + 64)
}
