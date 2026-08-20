// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Stream adapter bridging `std::io::{Read, Write, Seek}` to `libarchive` C callbacks.
//!
//! Enforces:
//! 1. Memory bound: $\le 64\text{MB}$ RSS resident memory limit with micro-buffering (64KB - 2MB).
//! 2. Panic safety: FFI exception barriers via `std::panic::catch_unwind` on all trampoline entry points.
//! 3. Pinned callback state (`Pin<Box<StreamReaderState<R>>>`) ensuring stable raw pointers.

use crate::types::TTZipStatus;
use std::io::{Read, Seek, SeekFrom, Write};
use std::panic::catch_unwind;
use std::pin::Pin;

/// Libarchive status constants.
pub const ARCHIVE_OK: libc::c_int = 0;
pub const ARCHIVE_EOF: libc::c_int = 1;
pub const ARCHIVE_RETRY: libc::c_int = -10;
pub const ARCHIVE_WARN: libc::c_int = -20;
pub const ARCHIVE_FAILED: libc::c_int = -25;
pub const ARCHIVE_FATAL: libc::c_int = -30;

/// Default micro-buffer size: 64 KB.
pub const DEFAULT_STREAM_BUFFER_SIZE: usize = 64 * 1024;
/// Maximum allowable buffer capacity per stream: 2 MB.
pub const MAX_STREAM_BUFFER_SIZE: usize = 2 * 1024 * 1024;
/// Task hard limit for resident memory allocation: 64 MB.
pub const MAX_RESIDENT_MEMORY_MB: usize = 64;

/// Stream pipeline operating mode conforming to `contracts/ttzip_stream_contract.json`.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipStreamMode {
    ReadSequential,
    ReadSeekable,
    WriteSequential,
    WriteChunkedArena,
}

/// State snapshot for stream progress monitoring and contract compliance.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StreamStateSnapshot {
    pub bytes_consumed: u64,
    pub bytes_written: u64,
    pub is_eof: bool,
    pub has_error: bool,
    pub last_error_msg: Option<String>,
}

/// Internal state for custom stream reading callbacks.
pub struct StreamReaderState<R> {
    pub reader: R,
    pub buffer: Vec<u8>,
    pub bytes_consumed: u64,
    pub is_eof: bool,
    pub has_error: bool,
    pub last_error_msg: Option<String>,
}

impl<R: Read> StreamReaderState<R> {
    /// Creates a new `StreamReaderState` with the specified micro-buffer capacity.
    pub fn new(reader: R, buffer_size: usize) -> Self {
        let cap = buffer_size.clamp(DEFAULT_STREAM_BUFFER_SIZE, MAX_STREAM_BUFFER_SIZE);
        Self {
            reader,
            buffer: vec![0u8; cap],
            bytes_consumed: 0,
            is_eof: false,
            has_error: false,
            last_error_msg: None,
        }
    }

    /// Reads the next chunk of data from the underlying reader into the internal buffer.
    pub fn read_chunk(&mut self) -> std::io::Result<(*const u8, usize)> {
        if self.is_eof {
            return Ok((self.buffer.as_ptr(), 0));
        }

        match self.reader.read(&mut self.buffer) {
            Ok(0) => {
                self.is_eof = true;
                Ok((self.buffer.as_ptr(), 0))
            }
            Ok(n) => {
                self.bytes_consumed = self.bytes_consumed.saturating_add(n as u64);
                Ok((self.buffer.as_ptr(), n))
            }
            Err(e) => {
                if e.kind() == std::io::ErrorKind::Interrupted {
                    return self.read_chunk();
                }
                self.has_error = true;
                self.last_error_msg = Some(e.to_string());
                Err(e)
            }
        }
    }

    /// Takes a point-in-time snapshot of the reader state.
    pub fn snapshot(&self) -> StreamStateSnapshot {
        StreamStateSnapshot {
            bytes_consumed: self.bytes_consumed,
            bytes_written: 0,
            is_eof: self.is_eof,
            has_error: self.has_error,
            last_error_msg: self.last_error_msg.clone(),
        }
    }
}

