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

use crate::types::TTZipStatus;
use std::cell::RefCell;
use std::ptr::NonNull;

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum LibdeflateResult {
    Success = 0,
    BadData = 1,
    ShortOutput = 2,
    InsufficientSpace = 3,
}

enum LibdeflateCompressorOpaque {}
enum LibdeflateDecompressorOpaque {}

extern "C" {
    fn libdeflate_alloc_compressor(compression_level: libc::c_int) -> *mut LibdeflateCompressorOpaque;
    fn libdeflate_deflate_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_deflate_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_zlib_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_zlib_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_gzip_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_gzip_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    fn libdeflate_free_compressor(compressor: *mut LibdeflateCompressorOpaque);

    fn libdeflate_alloc_decompressor() -> *mut LibdeflateDecompressorOpaque;
    fn libdeflate_deflate_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    fn libdeflate_zlib_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    fn libdeflate_gzip_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    fn libdeflate_free_decompressor(decompressor: *mut LibdeflateDecompressorOpaque);
}

/// Safe RAII wrapper around `libdeflate_compressor`.
pub struct DeflateCompressor {
    handle: NonNull<LibdeflateCompressorOpaque>,
    level: i32,
}

unsafe impl Send for DeflateCompressor {}

impl DeflateCompressor {
    /// Creates a new Deflate compressor for the specified compression level (0..=12).
    /// Level 0 = Store, 1 = Fastest, 6 = Default, 12 = Maximum.
    pub fn new(level: i32) -> Result<Self, TTZipStatus> {
        let valid_level = if level < 0 { 6 } else { level.clamp(0, 12) };
        let ptr = unsafe { libdeflate_alloc_compressor(valid_level) };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self {
            handle,
            level: valid_level,
        })
    }

    #[inline]
    pub fn level(&self) -> i32 {
        self.level
    }

    /// Computes worst-case upper bound on compressed bytes for raw DEFLATE.
    #[inline]
    pub fn compress_bound(&self, in_len: usize) -> usize {
        unsafe { libdeflate_deflate_compress_bound(self.handle.as_ptr(), in_len) }
    }

    /// Computes worst-case upper bound on compressed bytes for zlib wrapper.
    #[inline]
    pub fn zlib_compress_bound(&self, in_len: usize) -> usize {
        unsafe { libdeflate_zlib_compress_bound(self.handle.as_ptr(), in_len) }
    }

    /// Computes worst-case upper bound on compressed bytes for gzip wrapper.
    #[inline]
    pub fn gzip_compress_bound(&self, in_len: usize) -> usize {
        unsafe { libdeflate_gzip_compress_bound(self.handle.as_ptr(), in_len) }
    }

    /// Compresses source slice using raw RFC 1951 DEFLATE format into destination buffer.
    pub fn compress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let written = unsafe {
            libdeflate_deflate_compress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
            )
        };

        if written == 0 && !src.is_empty() {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(written)
        }
    }

    /// Compresses source slice using zlib (RFC 1950) format.
    pub fn zlib_compress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let written = unsafe {
            libdeflate_zlib_compress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
            )
        };

        if written == 0 && !src.is_empty() {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(written)
        }
    }

    /// Compresses source slice using gzip (RFC 1952) format.
    pub fn gzip_compress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let written = unsafe {
            libdeflate_gzip_compress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
            )
        };

        if written == 0 && !src.is_empty() {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(written)
        }
    }
}

impl Drop for DeflateCompressor {
    fn drop(&mut self) {
        unsafe {
            libdeflate_free_compressor(self.handle.as_ptr());
        }
    }
}

/// Safe RAII wrapper around `libdeflate_decompressor`.
pub struct DeflateDecompressor {
    handle: NonNull<LibdeflateDecompressorOpaque>,
}

unsafe impl Send for DeflateDecompressor {}

impl DeflateDecompressor {
    /// Creates a new Deflate decompressor context.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { libdeflate_alloc_decompressor() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Decompresses raw RFC 1951 DEFLATE stream into pre-allocated destination buffer.
    pub fn decompress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let mut actual_out_size: libc::size_t = 0;
        let res = unsafe {
            libdeflate_deflate_decompress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
                &mut actual_out_size,
            )
        };

        match res {
            LibdeflateResult::Success => Ok(actual_out_size),
            LibdeflateResult::BadData => Err(TTZipStatus::ErrCorruptHeader),
            LibdeflateResult::ShortOutput | LibdeflateResult::InsufficientSpace => {
                Err(TTZipStatus::ErrExtractionFailed)
            }
        }
    }

    /// Decompresses zlib (RFC 1950) stream into destination buffer.
    pub fn zlib_decompress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let mut actual_out_size: libc::size_t = 0;
        let res = unsafe {
            libdeflate_zlib_decompress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
                &mut actual_out_size,
            )
        };

        match res {
            LibdeflateResult::Success => Ok(actual_out_size),
            LibdeflateResult::BadData => Err(TTZipStatus::ErrCorruptHeader),
            LibdeflateResult::ShortOutput | LibdeflateResult::InsufficientSpace => {
                Err(TTZipStatus::ErrExtractionFailed)
            }
        }
    }

    /// Decompresses gzip (RFC 1952) stream into destination buffer.
    pub fn gzip_decompress(&mut self, src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
        let in_ptr = if src.is_empty() {
            std::ptr::null()
        } else {
            src.as_ptr() as *const libc::c_void
        };
        let out_ptr = if dst.is_empty() {
            std::ptr::null_mut()
        } else {
            dst.as_mut_ptr() as *mut libc::c_void
        };

        let mut actual_out_size: libc::size_t = 0;
        let res = unsafe {
            libdeflate_gzip_decompress(
                self.handle.as_ptr(),
                in_ptr,
                src.len(),
                out_ptr,
                dst.len(),
                &mut actual_out_size,
            )
        };

        match res {
            LibdeflateResult::Success => Ok(actual_out_size),
            LibdeflateResult::BadData => Err(TTZipStatus::ErrCorruptHeader),
            LibdeflateResult::ShortOutput | LibdeflateResult::InsufficientSpace => {
                Err(TTZipStatus::ErrExtractionFailed)
            }
        }
    }
}

