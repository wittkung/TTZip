// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Libdeflate raw C-ABI declarations and result codes.

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum LibdeflateResult {
    Success = 0,
    BadData = 1,
    ShortOutput = 2,
    InsufficientSpace = 3,
}

pub enum LibdeflateCompressorOpaque {}
pub enum LibdeflateDecompressorOpaque {}

extern "C" {
    pub fn libdeflate_alloc_compressor(compression_level: libc::c_int) -> *mut LibdeflateCompressorOpaque;
    pub fn libdeflate_deflate_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_deflate_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_zlib_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_zlib_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_gzip_compress(
        compressor: *mut LibdeflateCompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_gzip_compress_bound(
        compressor: *mut LibdeflateCompressorOpaque,
        in_nbytes: libc::size_t,
    ) -> libc::size_t;
    pub fn libdeflate_free_compressor(compressor: *mut LibdeflateCompressorOpaque);

    pub fn libdeflate_alloc_decompressor() -> *mut LibdeflateDecompressorOpaque;
    pub fn libdeflate_deflate_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    pub fn libdeflate_zlib_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    pub fn libdeflate_gzip_decompress(
        decompressor: *mut LibdeflateDecompressorOpaque,
        in_: *const libc::c_void,
        in_nbytes: libc::size_t,
        out: *mut libc::c_void,
        out_nbytes_avail: libc::size_t,
        actual_out_nbytes_ret: *mut libc::size_t,
    ) -> LibdeflateResult;
    pub fn libdeflate_free_decompressor(decompressor: *mut LibdeflateDecompressorOpaque);
}
