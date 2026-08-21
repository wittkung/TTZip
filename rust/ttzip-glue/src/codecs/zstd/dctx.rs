// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zstandard decompression context RAII wrapper and buffer decompression.

use super::types::*;
use crate::types::TTZipStatus;
use std::cell::RefCell;
use std::ptr::NonNull;

/// Safe RAII wrapper for `ZSTD_DCtx`.
pub struct ZstdDCtx {
    handle: NonNull<ZstdDCtxOpaque>,
}

unsafe impl Send for ZstdDCtx {}

impl ZstdDCtx {
    /// Allocates a new Zstandard decompression context.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { ZSTD_createDCtx() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Decompresses a buffer in a single pass into destination.
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
            ZSTD_decompressDCtx(
                self.handle.as_ptr(),
                out_ptr,
                dst.len(),
                in_ptr,
                src.len(),
            )
        };

        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrCorruptHeader)
        } else {
            Ok(res)
        }
    }

    /// Streams decompression data into output buffer.
    pub fn decompress_stream(
        &mut self,
        input: &mut ZstdInBuffer,
        output: &mut ZstdOutBuffer,
    ) -> Result<usize, TTZipStatus> {
        let res = unsafe {
            ZSTD_decompressStream(self.handle.as_ptr(), output, input)
        };
        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrCorruptHeader)
        } else {
            Ok(res)
        }
    }
}

impl Drop for ZstdDCtx {
    fn drop(&mut self) {
        unsafe {
            ZSTD_freeDCtx(self.handle.as_ptr());
        }
    }
}

thread_local! {
    static TLS_ZSTD_DCTX: RefCell<Option<ZstdDCtx>> = const { RefCell::new(None) };
}

/// Executes closure with thread-local cached `ZstdDCtx`.
pub fn with_thread_local_zstd_dctx<F, R>(f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut ZstdDCtx) -> Result<R, TTZipStatus>,
{
    TLS_ZSTD_DCTX.with(|cell| {
        let mut cached = cell.borrow_mut();
        if cached.is_none() {
            *cached = Some(ZstdDCtx::new()?);
        }
        let ctx = cached.as_mut().unwrap();
        f(ctx)
    })
}

/// Obtains uncompressed content size from Zstandard frame header, if available.
#[inline]
pub fn zstd_get_decompressed_size(src: &[u8]) -> Option<u64> {
    if src.is_empty() {
        return None;
    }
    let res = unsafe { ZSTD_getFrameContentSize(src.as_ptr() as *const libc::c_void, src.len()) };
    if res == u64::MAX || res == u64::MAX - 1 {
        None
    } else {
        Some(res)
    }
}

/// Zero-copy Zstandard decompression using thread-local pooled context.
pub fn zstd_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    with_thread_local_zstd_dctx(|dctx| dctx.decompress(src, dst))
}
