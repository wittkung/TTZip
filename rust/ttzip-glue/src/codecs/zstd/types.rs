// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Types, parameters, buffer definitions and FFI bindings for Facebook `Zstandard` (zstd).

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

pub enum ZstdCCtxOpaque {}
pub enum ZstdDCtxOpaque {}

#[allow(dead_code)]
extern "C" {
    pub fn ZSTD_createCCtx() -> *mut ZstdCCtxOpaque;
    pub fn ZSTD_freeCCtx(cctx: *mut ZstdCCtxOpaque) -> libc::size_t;
    pub fn ZSTD_createDCtx() -> *mut ZstdDCtxOpaque;
    pub fn ZSTD_freeDCtx(dctx: *mut ZstdDCtxOpaque) -> libc::size_t;

    pub fn ZSTD_CCtx_setParameter(
        cctx: *mut ZstdCCtxOpaque,
        param: ZstdCParameter,
        value: libc::c_int,
    ) -> libc::size_t;
    pub fn ZSTD_CCtx_reset(cctx: *mut ZstdCCtxOpaque, reset: libc::c_int) -> libc::size_t;

    pub fn ZSTD_compressBound(src_size: libc::size_t) -> libc::size_t;
    pub fn ZSTD_isError(code: libc::size_t) -> libc::c_uint;
    pub fn ZSTD_getErrorName(code: libc::size_t) -> *const libc::c_char;

    pub fn ZSTD_compressCCtx(
        cctx: *mut ZstdCCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
        compression_level: libc::c_int,
    ) -> libc::size_t;

    pub fn ZSTD_decompressDCtx(
        dctx: *mut ZstdDCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
    ) -> libc::size_t;

    pub fn ZSTD_compressStream2(
        cctx: *mut ZstdCCtxOpaque,
        output: *mut ZstdOutBuffer,
        input: *mut ZstdInBuffer,
        end_op: ZstdEndDirective,
    ) -> libc::size_t;

    pub fn ZSTD_decompressStream(
        dctx: *mut ZstdDCtxOpaque,
        output: *mut ZstdOutBuffer,
        input: *mut ZstdInBuffer,
    ) -> libc::size_t;

    pub fn ZSTD_getFrameContentSize(
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