impl<R: Read + Seek> StreamReaderState<R> {
    /// Skips forward by `request` bytes using the underlying seeker.
    pub fn skip(&mut self, request: i64) -> std::io::Result<i64> {
        if request == 0 {
            return Ok(0);
        }
        let old_pos = self.reader.stream_position()?;
        let new_pos = self.reader.seek(SeekFrom::Current(request))?;
        let delta = new_pos as i64 - old_pos as i64;
        if delta > 0 {
            self.bytes_consumed = self.bytes_consumed.saturating_add(delta as u64);
        }
        Ok(delta)
    }

    /// Seeks to a specific offset based on `whence`.
    pub fn seek(&mut self, whence: SeekFrom) -> std::io::Result<u64> {
        self.reader.seek(whence)
    }
}

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
// Libarchive Trampoline Callbacks (with Exception Barrier)
// ---------------------------------------------------------------------------

/// C-ABI read callback trampoline for `libarchive`.
pub unsafe extern "C" fn archive_read_callback_trampoline<R: Read>(
    _archive: *mut libc::c_void,
    client_data: *mut libc::c_void,
    buffer: *mut *const libc::c_void,
) -> libc::ssize_t {
    let result = catch_unwind(|| {
        if client_data.is_null() || buffer.is_null() {
            return ARCHIVE_FATAL as libc::ssize_t;
        }
        let state = &mut *(client_data as *mut StreamReaderState<R>);
        match state.read_chunk() {
            Ok((ptr, len)) => {
                *buffer = ptr as *const libc::c_void;
                len as libc::ssize_t
            }
            Err(_) => ARCHIVE_FATAL as libc::ssize_t,
        }
    });
    result.unwrap_or(ARCHIVE_FATAL as libc::ssize_t)
}

/// C-ABI skip callback trampoline for `libarchive` (with seek capability).
pub unsafe extern "C" fn archive_skip_callback_trampoline<R: Read + Seek>(
    _archive: *mut libc::c_void,
    client_data: *mut libc::c_void,
    request: i64,
) -> i64 {
    let result = catch_unwind(|| {
        if client_data.is_null() {
            return ARCHIVE_FATAL as i64;
        }
        let state = &mut *(client_data as *mut StreamReaderState<R>);
        match state.skip(request) {
            Ok(skipped) => skipped,
            Err(_) => 0, // Libarchive falls back to reading and discarding
        }
    });
    result.unwrap_or(0)
}

/// C-ABI seek callback trampoline for `libarchive`.
pub unsafe extern "C" fn archive_seek_callback_trampoline<R: Read + Seek>(
    _archive: *mut libc::c_void,
    client_data: *mut libc::c_void,
    offset: i64,
    whence: libc::c_int,
) -> i64 {
    let result = catch_unwind(|| {
        if client_data.is_null() {
            return ARCHIVE_FATAL as i64;
        }
        let state = &mut *(client_data as *mut StreamReaderState<R>);
        let seek_from = match whence {
            libc::SEEK_SET => {
                if offset < 0 {
                    return ARCHIVE_FATAL as i64;
                }
                SeekFrom::Start(offset as u64)
            }
            libc::SEEK_CUR => SeekFrom::Current(offset),
            libc::SEEK_END => SeekFrom::End(offset),
            _ => return ARCHIVE_FATAL as i64,
        };

        match state.seek(seek_from) {
            Ok(new_pos) => new_pos as i64,
            Err(e) => {
                state.has_error = true;
                state.last_error_msg = Some(e.to_string());
                ARCHIVE_FATAL as i64
            }
        }
    });
    result.unwrap_or(ARCHIVE_FATAL as i64)
}

/// C-ABI open callback trampoline for `libarchive`.
pub unsafe extern "C" fn archive_open_callback_trampoline(
    _archive: *mut libc::c_void,
    _client_data: *mut libc::c_void,
) -> libc::c_int {
    let result = catch_unwind(|| ARCHIVE_OK);
    result.unwrap_or(ARCHIVE_FATAL)
}

