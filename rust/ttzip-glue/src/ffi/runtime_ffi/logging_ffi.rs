// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for structured logger routing.

use crate::runtime::logging::{emit_log_direct, set_logger_callback, TTZipLogCallback};
use crate::types::{TTZipLogLevel, TTZipStatus};
use libc::{c_char, c_void};
use std::ffi::CStr;
use std::panic::catch_unwind;

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_set_logger(
    callback: TTZipLogCallback,
    min_level: TTZipLogLevel,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| set_logger_callback(callback, min_level, user_data));
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_log(
    level: TTZipLogLevel,
    target: *const c_char,
    message: *const c_char,
    file: *const c_char,
    line: i32,
) {
    let _ = catch_unwind(|| {
        let target_str = if !target.is_null() {
            CStr::from_ptr(target).to_str().unwrap_or("unknown")
        } else {
            "unknown"
        };
        let message_str = if !message.is_null() {
            CStr::from_ptr(message).to_str().unwrap_or("")
        } else {
            ""
        };
        let file_str = if !file.is_null() {
            CStr::from_ptr(file).to_str().unwrap_or("")
        } else {
            ""
        };
        emit_log_direct(level, target_str, message_str, file_str, line);
    });
}
