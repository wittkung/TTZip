// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zstandard compression context RAII wrapper and buffer compression.

use super::types::*;
use crate::types::TTZipStatus;
use std::cell::RefCell;
use std::ptr::NonNull;

/// Safe RAII wrapper for `ZSTD_CCtx`.
pub struct ZstdCCtx {
    handle: NonNull<ZstdCCtxOpaque>,
}

unsafe impl Send for ZstdCCtx {}

impl ZstdCCtx {
    /// Allocates a new Zstandard compression context.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { ZSTD_createCCtx() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Sets a generic compression parameter on the context.
    pub fn set_parameter(&mut self, param: ZstdCParameter, value: i32) -> Result<(), TTZipStatus> {
        let res = unsafe { ZSTD_CCtx_setParameter(self.handle.as_ptr(), param, value as libc::c_int) };
        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrInvalidParam)
        } else {
            Ok(())
        }
    }

    /// Applies full configuration parameters (workers, LDM, windowLog, etc.).
    pub fn apply_config(&mut self, config: &ZstdConfig) -> Result<(), TTZipStatus> {
        self.set_parameter(ZstdCParameter::CompressionLevel, config.level)?;

        if config.nb_workers > 0 {
            self.set_parameter(ZstdCParameter::NbWorkers, config.nb_workers as i32)?;
        }
        if config.job_size_mb > 0 {
            let job_size_bytes = (config.job_size_mb as i32).saturating_mul(1024 * 1024);
            self.set_parameter(ZstdCParameter::JobSize, job_size_bytes)?;
        }
        if config.overlap_log > 0 {
            self.set_parameter(ZstdCParameter::OverlapLog, config.overlap_log as i32)?;
        }
        if config.window_log > 0 {
            self.set_parameter(ZstdCParameter::WindowLog, config.window_log as i32)?;
        }
        if config.enable_ldm {
            self.set_parameter(ZstdCParameter::EnableLongDistanceMatching, 1)?;
        }
        if config.enable_checksum {
            self.set_parameter(ZstdCParameter::ChecksumFlag, 1)?;
        }
        Ok(())
    }

    /// Resets the compression context for reuse.
    pub fn reset(&mut self) -> Result<(), TTZipStatus> {
        let res = unsafe { ZSTD_CCtx_reset(self.handle.as_ptr(), 1) }; // ZSTD_reset_session_only
        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrArchiveInitFailed)
        } else {
            Ok(())
        }
    }

    /// Compresses a buffer in a single pass into destination.
    pub fn compress(&mut self, src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
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
            ZSTD_compressCCtx(
                self.handle.as_ptr(),
                out_ptr,
                dst.len(),
                in_ptr,
                src.len(),
                level as libc::c_int,
            )
        };

        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(res)
        }
    }

    /// Streams compression data into output buffer.
    pub fn compress_stream(
        &mut self,
        input: &mut ZstdInBuffer,
        output: &mut ZstdOutBuffer,
        end_op: ZstdEndDirective,
    ) -> Result<usize, TTZipStatus> {
        let res = unsafe {
            ZSTD_compressStream2(self.handle.as_ptr(), output, input, end_op)
        };
        if unsafe { ZSTD_isError(res) } != 0 {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(res)
        }
    }
}

impl Drop for ZstdCCtx {
    fn drop(&mut self) {
        unsafe {
            ZSTD_freeCCtx(self.handle.as_ptr());
        }
    }
}

thread_local! {
    static TLS_ZSTD_CCTX: RefCell<Option<ZstdCCtx>> = const { RefCell::new(None) };
}

/// Executes closure with thread-local cached `ZstdCCtx`.
pub fn with_thread_local_zstd_cctx<F, R>(f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut ZstdCCtx) -> Result<R, TTZipStatus>,
{
    TLS_ZSTD_CCTX.with(|cell| {
        let mut cached = cell.borrow_mut();
        if cached.is_none() {
            *cached = Some(ZstdCCtx::new()?);
        }
        let ctx = cached.as_mut().unwrap();
        f(ctx)
    })
}

/// Computes upper bound on compressed bytes for a given input size in Zstandard.
#[inline]
pub fn zstd_compress_bound(src_size: usize) -> usize {
    unsafe { ZSTD_compressBound(src_size) }
}

/// Zero-copy Zstandard compression using thread-local pooled context.
pub fn zstd_compress(src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
    with_thread_local_zstd_cctx(|cctx| cctx.compress(src, dst, level))
}

/// Zero-copy Zstandard compression with advanced configuration (workers, LDM, etc.).
pub fn zstd_compress_advanced(
    src: &[u8],
    dst: &mut [u8],
    config: &ZstdConfig,
) -> Result<usize, TTZipStatus> {
    let mut cctx = ZstdCCtx::new()?;
    cctx.apply_config(config)?;
    cctx.compress(src, dst, config.level)
}