impl Drop for DeflateDecompressor {
    fn drop(&mut self) {
        unsafe {
            libdeflate_free_decompressor(self.handle.as_ptr());
        }
    }
}

// MARK: - Thread-Local Storage (TLS) Pool

thread_local! {
    static TLS_COMPRESSORS: RefCell<[Option<DeflateCompressor>; 13]> = const { RefCell::new([
        None, None, None, None, None, None, None, None, None, None, None, None, None
    ]) };
    static TLS_DECOMPRESSOR: RefCell<Option<DeflateDecompressor>> = const { RefCell::new(None) };
}

/// Executes a closure with a thread-local cached `DeflateCompressor` for the specified level.
pub fn with_thread_local_compressor<F, R>(level: i32, f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut DeflateCompressor) -> Result<R, TTZipStatus>,
{
    let idx = if level < 0 { 6 } else { level.clamp(0, 12) as usize };
    TLS_COMPRESSORS.with(|cell| {
        let mut pool = cell.borrow_mut();
        if pool[idx].is_none() {
            pool[idx] = Some(DeflateCompressor::new(idx as i32)?);
        }
        let compressor = pool[idx].as_mut().unwrap();
        f(compressor)
    })
}

/// Executes a closure with a thread-local cached `DeflateDecompressor`.
pub fn with_thread_local_decompressor<F, R>(f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut DeflateDecompressor) -> Result<R, TTZipStatus>,
{
    TLS_DECOMPRESSOR.with(|cell| {
        let mut cached = cell.borrow_mut();
        if cached.is_none() {
            *cached = Some(DeflateDecompressor::new()?);
        }
        let decompressor = cached.as_mut().unwrap();
        f(decompressor)
    })
}

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
    with_thread_local_compressor(level, |c| Ok(c.compress_bound(in_len))).unwrap_or(in_len + (in_len / 7) + 64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deflate_roundtrip_basic() {
        let input = b"Hello world! TTZip native Rust DEFLATE engine testing 1234567890.";
        let mut compressed = vec![0u8; deflate_compress_bound(input.len(), 6)];
        let comp_len = deflate_compress(input, &mut compressed, 6).expect("deflate compress failed");
        assert!(comp_len > 0);

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = deflate_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("deflate decompress failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed[..decomp_len], input);
    }

    #[test]
    fn test_zlib_roundtrip_all_levels() {
        let input = b"The quick brown fox jumps over the lazy dog. Repeat repeatedly for compression ratio.";
        let mut buffer = Vec::new();
        for _ in 0..50 {
            buffer.extend_from_slice(input);
        }

        for level in [1, 3, 6, 9, 12] {
            let mut compressed = vec![0u8; buffer.len() + 1024];
            let comp_len = zlib_compress(&buffer, &mut compressed, level).expect("zlib compress failed");
            assert!(comp_len > 0);
            assert!(comp_len < buffer.len());

            let mut decompressed = vec![0u8; buffer.len()];
            let decomp_len = zlib_decompress(&compressed[..comp_len], &mut decompressed)
                .expect("zlib decompress failed");
            assert_eq!(decomp_len, buffer.len());
            assert_eq!(&decompressed, &buffer);
        }
    }

    #[test]
    fn test_gzip_roundtrip() {
        let input = b"GZIP format wrapping test for TTZip high-performance native pipeline.";
        let mut compressed = vec![0u8; input.len() + 1024];
        let comp_len = gzip_compress(input, &mut compressed, 6).expect("gzip compress failed");
        assert!(comp_len > 0);

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = gzip_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("gzip decompress failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed, input);
    }

    #[test]
    fn test_corrupt_data_handling() {
        let garbage = [0xde, 0xad, 0xbe, 0xef, 0x01, 0x02, 0x03, 0x04];
        let mut out = [0u8; 64];
        let res = deflate_decompress(&garbage, &mut out);
        assert!(res.is_err());
    }
}
