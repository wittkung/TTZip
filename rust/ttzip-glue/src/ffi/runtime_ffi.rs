// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for runtime cancellation tokens and structured logger routing.

use crate::runtime::cancellation::{CancellationReason, CancellationToken};
use crate::runtime::logging::{emit_log_direct, set_logger_callback, TTZipLogCallback};
use crate::types::{TTZipLogLevel, TTZipStatus};
use libc::{c_char, c_void};
use std::ffi::CStr;
use std::panic::catch_unwind;

/// Allocates a new heap-allocated cancellation token.
#[no_mangle]
pub extern "C" fn ttzip_rust_cancellation_token_new() -> *mut CancellationToken {
    let result = catch_unwind(|| {
        Box::into_raw(Box::new(CancellationToken::new()))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Triggers cancellation on the specified token.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cancellation_token_cancel(
    token: *mut CancellationToken,
    reason: u8,
) {
    let _ = catch_unwind(|| {
        if !token.is_null() {
            let token_ref = &*token;
            token_ref.cancel(CancellationReason::from_u8(reason));
        }
    });
}

/// Returns true if the token has been cancelled.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cancellation_token_is_cancelled(
    token: *const CancellationToken,
) -> bool {
    let result = catch_unwind(|| {
        if token.is_null() {
            false
        } else {
            (*token).is_cancelled()
        }
    });
    result.unwrap_or(false)
}

/// Frees a heap-allocated cancellation token.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cancellation_token_free(token: *mut CancellationToken) {
    let _ = catch_unwind(|| {
        if !token.is_null() {
            drop(Box::from_raw(token));
        }
    });
}

/// Sets the global C logger callback.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_set_logger(
    callback: TTZipLogCallback,
    min_level: TTZipLogLevel,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        set_logger_callback(callback, min_level, user_data)
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Emits a structured log message to the registered C callback.
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
