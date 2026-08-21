// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for in-place atomic archive editing sessions.

use crate::archive::in_place_edit::InPlaceArchiveSession;
use crate::types::{TTZipArchiveFormat, TTZipStatus};
use libc::c_char;
use std::ffi::CStr;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

/// Opaque FFI wrapper handle around transactional in-place archive mutation session.
pub struct TTZipInPlaceSession {
    pub inner: InPlaceArchiveSession,
}

impl std::panic::RefUnwindSafe for TTZipInPlaceSession {}
impl std::panic::UnwindSafe for TTZipInPlaceSession {}

/// Begins a new transactional in-place archive mutation session.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_begin(
    archive_path: *const c_char,
    format: i32,
    out_session: *mut *mut TTZipInPlaceSession,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if archive_path.is_null() || out_session.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let path_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let fmt = match format {
            1 => Some(TTZipArchiveFormat::Zip),
            2 => Some(TTZipArchiveFormat::SevenZip),
            3 => Some(TTZipArchiveFormat::Tar),
            _ => None,
        };

        match InPlaceArchiveSession::begin(Path::new(path_str), fmt) {
            Ok(session) => {
                *out_session = Box::into_raw(Box::new(TTZipInPlaceSession { inner: session }));
                TTZipStatus::Ok
            }
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Appends a new file entry into the in-place editing session.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_append(
    session: *mut TTZipInPlaceSession,
    entry_path: *const c_char,
    source_file_path: *const c_char,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() || entry_path.is_null() || source_file_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let entry_str = match CStr::from_ptr(entry_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let src_str = match CStr::from_ptr(source_file_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let s = &mut (*session).inner;
        match s.append(entry_str, Path::new(src_str)) {
            Ok(()) => TTZipStatus::Ok,
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Replaces an existing entry inside the in-place editing session.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_replace(
    session: *mut TTZipInPlaceSession,
    entry_path: *const c_char,
    source_file_path: *const c_char,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() || entry_path.is_null() || source_file_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let entry_str = match CStr::from_ptr(entry_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let src_str = match CStr::from_ptr(source_file_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let s = &mut (*session).inner;
        match s.replace(entry_str, Path::new(src_str)) {
            Ok(()) => TTZipStatus::Ok,
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Deletes an entry inside the in-place editing session.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_delete(
    session: *mut TTZipInPlaceSession,
    entry_path: *const c_char,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() || entry_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let entry_str = match CStr::from_ptr(entry_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let s = &mut (*session).inner;
        match s.delete(entry_str) {
            Ok(()) => TTZipStatus::Ok,
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Commits the in-place editing session atomically into the original archive.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_commit(
    session: *mut TTZipInPlaceSession,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let s = &mut (*session).inner;
        match s.commit() {
            Ok(()) => TTZipStatus::Ok,
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Cancels the session, rolling back all uncommitted mutations and removing shadow files.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_cancel(
    session: *mut TTZipInPlaceSession,
) -> TTZipStatus {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let s = &mut (*session).inner;
        match s.cancel() {
            Ok(()) => TTZipStatus::Ok,
            Err(st) => st,
        }
    }));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Frees an in-place session handle and releases resources.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inplace_session_free(session: *mut TTZipInPlaceSession) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !session.is_null() {
            drop(Box::from_raw(session));
        }
    }));
}
