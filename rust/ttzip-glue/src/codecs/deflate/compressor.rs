// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper around `libdeflate_compressor`.

use super::ffi::*;
use crate::types::TTZipStatus;
use std::ptr::NonNull;

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
