// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Ultra-fast block compression codecs: `LZ4`, Google `Snappy`, and Apple `LZFSE`.
//!
//! Includes thread-private 2MB scratch buffer pooling for zero-allocation LZFSE operations.

use crate::types::TTZipStatus;
use std::cell::RefCell;

// MARK: - LZ4 C-Bindings & Safe Interface

#[allow(dead_code)]
extern "C" {
    fn LZ4_compress_default(
        src: *const libc::c_char,
        dst: *mut libc::c_char,
        src_size: libc::c_int,
        dst_capacity: libc::c_int,
    ) -> libc::c_int;

    fn LZ4_compress_fast(
        src: *const libc::c_char,
        dst: *mut libc::c_char,
        src_size: libc::c_int,
        dst_capacity: libc::c_int,
        acceleration: libc::c_int,
    ) -> libc::c_int;

    fn LZ4_decompress_safe(
        src: *const libc::c_char,
        dst: *mut libc::c_char,
        compressed_size: libc::c_int,
        dst_capacity: libc::c_int,
    ) -> libc::c_int;

    fn LZ4_compressBound(input_size: libc::c_int) -> libc::c_int;
}

/// Computes worst-case output buffer size for LZ4 block compression.
#[inline]
pub fn lz4_compress_bound(src_size: usize) -> usize {
    if src_size > i32::MAX as usize {
        0
    } else {
        unsafe { LZ4_compressBound(src_size as libc::c_int) as usize }
    }
}

/// Compresses a memory block using LZ4 default acceleration.
pub fn lz4_compress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    lz4_compress_fast(src, dst, 1)
}

/// Compresses a memory block using LZ4 with custom acceleration factor.
pub fn lz4_compress_fast(src: &[u8], dst: &mut [u8], acceleration: i32) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    if src.len() > i32::MAX as usize || dst.len() > i32::MAX as usize {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let written = unsafe {
        LZ4_compress_fast(
            src.as_ptr() as *const libc::c_char,
            dst.as_mut_ptr() as *mut libc::c_char,
            src.len() as libc::c_int,
            dst.len() as libc::c_int,
            acceleration as libc::c_int,
        )
    };

    if written <= 0 {
        Err(TTZipStatus::ErrCompressionFailed)
    } else {
        Ok(written as usize)
    }
}

/// Decompresses an LZ4 compressed block into a pre-allocated destination buffer.
pub fn lz4_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    if src.len() > i32::MAX as usize || dst.len() > i32::MAX as usize {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let written = unsafe {
        LZ4_decompress_safe(
            src.as_ptr() as *const libc::c_char,
            dst.as_mut_ptr() as *mut libc::c_char,
            src.len() as libc::c_int,
            dst.len() as libc::c_int,
        )
    };

    if written < 0 {
        Err(TTZipStatus::ErrCorruptHeader)
    } else {
        Ok(written as usize)
    }
}

// MARK: - Snappy Pure Rust Codec Forwarding

pub use crate::codecs::snappy::{
    snappy_compress, snappy_compress_bound as snappy_max_compressed_length, snappy_decompress,
    snappy_uncompressed_length, snappy_validate,
};

// MARK: - Apple LZFSE C-Bindings & Thread-Local Scratch Pool

extern "C" {
    fn lzfse_encode_scratch_size() -> libc::size_t;
    fn lzfse_encode_buffer(
        dst_buffer: *mut u8,
        dst_size: libc::size_t,
        src_buffer: *const u8,
        src_size: libc::size_t,
        scratch_buffer: *mut libc::c_void,
    ) -> libc::size_t;

    fn lzfse_decode_scratch_size() -> libc::size_t;
    fn lzfse_decode_buffer(
        dst_buffer: *mut u8,
        dst_size: libc::size_t,
        src_buffer: *const u8,
        src_size: libc::size_t,
        scratch_buffer: *mut libc::c_void,
    ) -> libc::size_t;
}

