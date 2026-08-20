// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper for `fast-lzma2` (FL2) multi-threaded LZMA2 engine.
//!
//! Provides parallel chunked LZMA2 compression, dictionary property extraction (for 7z/XZ),
//! streaming decompressor, and automatic resource reclamation.

use crate::types::TTZipStatus;
use std::ptr::NonNull;

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

enum Fl2CCtxOpaque {}
enum Fl2DCtxOpaque {}

#[allow(dead_code)]
extern "C" {
    fn FL2_createCCtx() -> *mut Fl2CCtxOpaque;
    fn FL2_createCCtxMt(nb_threads: libc::c_uint) -> *mut Fl2CCtxOpaque;
    fn FL2_freeCCtx(cctx: *mut Fl2CCtxOpaque);

    fn FL2_createDCtx() -> *mut Fl2DCtxOpaque;
    fn FL2_createDCtxMt(nb_threads: libc::c_uint) -> *mut Fl2DCtxOpaque;
    fn FL2_freeDCtx(dctx: *mut Fl2DCtxOpaque) -> libc::size_t;

    fn FL2_CCtx_setParameter(
        cctx: *mut Fl2CCtxOpaque,
        param: Fl2CParameter,
        value: libc::size_t,
    ) -> libc::size_t;
    fn FL2_compressBound(src_size: libc::size_t) -> libc::size_t;
    fn FL2_isError(code: libc::size_t) -> libc::c_uint;
    fn FL2_getErrorName(code: libc::size_t) -> *const libc::c_char;

    fn FL2_compressCCtx(
        cctx: *mut Fl2CCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
        compression_level: libc::c_int,
    ) -> libc::size_t;

    fn FL2_decompressDCtx(
        dctx: *mut Fl2DCtxOpaque,
        dst: *mut libc::c_void,
        dst_capacity: libc::size_t,
        src: *const libc::c_void,
        src_size: libc::size_t,
    ) -> libc::size_t;

    fn FL2_findDecompressedSize(src: *const libc::c_void, src_size: libc::size_t) -> libc::c_ulonglong;
    fn FL2_getCCtxDictProp(cctx: *mut Fl2CCtxOpaque) -> libc::c_uchar;
    fn FL2_initDCtx(dctx: *mut Fl2DCtxOpaque, prop: libc::c_uchar) -> libc::size_t;

    fn FL2_createCStreamMt(nb_threads: libc::c_uint, dual_buffer: libc::c_int) -> *mut Fl2CCtxOpaque;
    fn FL2_freeCStream(fcs: *mut Fl2CCtxOpaque);
    fn FL2_initCStream(fcs: *mut Fl2CCtxOpaque, compression_level: libc::c_int) -> libc::size_t;
    fn FL2_compressStream(
        fcs: *mut Fl2CCtxOpaque,
        output: *mut Fl2OutBuffer,
        input: *mut Fl2InBuffer,
    ) -> libc::size_t;
    fn FL2_endStream(fcs: *mut Fl2CCtxOpaque, output: *mut Fl2OutBuffer) -> libc::size_t;

    fn FL2_createDStreamMt(nb_threads: libc::c_uint) -> *mut Fl2DCtxOpaque;
    fn FL2_freeDStream(fds: *mut Fl2DCtxOpaque) -> libc::size_t;
    fn FL2_initDStream(fds: *mut Fl2DCtxOpaque) -> libc::size_t;
    fn FL2_initDStream_withProp(fds: *mut Fl2DCtxOpaque, prop: libc::c_uchar) -> libc::size_t;
    fn FL2_decompressStream(
        fds: *mut Fl2DCtxOpaque,
        output: *mut Fl2OutBuffer,
        input: *mut Fl2InBuffer,
    ) -> libc::size_t;
}


/// Safe RAII wrapper for fast-lzma2 compression context `FL2_CCtx`.
pub struct Fl2CCtx {
    handle: NonNull<Fl2CCtxOpaque>,
}

unsafe impl Send for Fl2CCtx {}

impl Fl2CCtx {
    /// Creates a single-threaded compression context.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { FL2_createCCtx() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Creates a multi-threaded compression context with thread budget.
    /// Specifying 0 threads tells FL2 to auto-detect hardware core count.
    pub fn new_mt(threads: u32) -> Result<Self, TTZipStatus> {
        let ptr = unsafe { FL2_createCCtxMt(threads as libc::c_uint) };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Sets a specific compression parameter.
    pub fn set_parameter(&mut self, param: Fl2CParameter, value: usize) -> Result<(), TTZipStatus> {
        let res = unsafe { FL2_CCtx_setParameter(self.handle.as_ptr(), param, value as libc::size_t) };
        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrInvalidParam)
        } else {
            Ok(())
        }
    }

    /// Retrieves the LZMA2 dictionary property byte for 7-zip header encoding.
    pub fn dict_property(&mut self) -> u8 {
        unsafe { FL2_getCCtxDictProp(self.handle.as_ptr()) }
    }

    /// Compresses buffer in a single pass into destination.
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
            FL2_compressCCtx(
                self.handle.as_ptr(),
                out_ptr,
                dst.len(),
                in_ptr,
                src.len(),
                level as libc::c_int,
            )
        };

        if unsafe { FL2_isError(res) } != 0 {
            Err(TTZipStatus::ErrCompressionFailed)
        } else {
            Ok(res)
        }
    }
}

impl Drop for Fl2CCtx {
    fn drop(&mut self) {
        unsafe {
            FL2_freeCCtx(self.handle.as_ptr());
        }
    }
}

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

/// Computes upper bound on compressed bytes for a given input size in fast-lzma2.
#[inline]
pub fn fl2_compress_bound(src_size: usize) -> usize {
    unsafe { FL2_compressBound(src_size) }
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

/// High-level single-pass fast-lzma2 compression with thread budget.
pub fn fl2_compress(
    src: &[u8],
    dst: &mut [u8],
    level: i32,
    threads: u32,
) -> Result<usize, TTZipStatus> {
    let mut ctx = if threads > 1 {
        Fl2CCtx::new_mt(threads)?
    } else {
        Fl2CCtx::new()?
    };
    ctx.compress(src, dst, level)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fl2_basic_roundtrip() {
        let input = b"TTZip Safe Rust Fast-LZMA2 Multi-threaded Engine testing payload.";
        let mut compressed = vec![0u8; fl2_compress_bound(input.len()) + 1024];
        let comp_len = fl2_compress(input, &mut compressed, 3, 2).expect("fl2 compression failed");
        assert!(comp_len > 0);

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = fl2_decompress(&compressed[..comp_len], &mut decompressed, 2)
            .expect("fl2 decompression failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed[..decomp_len], input);
    }
}
