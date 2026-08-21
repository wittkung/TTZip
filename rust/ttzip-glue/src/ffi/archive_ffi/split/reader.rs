// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI entries for multi-volume split stream reader.

use crate::archive::split::VirtualMultiVolumeReader;
use crate::types::TTZipStatus;
use libc::c_char;
use std::ffi::{CStr, CString};
use std::io::{Read, Seek, SeekFrom};
use std::panic::catch_unwind;

/// Opaque handle wrapping `VirtualMultiVolumeReader`.
pub struct TTZipSplitReaderHandle {
    pub(crate) reader: VirtualMultiVolumeReader,
    pub(crate) cached_volumes: Vec<CString>,
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_open(
    seed_path: *const c_char,
) -> *mut TTZipSplitReaderHandle {
    let res = catch_unwind(|| {
        if seed_path.is_null() {
            return std::ptr::null_mut();
        }
        let p_str = match CStr::from_ptr(seed_path).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };
        let reader = match VirtualMultiVolumeReader::open_from_any_volume(p_str) {
            Ok(r) => r,
            Err(_) => return std::ptr::null_mut(),
        };
        let cached_volumes = reader
            .volume_paths()
            .into_iter()
            .filter_map(|p| CString::new(p.to_string_lossy().as_bytes()).ok())
            .collect();
        Box::into_raw(Box::new(TTZipSplitReaderHandle {
            reader,
            cached_volumes,
        }))
    });
    res.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_read(
    handle: *mut TTZipSplitReaderHandle,
    buf: *mut u8,
    len: usize,
    out_bytes_read: *mut usize,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() || (buf.is_null() && len > 0) || out_bytes_read.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let h = &mut *handle;
        let slice = if len > 0 {
            std::slice::from_raw_parts_mut(buf, len)
        } else {
            &mut []
        };
        match h.reader.read(slice) {
            Ok(n) => {
                *out_bytes_read = n;
                if n == 0 && len > 0 {
                    TTZipStatus::Eof
                } else {
                    TTZipStatus::Ok
                }
            }
            Err(_) => TTZipStatus::ErrOpenFailed,
        }
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_seek(
    handle: *mut TTZipSplitReaderHandle,
    offset: i64,
    whence: i32,
    out_new_offset: *mut u64,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let seek_from = match whence {
            0 => {
                if offset < 0 {
                    return TTZipStatus::ErrInvalidOffset;
                }
                SeekFrom::Start(offset as u64)
            }
            1 => SeekFrom::Current(offset),
            2 => SeekFrom::End(offset),
            _ => return TTZipStatus::ErrInvalidParam,
        };
        let h = &mut *handle;
        match h.reader.seek(seek_from) {
            Ok(pos) => {
                if !out_new_offset.is_null() {
                    *out_new_offset = pos;
                }
                TTZipStatus::Ok
            }
            Err(_) => TTZipStatus::ErrInvalidOffset,
        }
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_get_total_size(
    handle: *const TTZipSplitReaderHandle,
) -> u64 {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return 0;
        }
        (*handle).reader.total_size()
    });
    res.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_get_volume_count(
    handle: *const TTZipSplitReaderHandle,
) -> usize {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return 0;
        }
        (*handle).cached_volumes.len()
    });
    res.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_get_volume_path(
    handle: *const TTZipSplitReaderHandle,
    index: usize,
    out_buf: *mut c_char,
    buf_capacity: usize,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() || out_buf.is_null() || buf_capacity == 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        let h = &*handle;
        if index >= h.cached_volumes.len() {
            return TTZipStatus::ErrInvalidParam;
        }
        let c_str = &h.cached_volumes[index];
        let bytes = c_str.as_bytes_with_nul();
        if bytes.len() > buf_capacity {
            return TTZipStatus::ErrPathTooLong;
        }
        std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, out_buf, bytes.len());
        TTZipStatus::Ok
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_reader_free(handle: *mut TTZipSplitReaderHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    });
}
