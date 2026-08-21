// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI entries for multi-volume split stream writer.

use crate::archive::split::{SplitVolumeWriter, VolumeNamingScheme};
use crate::types::TTZipStatus;
use libc::c_char;
use std::ffi::{CStr, CString};
use std::io::Write;
use std::panic::catch_unwind;

/// Opaque handle wrapping `SplitVolumeWriter`.
pub struct TTZipSplitWriterHandle {
    pub(crate) writer: SplitVolumeWriter,
    pub(crate) cached_volumes: Vec<CString>,
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_new(
    base_path: *const c_char,
    volume_size_bytes: u64,
    naming_scheme: i32,
    clean_on_failure: bool,
) -> *mut TTZipSplitWriterHandle {
    let res = catch_unwind(|| {
        if base_path.is_null() || volume_size_bytes == 0 {
            return std::ptr::null_mut();
        }
        let p_str = match CStr::from_ptr(base_path).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };
        let scheme = VolumeNamingScheme::from(naming_scheme);
        let writer = match SplitVolumeWriter::new(p_str, volume_size_bytes, scheme) {
            Ok(w) => w.with_clean_on_failure(clean_on_failure),
            Err(_) => return std::ptr::null_mut(),
        };
        Box::into_raw(Box::new(TTZipSplitWriterHandle {
            writer,
            cached_volumes: Vec::new(),
        }))
    });
    res.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_write(
    handle: *mut TTZipSplitWriterHandle,
    data: *const u8,
    len: usize,
) -> i32 {
    let res = catch_unwind(|| {
        if handle.is_null() || (data.is_null() && len > 0) {
            return -1;
        }
        let h = &mut *handle;
        let slice = if len > 0 {
            std::slice::from_raw_parts(data, len)
        } else {
            &[]
        };
        match h.writer.write_all(slice) {
            Ok(_) => 0,
            Err(_) => -1,
        }
    });
    res.unwrap_or(-1)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_flush(
    handle: *mut TTZipSplitWriterHandle,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let h = &mut *handle;
        match h.writer.flush() {
            Ok(_) => TTZipStatus::Ok,
            Err(_) => TTZipStatus::ErrCompressionFailed,
        }
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_close(
    handle: *mut TTZipSplitWriterHandle,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let h = &mut *handle;
        match h.writer.close() {
            Ok(volumes) => {
                h.cached_volumes = volumes
                    .into_iter()
                    .filter_map(|p| CString::new(p.to_string_lossy().as_bytes()).ok())
                    .collect();
                TTZipStatus::Ok
            }
            Err(_) => TTZipStatus::ErrCompressionFailed,
        }
    });
    res.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_cancel(handle: *mut TTZipSplitWriterHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            let h = &mut *handle;
            h.writer.cancel_and_cleanup();
        }
    });
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_get_total_bytes(
    handle: *const TTZipSplitWriterHandle,
) -> u64 {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return 0;
        }
        (*handle).writer.total_bytes()
    });
    res.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_get_volume_count(
    handle: *mut TTZipSplitWriterHandle,
) -> usize {
    let res = catch_unwind(|| {
        if handle.is_null() {
            return 0;
        }
        let h = &mut *handle;
        if h.cached_volumes.is_empty() {
            h.cached_volumes = h
                .writer
                .generated_volumes()
                .iter()
                .filter_map(|p| CString::new(p.to_string_lossy().as_bytes()).ok())
                .collect();
        }
        h.cached_volumes.len()
    });
    res.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_split_writer_get_volume_path(
    handle: *mut TTZipSplitWriterHandle,
    index: usize,
    out_buf: *mut c_char,
    buf_capacity: usize,
) -> TTZipStatus {
    let res = catch_unwind(|| {
        if handle.is_null() || out_buf.is_null() || buf_capacity == 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        let h = &mut *handle;
        if h.cached_volumes.is_empty() {
            h.cached_volumes = h
                .writer
                .generated_volumes()
                .iter()
                .filter_map(|p| CString::new(p.to_string_lossy().as_bytes()).ok())
                .collect();
        }
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
pub unsafe extern "C" fn ttzip_rust_split_writer_free(handle: *mut TTZipSplitWriterHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    });
}