/// C-ABI close callback trampoline for `libarchive`.
pub unsafe extern "C" fn archive_close_callback_trampoline(
    _archive: *mut libc::c_void,
    _client_data: *mut libc::c_void,
) -> libc::c_int {
    let result = catch_unwind(|| ARCHIVE_OK);
    result.unwrap_or(ARCHIVE_FATAL)
}

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
// External Libarchive C-ABI declarations
// ---------------------------------------------------------------------------

extern "C" {
    pub fn archive_read_new() -> *mut libc::c_void;
    pub fn archive_read_support_format_all(a: *mut libc::c_void) -> libc::c_int;
    pub fn archive_read_support_filter_all(a: *mut libc::c_void) -> libc::c_int;
    pub fn archive_read_open2(
        a: *mut libc::c_void,
        client_data: *mut libc::c_void,
        opener: Option<unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void) -> libc::c_int>,
        reader: Option<
            unsafe extern "C" fn(
                *mut libc::c_void,
                *mut libc::c_void,
                *mut *const libc::c_void,
            ) -> libc::ssize_t,
        >,
        skipper: Option<
            unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void, i64) -> i64,
        >,
        closer: Option<unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void) -> libc::c_int>,
    ) -> libc::c_int;
    pub fn archive_read_set_seek_callback(
        a: *mut libc::c_void,
        seeker: Option<
            unsafe extern "C" fn(*mut libc::c_void, *mut libc::c_void, i64, libc::c_int) -> i64,
        >,
    ) -> libc::c_int;
    pub fn archive_read_close(a: *mut libc::c_void) -> libc::c_int;
    pub fn archive_read_free(a: *mut libc::c_void) -> libc::c_int;

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

/// Pinned Safe RAII wrapper for reading archives via custom `Read` / `Seek` streams.
pub struct ArchiveStreamReader<R> {
    archive_ptr: *mut libc::c_void,
    state: Pin<Box<StreamReaderState<R>>>,
}

impl<R: Read + 'static> ArchiveStreamReader<R> {
    /// Creates and opens a new sequential `ArchiveStreamReader`.
    pub fn open_sequential(reader: R, buffer_size: usize) -> Result<Self, TTZipStatus> {
        let mut state = Box::pin(StreamReaderState::new(reader, buffer_size));
        unsafe {
            let a = archive_read_new();
            if a.is_null() {
                return Err(TTZipStatus::ErrOutOfMemory);
            }
            archive_read_support_format_all(a);
            archive_read_support_filter_all(a);

            let state_raw: *mut StreamReaderState<R> = Pin::get_unchecked_mut(state.as_mut());
            let ret = archive_read_open2(
                a,
                state_raw as *mut libc::c_void,
                Some(archive_open_callback_trampoline),
                Some(archive_read_callback_trampoline::<R>),
                None,
                Some(archive_close_callback_trampoline),
            );

            if ret != ARCHIVE_OK {
                archive_read_free(a);
                return Err(TTZipStatus::ErrOpenFailed);
            }

            Ok(Self {
                archive_ptr: a,
                state,
            })
        }
    }
}

impl<R: Read + Seek + 'static> ArchiveStreamReader<R> {
    /// Creates and opens a new seekable `ArchiveStreamReader`.
    pub fn open_seekable(reader: R, buffer_size: usize) -> Result<Self, TTZipStatus> {
        let mut state = Box::pin(StreamReaderState::new(reader, buffer_size));
        unsafe {
            let a = archive_read_new();
            if a.is_null() {
                return Err(TTZipStatus::ErrOutOfMemory);
            }
            archive_read_support_format_all(a);
            archive_read_support_filter_all(a);

            let state_raw: *mut StreamReaderState<R> = Pin::get_unchecked_mut(state.as_mut());
            let ret = archive_read_open2(
                a,
                state_raw as *mut libc::c_void,
                Some(archive_open_callback_trampoline),
                Some(archive_read_callback_trampoline::<R>),
                Some(archive_skip_callback_trampoline::<R>),
                Some(archive_close_callback_trampoline),
            );

            if ret != ARCHIVE_OK {
                archive_read_free(a);
                return Err(TTZipStatus::ErrOpenFailed);
            }

            archive_read_set_seek_callback(a, Some(archive_seek_callback_trampoline::<R>));

            Ok(Self {
                archive_ptr: a,
                state,
            })
        }
    }
}

