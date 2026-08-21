// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fast-LZMA2 decompression context and stream decoding.

use super::ffi::*;
use crate::types::TTZipStatus;
use std::ptr::NonNull;

/// Safe RAII wrapper for fast-lzma2 decompression context `FL2_DCtx`.
pub struct Fl2DCtx {
    handle: NonNull<Fl2DCtxOpaque>,
}

unsafe impl Send for Fl2DCtx {}

impl Fl2DCtx {
    /// Creates a single-threaded decompression context.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { FL2_createDCtx() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Creates a multi-threaded decompression context with thread budget.
    pub fn new_mt(threads: u32) -> Result<Self, TTZipStatus> {
        let ptr = unsafe { FL2_createDCtxMt(threads as libc::c_uint) };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Initializes decompression context with custom dictionary property byte.
    pub fn init_with_prop(&mut self, prop: u8) -> Result<(), TTZipStatus> {
        let res = unsafe { FL2_initDCtx(self.handle.as_ptr(), prop) };
        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrCorruptHeader)
        } else {
            Ok(())
        }
    }

    /// Decompresses buffer in a single pass into destination.
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

        let res = unsafe {
            FL2_decompressDCtx(
                self.handle.as_ptr(),
                out_ptr,
                dst.len(),
                in_ptr,
                src.len(),
            )
        };

        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrCorruptHeader)
        } else {
            Ok(res)
        }
    }
}

impl Drop for Fl2DCtx {
    fn drop(&mut self) {
        unsafe {
            FL2_freeDCtx(self.handle.as_ptr());
        }
    }
}

/// Safe RAII wrapper for streaming fast-lzma2 decompression `FL2_DStream`.
pub struct Fl2DStream {
    handle: NonNull<Fl2DCtxOpaque>,
}

unsafe impl Send for Fl2DStream {}

impl Fl2DStream {
    /// Creates a new streaming LZMA2 decoder.
    pub fn new(threads: u32) -> Result<Self, TTZipStatus> {
        let ptr = unsafe {
            if threads > 1 {
                FL2_createDStreamMt(threads as libc::c_uint)
            } else {
                FL2_createDStream()
            }
        };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Initializes decompression stream with dictionary property byte if known.
    pub fn init(&mut self, prop: Option<u8>) -> Result<(), TTZipStatus> {
        let res = match prop {
            Some(p) => unsafe { FL2_initDStream_withProp(self.handle.as_ptr(), p as libc::c_uchar) },
            None => unsafe { FL2_initDStream(self.handle.as_ptr()) },
        };
        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrCorruptHeader)
        } else {
            Ok(())
        }
    }

    /// Decompresses stream incrementally from input to output buffer.
    pub fn decompress_stream(
        &mut self,
        input: &mut Fl2InBuffer,
        output: &mut Fl2OutBuffer,
    ) -> Result<usize, TTZipStatus> {
        let res = unsafe { FL2_decompressStream(self.handle.as_ptr(), output, input) };
        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrExtractionFailed)
        } else {
            Ok(res)
        }
    }
}

impl Drop for Fl2DStream {
    fn drop(&mut self) {
        unsafe {
            FL2_freeDStream(self.handle.as_ptr());
        }
    }
}

/// Finds uncompressed size from fast-lzma2 stream if known.
#[inline]
pub fn fl2_find_decompressed_size(src: &[u8]) -> Option<u64> {
    if src.is_empty() {
        return None;
    }
    let res = unsafe { FL2_findDecompressedSize(src.as_ptr() as *const libc::c_void, src.len()) };
    if res == u64::MAX {
        None
    } else {
        Some(res)
    }
}

/// High-level single-pass fast-lzma2 decompression with thread budget.
pub fn fl2_decompress(src: &[u8], dst: &mut [u8], threads: u32) -> Result<usize, TTZipStatus> {
    let mut ctx = if threads > 1 {
        Fl2DCtx::new_mt(threads)?
    } else {
        Fl2DCtx::new()?
    };
    ctx.decompress(src, dst)
}
