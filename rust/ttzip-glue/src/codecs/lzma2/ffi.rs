// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! FFI extern definitions for `fast-lzma2` (FL2) library.

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum Fl2CParameter {
    CompressionLevel = 0,
    HighCompression = 1,
    DictionaryLog = 2,
    DictionarySize = 3,
    OverlapFraction = 4,
    ResetInterval = 5,
    BufferResize = 6,
    HybridChainLog = 7,
    HybridCycles = 8,
    SearchDepth = 9,
    FastLength = 10,
    DivideAndConquer = 11,
    Strategy = 12,
    LiteralCtxBits = 13,
    LiteralPosBits = 14,
    PosBits = 15,
    OmitProperties = 16,
}

#[repr(C)]
pub struct Fl2InBuffer {
    pub src: *const libc::c_void,
    pub size: libc::size_t,
    pub pos: libc::size_t,
}

#[repr(C)]
pub struct Fl2OutBuffer {
    pub dst: *mut libc::c_void,
    pub size: libc::size_t,
    pub pos: libc::size_t,
}

pub enum Fl2CCtxOpaque {}
pub enum Fl2DCtxOpaque {}

#[allow(dead_code)]
extern "C" {
    pub fn FL2_createCCtx() -> *mut Fl2CCtxOpaque;
    pub fn FL2_createCCtxMt(nb_threads: libc::c_uint) -> *mut Fl2CCtxOpaque;
    pub fn FL2_freeCCtx(cctx: *mut Fl2CCtxOpaque);

    pub fn FL2_createDCtx() -> *mut Fl2DCtxOpaque;
    pub fn FL2_createDCtxMt(nb_threads: libc::c_uint) -> *mut Fl2DCtxOpaque;
    pub fn FL2_freeDCtx(dctx: *mut Fl2DCtxOpaque) -> libc::size_t;

    pub fn FL2_CCtx_setParameter(
        cctx: *mut Fl2CCtxOpaque,
        param: Fl2CParameter,
        value: libc::size_t,
    ) -> libc::size_t;
    pub fn FL2_compressBound(src_size: libc::size_t) -> libc::size_t;
    pub fn FL2_isError(code: libc::size_t) -> libc::c_uint;
    pub fn FL2_getErrorName(code: libc::size_t) -> *const libc::c_char;

    pub fn FL2_compressCCtx(
        cctx: *mut Fl2CCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
        compression_level: libc::c_int,
    ) -> libc::size_t;

    pub fn FL2_decompressDCtx(
        dctx: *mut Fl2DCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
    ) -> libc::size_t;

    pub fn FL2_findDecompressedSize(src: *const libc::c_void, src_size: libc::size_t) -> libc::c_ulonglong;
    pub fn FL2_getCCtxDictProp(cctx: *mut Fl2CCtxOpaque) -> libc::c_uchar;
    pub fn FL2_initDCtx(dctx: *mut Fl2DCtxOpaque, prop: libc::c_uchar) -> libc::size_t;

    pub fn FL2_createDStream() -> *mut Fl2DCtxOpaque;
    pub fn FL2_createDStreamMt(nb_threads: libc::c_uint) -> *mut Fl2DCtxOpaque;
    pub fn FL2_freeDStream(fds: *mut Fl2DCtxOpaque) -> libc::size_t;
    pub fn FL2_initDStream(fds: *mut Fl2DCtxOpaque) -> libc::size_t;
    pub fn FL2_initDStream_withProp(fds: *mut Fl2DCtxOpaque, prop: libc::c_uchar) -> libc::size_t;
    pub fn FL2_decompressStream(
        fds: *mut Fl2DCtxOpaque,
        output: *mut Fl2OutBuffer,
        input: *mut Fl2InBuffer,
    ) -> libc::size_t;
}
