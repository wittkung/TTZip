// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for runtime cancellation tokens.

use crate::runtime::cancellation::{CancellationReason, CancellationToken};
use std::panic::catch_unwind;

#[no_mangle]
pub extern "C" fn ttzip_rust_cancellation_token_new() -> *mut CancellationToken {
    let result = catch_unwind(|| Box::into_raw(Box::new(CancellationToken::new())));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cancellation_token_cancel(
    token: *mut CancellationToken,
    reason: u8,
) {
    let _ = catch_unwind(|| {
        if !token.is_null() {
            (*token).cancel(CancellationReason::from_u8(reason));
        }
    });
}

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

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cancellation_token_free(token: *mut CancellationToken) {
    let _ = catch_unwind(|| {
        if !token.is_null() {
            drop(Box::from_raw(token));
        }
    });
}
