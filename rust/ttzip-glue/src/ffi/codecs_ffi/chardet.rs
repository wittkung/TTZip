// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Charset Detector C-ABI FFI exports.

use crate::codecs::chardet::detect_charset;
use crate::types::TTZipStatus;
use libc::{c_char, size_t};
use std::panic::catch_unwind;

// MARK: - Charset Detector C-ABI

#[no_mangle]
pub extern "C" fn ttzip_rust_detect_charset(
    data: *const u8,
    data_len: size_t,
    out_buf: *mut c_char,
    out_buf_capacity: size_t,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_buf.is_null() || out_buf_capacity == 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        if data_len > 0 && data.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let in_slice = if data_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(data, data_len) }
        };

        if let Some(charset) = detect_charset(in_slice) {
            let bytes = charset.as_bytes();
            if bytes.len() + 1 > out_buf_capacity {
                return TTZipStatus::ErrPathTooLong;
            }
            unsafe {
                std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf as *mut u8, bytes.len());
                *out_buf.add(bytes.len()) = 0;
            }
            TTZipStatus::Ok
        } else {
            unsafe {
                *out_buf = 0;
            }
            TTZipStatus::Ok
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