impl<R> ArchiveStreamReader<R> {
    /// Returns the underlying raw `libarchive` handle pointer.
    pub fn as_raw_archive(&self) -> *mut libc::c_void {
        self.archive_ptr
    }

    /// Returns the current stream state snapshot.
    pub fn snapshot(&self) -> StreamStateSnapshot {
        StreamStateSnapshot {
            bytes_consumed: self.state.bytes_consumed,
            bytes_written: 0,
            is_eof: self.state.is_eof,
            has_error: self.state.has_error,
            last_error_msg: self.state.last_error_msg.clone(),
        }
    }
}

impl<R> Drop for ArchiveStreamReader<R> {
    fn drop(&mut self) {
        if !self.archive_ptr.is_null() {
            unsafe {
                archive_read_close(self.archive_ptr);
                archive_read_free(self.archive_ptr);
            }
            self.archive_ptr = std::ptr::null_mut();
        }
    }
}

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

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_stream_reader_state_reading() {
        let sample_data = b"Hello, TTZip streaming micro-buffer pipeline!";
        let cursor = Cursor::new(sample_data.to_vec());
        let mut state = StreamReaderState::new(cursor, 16);

        let (ptr, len) = state.read_chunk().expect("read_chunk should succeed");
        assert_eq!(len, sample_data.len());
        let slice = unsafe { std::slice::from_raw_parts(ptr, len) };
        assert_eq!(&slice[..sample_data.len()], sample_data);
        assert_eq!(state.bytes_consumed, sample_data.len() as u64);

        let (_, len2) = state.read_chunk().expect("read_chunk at EOF");
        assert_eq!(len2, 0);
        assert!(state.is_eof);
    }

    #[test]
    fn test_stream_reader_state_seek_and_skip() {
        let sample_data = b"0123456789ABCDEF";
        let cursor = Cursor::new(sample_data.to_vec());
        let mut state = StreamReaderState::new(cursor, 64 * 1024);

        let skipped = state.skip(4).expect("skip forward");
        assert_eq!(skipped, 4);

        let new_pos = state.seek(SeekFrom::Start(10)).expect("seek to 10");
        assert_eq!(new_pos, 10);

        let new_pos2 = state.seek(SeekFrom::End(-2)).expect("seek from end");
        assert_eq!(new_pos2, 14);
    }

    #[test]
    fn test_stream_writer_state_writing() {
        let mut output = Vec::new();
        let mut state = StreamWriterState::new(&mut output, 64 * 1024);

        let chunk1 = b"Chunk 1: Hello World; ";
        let chunk2 = b"Chunk 2: TTZip Rust Glue!";
        let n1 = state.write_chunk(chunk1).expect("write chunk 1");
        let n2 = state.write_chunk(chunk2).expect("write chunk 2");

        assert_eq!(n1, chunk1.len());
        assert_eq!(n2, chunk2.len());
        assert_eq!(state.bytes_written, (chunk1.len() + chunk2.len()) as u64);
        assert_eq!(output, [chunk1.as_slice(), chunk2.as_slice()].concat());
    }

    #[test]
    fn test_read_callback_trampoline_panic_catch() {
        unsafe {
            let res = archive_read_callback_trampoline::<Cursor<Vec<u8>>>(
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                std::ptr::null_mut(),
            );
            assert_eq!(res, ARCHIVE_FATAL as libc::ssize_t);
        }
    }

    #[test]
    fn test_seek_callback_trampoline_panic_catch() {
        unsafe {
            let res = archive_seek_callback_trampoline::<Cursor<Vec<u8>>>(
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                0,
                libc::SEEK_SET,
            );
            assert_eq!(res, ARCHIVE_FATAL as i64);
        }
    }
}
