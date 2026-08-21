// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Libarchive Stream Writing adapter and C-ABI trampolines.

use super::read::{archive_close_callback_trampoline, archive_open_callback_trampoline};
use super::{
    ARCHIVE_FATAL, ARCHIVE_OK, DEFAULT_STREAM_BUFFER_SIZE, MAX_STREAM_BUFFER_SIZE,
    StreamStateSnapshot,
};
use crate::types::TTZipStatus;
use std::io::Write;
use std::panic::catch_unwind;
use std::pin::Pin;

/// Internal state for custom stream writing callbacks.
pub struct StreamWriterState<W> {
    pub writer: W,
    pub buffer: Vec<u8>,
    pub bytes_written: u64,
    pub has_error: bool,
    pub last_error_msg: Option<String>,
}

impl<W: Write> StreamWriterState<W> {
    /// Creates a new `StreamWriterState` with the specified micro-buffer capacity.
    pub fn new(writer: W, buffer_size: usize) -> Self {
        let cap = buffer_size.clamp(DEFAULT_STREAM_BUFFER_SIZE, MAX_STREAM_BUFFER_SIZE);
        Self {
            writer,
            buffer: Vec::with_capacity(cap),
            bytes_written: 0,
            has_error: false,
            last_error_msg: None,
        }
    }

    /// Writes data chunk to the underlying writer.
    pub fn write_chunk(&mut self, data: &[u8]) -> std::io::Result<usize> {
        match self.writer.write_all(data) {
            Ok(()) => {
                let n = data.len();
                self.bytes_written = self.bytes_written.saturating_add(n as u64);
                Ok(n)
            }
            Err(e) => {
                self.has_error = true;
                self.last_error_msg = Some(e.to_string());
                Err(e)
            }
        }
    }

    /// Flushes buffered data to the underlying writer.
    pub fn flush(&mut self) -> std::io::Result<()> {
        self.writer.flush()
    }

    /// Takes a point-in-time snapshot of the writer state.
    pub fn snapshot(&self) -> StreamStateSnapshot {
        StreamStateSnapshot {
            bytes_consumed: 0,
            bytes_written: self.bytes_written,
            is_eof: false,
            has_error: self.has_error,
            last_error_msg: self.last_error_msg.clone(),
        }
    }
}

// ---------------------------------------------------------------------------
// Libarchive Write Trampoline Callbacks
// ---------------------------------------------------------------------------

/// C-ABI write callback trampoline for `libarchive`.
pub unsafe extern "C" fn archive_write_callback_trampoline<W: Write>(
    _archive: *mut libc::c_void,
    client_data: *mut libc::c_void,
    buffer: *const libc::c_void,
    length: libc::size_t,
) -> libc::ssize_t {
    let result = catch_unwind(|| {
        if client_data.is_null() || (buffer.is_null() && length > 0) {
            return ARCHIVE_FATAL as libc::ssize_t;
        }
        let state = &mut *(client_data as *mut StreamWriterState<W>);
        let slice = if length > 0 {
            std::slice::from_raw_parts(buffer as *const u8, length)
        } else {
            &[]
        };

        match state.write_chunk(slice) {
            Ok(n) => n as libc::ssize_t,
            Err(_) => ARCHIVE_FATAL as libc::ssize_t,
        }
    });
    result.unwrap_or(ARCHIVE_FATAL as libc::ssize_t)
}

// ---------------------------------------------------------------------------
// External Libarchive Write C-ABI declarations
// ---------------------------------------------------------------------------

extern "C" {
    pub fn archive_write_new() -> *mut libc::c_void;
    pub fn archive_write_set_format_zip(a: *mut libc::c_void) -> libc::c_int;
    pub fn archive_write_open2(
        a: *mut libc::c_void,
        client_data: *mut libc::c_void,
        opener: Option<unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void) -> libc::c_int>,
        writer: Option<
            unsafe extern "C" fn(
                *mut libc::c_void,
                *mut libc::c_void,
                *const libc::c_void,
                libc::size_t,
            ) -> libc::ssize_t,
        >,
        closer: Option<unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void) -> libc::c_int>,
        freeer: Option<unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void) -> libc::c_int>,
    ) -> libc::c_int;
    pub fn archive_write_close(a: *mut libc::c_void) -> libc::c_int;
    pub fn archive_write_free(a: *mut libc::c_void) -> libc::c_int;
}

// ---------------------------------------------------------------------------
// Safe RAII Stream Pipeline Handles
// ---------------------------------------------------------------------------

/// Pinned Safe RAII wrapper for writing archives via custom `Write` streams.
pub struct ArchiveStreamWriter<W> {
    archive_ptr: *mut libc::c_void,
    state: Pin<Box<StreamWriterState<W>>>,
}

impl<W: Write + 'static> ArchiveStreamWriter<W> {
    /// Creates and opens a new `ArchiveStreamWriter`.
    pub fn open_writer(writer: W, buffer_size: usize) -> Result<Self, TTZipStatus> {
        let mut state = Box::pin(StreamWriterState::new(writer, buffer_size));
        unsafe {
            let a = archive_write_new();
            if a.is_null() {
                return Err(TTZipStatus::ErrOutOfMemory);
            }
            archive_write_set_format_zip(a);

            let state_raw: *mut StreamWriterState<W> = Pin::get_unchecked_mut(state.as_mut());
            let ret = archive_write_open2(
                a,
                state_raw as *mut libc::c_void,
                Some(archive_open_callback_trampoline),
                Some(archive_write_callback_trampoline::<W>),
                Some(archive_close_callback_trampoline),
                None,
            );

            if ret != ARCHIVE_OK {
                archive_write_free(a);
                return Err(TTZipStatus::ErrOpenFailed);
            }

            Ok(Self {
                archive_ptr: a,
                state,
            })
        }
    }

    /// Returns the underlying raw `libarchive` handle pointer.
    pub fn as_raw_archive(&self) -> *mut libc::c_void {
        self.archive_ptr
    }

    /// Returns the current stream state snapshot.
    pub fn snapshot(&self) -> StreamStateSnapshot {
        StreamStateSnapshot {
            bytes_consumed: 0,
            bytes_written: self.state.bytes_written,
            is_eof: false,
            has_error: self.state.has_error,
            last_error_msg: self.state.last_error_msg.clone(),
        }
    }
}

impl<W> Drop for ArchiveStreamWriter<W> {
    fn drop(&mut self) {
        if !self.archive_ptr.is_null() {
            unsafe {
                archive_write_close(self.archive_ptr);
                archive_write_free(self.archive_ptr);
            }
            self.archive_ptr = std::ptr::null_mut();
        }
    }
}
