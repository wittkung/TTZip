// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Thread-Local Storage (TLS) handle caching and recycling pool for `libdeflate`.

use super::compressor::DeflateCompressor;
use super::decompressor::DeflateDecompressor;
use crate::types::TTZipStatus;
use std::cell::RefCell;

thread_local! {
    static TLS_COMPRESSORS: RefCell<[Option<DeflateCompressor>; 13]> = const { RefCell::new([
        None, None, None, None, None, None, None, None, None, None, None, None, None
    ]) };
    static TLS_DECOMPRESSOR: RefCell<Option<DeflateDecompressor>> = const { RefCell::new(None) };
}

/// Executes a closure with a thread-local cached `DeflateCompressor` for the specified level.
pub fn with_thread_local_compressor<F, R>(level: i32, f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut DeflateCompressor) -> Result<R, TTZipStatus>,
{
    let idx = if level < 0 { 6 } else { level.clamp(0, 12) as usize };
    TLS_COMPRESSORS.with(|cell| {
        let mut pool = cell.borrow_mut();
        if pool[idx].is_none() {
            pool[idx] = Some(DeflateCompressor::new(idx as i32)?);
        }
        let compressor = pool[idx].as_mut().unwrap();
        f(compressor)
    })
}

/// Executes a closure with a thread-local cached `DeflateDecompressor`.
pub fn with_thread_local_decompressor<F, R>(f: F) -> Result<R, TTZipStatus>
where
    F: FnOnce(&mut DeflateDecompressor) -> Result<R, TTZipStatus>,
{
    TLS_DECOMPRESSOR.with(|cell| {
        let mut cached = cell.borrow_mut();
        if cached.is_none() {
            *cached = Some(DeflateDecompressor::new()?);
        }
        let decompressor = cached.as_mut().unwrap();
        f(decompressor)
    })
}
