// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Libarchive Seek and Skip C-ABI trampolines and seekable reader state methods.

use super::{ARCHIVE_FATAL, StreamReaderState};
use std::io::{Read, Seek, SeekFrom};
use std::panic::catch_unwind;

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
