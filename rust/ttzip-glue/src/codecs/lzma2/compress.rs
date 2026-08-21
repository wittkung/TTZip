// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fast-LZMA2 compression context and single-pass operations.

use super::ffi::*;
use crate::types::TTZipStatus;
use std::ptr::NonNull;

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

/// Computes upper bound on compressed bytes for a given input size in fast-lzma2.
#[inline]
pub fn fl2_compress_bound(src_size: usize) -> usize {
    unsafe { FL2_compressBound(src_size) }
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
