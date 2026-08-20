// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for stream adapters.

use crate::archive::stream_adapter::{StreamReaderState, StreamWriterState};
use libc::c_char;
use std::ffi::CStr;
use std::fs::File;
use std::panic::catch_unwind;

/// Opaque wrapper for a streaming file reader.
pub struct TTZipStreamReaderHandle {
    state: StreamReaderState<File>,
}

/// Opaque wrapper for a streaming file writer.
pub struct TTZipStreamWriterHandle {
    state: StreamWriterState<File>,
}

/// Creates a new streaming file reader handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_reader_new_file(
    path: *const c_char,
    buffer_size: usize,
) -> *mut TTZipStreamReaderHandle {
    let result = catch_unwind(|| {
        if path.is_null() {
            return std::ptr::null_mut();
        }
        let c_str = CStr::from_ptr(path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };

        let file = match File::open(path_str) {
            Ok(f) => f,
            Err(_) => return std::ptr::null_mut(),
        };

        let state = StreamReaderState::new(file, buffer_size);
        Box::into_raw(Box::new(TTZipStreamReaderHandle { state }))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Reads the next chunk from the stream reader handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_reader_read(
    handle: *mut TTZipStreamReaderHandle,
    out_ptr: *mut *const u8,
    out_len: *mut usize,
) -> i32 {
    let result = catch_unwind(|| {
        if handle.is_null() || out_ptr.is_null() || out_len.is_null() {
            return -1;
        }

        let handle_ref = &mut *handle;
        match handle_ref.state.read_chunk() {
            Ok((ptr, len)) => {
                *out_ptr = ptr;
                *out_len = len;
                0
            }
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Destroys a stream reader handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_reader_free(handle: *mut TTZipStreamReaderHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    });
}

/// Creates a new streaming file writer handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_writer_new_file(
    path: *const c_char,
    buffer_size: usize,
) -> *mut TTZipStreamWriterHandle {
    let result = catch_unwind(|| {
        if path.is_null() {
            return std::ptr::null_mut();
        }
        let c_str = CStr::from_ptr(path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };

        let file = match File::create(path_str) {
            Ok(f) => f,
            Err(_) => return std::ptr::null_mut(),
        };

        let state = StreamWriterState::new(file, buffer_size);
        Box::into_raw(Box::new(TTZipStreamWriterHandle { state }))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Writes a data chunk to the stream writer handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_writer_write(
    handle: *mut TTZipStreamWriterHandle,
    data: *const u8,
    len: usize,
) -> i32 {
    let result = catch_unwind(|| {
        if handle.is_null() || (data.is_null() && len > 0) {
            return -1;
        }

        let handle_ref = &mut *handle;
        let slice = if len > 0 {
            std::slice::from_raw_parts(data, len)
        } else {
            &[]
        };

        match handle_ref.state.write_chunk(slice) {
            Ok(_) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Flushes a stream writer handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_writer_flush(handle: *mut TTZipStreamWriterHandle) -> i32 {
    let result = catch_unwind(|| {
        if handle.is_null() {
            return -1;
        }
        let handle_ref = &mut *handle;
        match handle_ref.state.flush() {
            Ok(()) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Destroys a stream writer handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_stream_writer_free(handle: *mut TTZipStreamWriterHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    });
}
