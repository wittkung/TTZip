// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper around `libdeflate_decompressor`.

use super::ffi::*;
use crate::types::TTZipStatus;
use std::ptr::NonNull;

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
