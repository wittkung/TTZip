// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for VFS O(1) 16-way sharded LZ4 Cache Pool.

use crate::types::TTZipStatus;
use crate::vfs::VFSLz4CachePool;
use libc::{c_char, size_t};
use std::ffi::CStr;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;

pub struct TTZipVfsCacheHandle {
    inner: VFSLz4CachePool,
}

impl std::panic::RefUnwindSafe for TTZipVfsCacheHandle {}
impl std::panic::UnwindSafe for TTZipVfsCacheHandle {}

/// Creates a new VFS LZ4 cache pool handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_new(
    max_ram_bytes: usize,
    spill_dir: *const c_char,
) -> *mut TTZipVfsCacheHandle {
    let result = catch_unwind(AssertUnwindSafe(|| {
        let dir = if spill_dir.is_null() {
            None
        } else {
            CStr::from_ptr(spill_dir).to_str().ok().map(PathBuf::from)
        };
        let pool = VFSLz4CachePool::new(max_ram_bytes, dir);
        Box::into_raw(Box::new(TTZipVfsCacheHandle { inner: pool }))
    }));
    result.unwrap_or(std::ptr::null_mut())
}

/// Compresses raw chunk via LZ4 and inserts into VFS cache pool.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_put(
    handle: *mut TTZipVfsCacheHandle,
    session_id: *const c_char,
    chunk_index: u64,
    raw_data: *const u8,
    raw_len: usize,
    acceleration: i32,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() || session_id.is_null() || (raw_data.is_null() && raw_len > 0) {
            return TTZipStatus::ErrInvalidParam;
        }
        let pool = &(*handle).inner;
        let session_str = match CStr::from_ptr(session_id).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let slice = if raw_len == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(raw_data, raw_len)
        };
        match pool.put(session_str, chunk_index, slice, acceleration) {
            Ok(()) => TTZipStatus::Ok,
            Err(status) => status,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Retrieves and decompresses chunk into `out_buf`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_get(
    handle: *mut TTZipVfsCacheHandle,
    session_id: *const c_char,
    chunk_index: u64,
    out_buf: *mut u8,
    out_cap: usize,
    out_len: *mut size_t,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() || session_id.is_null() || out_buf.is_null() || out_len.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let pool = &(*handle).inner;
        let session_str = match CStr::from_ptr(session_id).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dst = std::slice::from_raw_parts_mut(out_buf, out_cap);
        match pool.get(session_str, chunk_index, dst) {
            Ok(decomp_len) => {
                *out_len = decomp_len;
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Clears all chunks belonging to a session from RAM and disk.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_clear_session(
    handle: *mut TTZipVfsCacheHandle,
    session_id: *const c_char,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() || session_id.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let pool = &(*handle).inner;
        let session_str = match CStr::from_ptr(session_id).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        pool.clear_session(session_str);
        TTZipStatus::Ok
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Retrieves pool statistics.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_get_stats(
    handle: *const TTZipVfsCacheHandle,
    out_ram_count: *mut usize,
    out_disk_count: *mut usize,
    out_ram_bytes: *mut usize,
) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            return;
        }
        let pool = &(*handle).inner;
        let (r_cnt, d_cnt, r_bytes) = pool.get_stats();
        if !out_ram_count.is_null() {
            *out_ram_count = r_cnt;
        }
        if !out_disk_count.is_null() {
            *out_disk_count = d_cnt;
        }
        if !out_ram_bytes.is_null() {
            *out_ram_bytes = r_bytes;
        }
    }));
}

/// Frees VFS cache pool handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_cache_free(handle: *mut TTZipVfsCacheHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    }));
}
