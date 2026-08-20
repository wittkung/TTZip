// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper and streaming context for Facebook `Zstandard` (zstd).
//!
//! Supports multi-threaded parallel compression (`nb_workers`), Long Distance Matching (LDM),
//! custom window/overlap logs, and zero-copy in-memory buffer operations.

use crate::types::TTZipStatus;
use std::cell::RefCell;
use std::ptr::NonNull;

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum ZstdCParameter {
    CompressionLevel = 100,
    WindowLog = 101,
    HashLog = 102,
    ChainLog = 103,
    SearchLog = 104,
    MinMatch = 105,
    TargetLength = 106,
    Strategy = 107,
    EnableLongDistanceMatching = 160,
    LdmHashLog = 161,
    LdmMinMatch = 162,
    LdmBucketSizeLog = 163,
    LdmHashRateLog = 164,
    ContentSizeFlag = 200,
    ChecksumFlag = 201,
    DictIdFlag = 202,
    NbWorkers = 400,
    JobSize = 401,
    OverlapLog = 402,
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum ZstdEndDirective {
    Continue = 0,
    Flush = 1,
    End = 2,
}

#[repr(C)]
pub struct ZstdInBuffer {
    pub src: *const libc::c_void,
    pub size: libc::size_t,
    pub pos: libc::size_t,
}

#[repr(C)]
pub struct ZstdOutBuffer {
    pub dst: *mut libc::c_void,
    pub capacity: libc::size_t,
    pub pos: libc::size_t,
}

enum ZstdCCtxOpaque {}
enum ZstdDCtxOpaque {}

#[allow(dead_code)]
extern "C" {
    fn ZSTD_createCCtx() -> *mut ZstdCCtxOpaque;
    fn ZSTD_freeCCtx(cctx: *mut ZstdCCtxOpaque) -> libc::size_t;
    fn ZSTD_createDCtx() -> *mut ZstdDCtxOpaque;
    fn ZSTD_freeDCtx(dctx: *mut ZstdDCtxOpaque) -> libc::size_t;

    fn ZSTD_CCtx_setParameter(
        cctx: *mut ZstdCCtxOpaque,
        param: ZstdCParameter,
        value: libc::c_int,
    ) -> libc::size_t;
    fn ZSTD_CCtx_reset(cctx: *mut ZstdCCtxOpaque, reset: libc::c_int) -> libc::size_t;

    fn ZSTD_compressBound(src_size: libc::size_t) -> libc::size_t;
    fn ZSTD_isError(code: libc::size_t) -> libc::c_uint;
    fn ZSTD_getErrorName(code: libc::size_t) -> *const libc::c_char;

    fn ZSTD_compressCCtx(
        cctx: *mut ZstdCCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
        compression_level: libc::c_int,
    ) -> libc::size_t;

    fn ZSTD_decompressDCtx(
        dctx: *mut ZstdDCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
    ) -> libc::size_t;

    fn ZSTD_compressStream2(
        cctx: *mut ZstdCCtxOpaque,
        output: *mut ZstdOutBuffer,
        input: *mut ZstdInBuffer,
        end_op: ZstdEndDirective,
    ) -> libc::size_t;

    fn ZSTD_decompressStream(
        dctx: *mut ZstdDCtxOpaque,
        output: *mut ZstdOutBuffer,
        input: *mut ZstdInBuffer,
    ) -> libc::size_t;

    fn ZSTD_getFrameContentSize(
        src: *const libc::c_void,
        src_size: libc::size_t,
    ) -> libc::c_ulonglong;
}

/// Advanced configuration parameters for Zstandard compression.
#[derive(Debug, Clone, Copy)]
pub struct ZstdConfig {
    pub level: i32,
    pub nb_workers: u32,
    pub job_size_mb: u32,
    pub overlap_log: u32,
    pub window_log: u32,
    pub enable_ldm: bool,
    pub enable_checksum: bool,
}

impl Default for ZstdConfig {
    fn default() -> Self {
        Self {
            level: 3,
            nb_workers: 0,
            job_size_mb: 0,
            overlap_log: 0,
            window_log: 0,
            enable_ldm: false,
            enable_checksum: true,
        }
    }
}

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

// MARK: - Thread-Local Storage (TLS) Pool

thread_local! {
    static TLS_ZSTD_CCTX: RefCell<Option<ZstdCCtx>> = const { RefCell::new(None) };
    static TLS_ZSTD_DCTX: RefCell<Option<ZstdDCtx>> = const { RefCell::new(None) };
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

// MARK: - High-Level Zero-Copy Helpers

/// Computes upper bound on compressed bytes for a given input size in Zstandard.
#[inline]
pub fn zstd_compress_bound(src_size: usize) -> usize {
    unsafe { ZSTD_compressBound(src_size) }
}

/// Obtains uncompressed content size from Zstandard frame header, if available.
#[inline]
pub fn zstd_get_decompressed_size(src: &[u8]) -> Option<u64> {
    if src.is_empty() {
        return None;
    }
    let res = unsafe { ZSTD_getFrameContentSize(src.as_ptr() as *const libc::c_void, src.len()) };
    // ZSTD_CONTENTSIZE_UNKNOWN = (unsigned long long)-1, ZSTD_CONTENTSIZE_ERROR = (unsigned long long)-2
    if res == u64::MAX || res == u64::MAX - 1 {
        None
    } else {
        Some(res)
    }
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

/// Zero-copy Zstandard decompression using thread-local pooled context.
pub fn zstd_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    with_thread_local_zstd_dctx(|dctx| dctx.decompress(src, dst))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zstd_basic_roundtrip() {
        let input = b"TTZip High-performance ZSTD compression engine test string in Safe Rust.";
        let mut compressed = vec![0u8; zstd_compress_bound(input.len())];
        let comp_len = zstd_compress(input, &mut compressed, 3).expect("zstd compression failed");
        assert!(comp_len > 0);

        let detected_size = zstd_get_decompressed_size(&compressed[..comp_len]);
        assert_eq!(detected_size, Some(input.len() as u64));

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = zstd_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("zstd decompression failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed[..decomp_len], input);
    }

    #[test]
    fn test_zstd_advanced_multithread_ldm() {
        let pattern = b"Long repetitive block data designed for Zstandard Long Distance Matching (LDM) verification. ";
        let mut input = Vec::new();
        for _ in 0..1000 {
            input.extend_from_slice(pattern);
        }

        let config = ZstdConfig {
            level: 6,
            nb_workers: 2,
            job_size_mb: 1,
            overlap_log: 2,
            window_log: 20,
            enable_ldm: true,
            enable_checksum: true,
        };

        let mut compressed = vec![0u8; zstd_compress_bound(input.len())];
        let comp_len = zstd_compress_advanced(&input, &mut compressed, &config)
            .expect("zstd advanced compression failed");
        assert!(comp_len > 0);
        assert!(comp_len < input.len() / 5); // high compression ratio on repetitive data

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = zstd_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("zstd decompression failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed, &input);
    }

    #[test]
    fn test_zstd_corrupt_data() {
        let corrupt = [0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00, 0xff, 0xff];
        let mut out = [0u8; 128];
        let res = zstd_decompress(&corrupt, &mut out);
        assert!(res.is_err());
    }
}