const LZFSE_SCRATCH_MIN_CAPACITY: usize = 2 * 1024 * 1024; // 2MB Scratch buffer

thread_local! {
    static LZFSE_SCRATCH_BUFFER: RefCell<Vec<u8>> = RefCell::new(Vec::new());
}

fn with_lzfse_scratch<F, R>(min_size: usize, f: F) -> R
where
    F: FnOnce(*mut libc::c_void) -> R,
{
    LZFSE_SCRATCH_BUFFER.with(|cell| {
        let mut buf = cell.borrow_mut();
        let target_size = min_size.max(LZFSE_SCRATCH_MIN_CAPACITY);
        if buf.len() < target_size {
            buf.resize(target_size, 0);
        }
        f(buf.as_mut_ptr() as *mut libc::c_void)
    })
}

/// Compresses a buffer with Apple LZFSE using thread-private 2MB scratch buffer.
pub fn lzfse_compress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let scratch_size = unsafe { lzfse_encode_scratch_size() };
    let written = with_lzfse_scratch(scratch_size, |scratch| {
        unsafe {
            lzfse_encode_buffer(
                dst.as_mut_ptr(),
                dst.len(),
                src.as_ptr(),
                src.len(),
                scratch,
            )
        }
    });

    if written == 0 && !src.is_empty() {
        Err(TTZipStatus::ErrCompressionFailed)
    } else {
        Ok(written)
    }
}

/// Decompresses an Apple LZFSE buffer using thread-private 2MB scratch buffer.
pub fn lzfse_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let scratch_size = unsafe { lzfse_decode_scratch_size() };
    let written = with_lzfse_scratch(scratch_size, |scratch| {
        unsafe {
            lzfse_decode_buffer(
                dst.as_mut_ptr(),
                dst.len(),
                src.as_ptr(),
                src.len(),
                scratch,
            )
        }
    });

    if written == 0 && !src.is_empty() {
        Err(TTZipStatus::ErrCorruptHeader)
    } else {
        Ok(written)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lz4_roundtrip() {
        let input = b"LZ4 fast compression block testing in TTZip native glue layer.";
        let mut comp = vec![0u8; lz4_compress_bound(input.len())];
        let c_len = lz4_compress(input, &mut comp).expect("lz4 compress");
        assert!(c_len > 0);

        let mut decomp = vec![0u8; input.len()];
        let d_len = lz4_decompress(&comp[..c_len], &mut decomp).expect("lz4 decompress");
        assert_eq!(d_len, input.len());
        assert_eq!(&decomp[..d_len], input);
    }

    #[test]
    fn test_snappy_roundtrip_and_validation() {
        let input = b"Snappy Google fast block codec validation roundtrip TTZip 2026.";
        let mut comp = vec![0u8; snappy_max_compressed_length(input.len())];
        let c_len = snappy_compress(input, &mut comp).expect("snappy compress");
        assert!(c_len > 0);

        assert!(snappy_validate(&comp[..c_len]));
        let uncomp_len = snappy_uncompressed_length(&comp[..c_len]).expect("snappy uncompressed length");
        assert_eq!(uncomp_len, input.len());

        let mut decomp = vec![0u8; input.len()];
        let d_len = snappy_decompress(&comp[..c_len], &mut decomp).expect("snappy decompress");
        assert_eq!(d_len, input.len());
        assert_eq!(&decomp[..d_len], input);
    }

    #[test]
    fn test_lzfse_scratch_roundtrip() {
        let input = b"Apple LZFSE proprietary high-ratio block compression with 2MB scratch buffer.";
        let mut comp = vec![0u8; input.len() + 1024];
        let c_len = lzfse_compress(input, &mut comp).expect("lzfse compress");
        assert!(c_len > 0);

        let mut decomp = vec![0u8; input.len()];
        let d_len = lzfse_decompress(&comp[..c_len], &mut decomp).expect("lzfse decompress");
        assert_eq!(d_len, input.len());
        assert_eq!(&decomp[..d_len], input);
    }
}
