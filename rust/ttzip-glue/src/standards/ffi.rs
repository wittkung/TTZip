// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe C-ABI exports for format sniffing and standards compliance checking.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;
use std::path::Path;
use std::slice;

use super::checkers::{check_compliance_buffer, check_compliance_file};
use super::signatures::DetectedFormat;
use super::sniffer::{detect_format_buffer, detect_format_file};
use crate::types::TTZipStatus;

/// Detects archive format from an in-memory byte buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_detect_format_buffer(
    buf: *const u8,
    len: usize,
    filename_hint: *const c_char,
    out_format: *mut i32,
    out_is_sfx: *mut bool,
    out_sfx_offset: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if buf.is_null() || len == 0 || out_format.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let slice = slice::from_raw_parts(buf, len);
        let hint_str = if !filename_hint.is_null() {
            CStr::from_ptr(filename_hint).to_str().ok()
        } else {
            None
        };

        let sniff = detect_format_buffer(slice, hint_str);

        *out_format = sniff.format as i32;
        if !out_is_sfx.is_null() {
            *out_is_sfx = sniff.is_sfx;
        }
        if !out_sfx_offset.is_null() {
            *out_sfx_offset = sniff.sfx_offset;
        }

        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Detects archive format from a filesystem path.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_detect_format_file(
    file_path: *const c_char,
    out_format: *mut i32,
    out_is_sfx: *mut bool,
    out_sfx_offset: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if file_path.is_null() || out_format.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let c_str = CStr::from_ptr(file_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match detect_format_file(Path::new(path_str)) {
            Ok(sniff) => {
                *out_format = sniff.format as i32;
                if !out_is_sfx.is_null() {
                    *out_is_sfx = sniff.is_sfx;
                }
                if !out_sfx_offset.is_null() {
                    *out_sfx_offset = sniff.sfx_offset;
                }
                TTZipStatus::Ok
            }
            Err(_) => TTZipStatus::ErrFileNotFound,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Validates format compliance on an in-memory buffer, outputting a structured JSON report.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_check_compliance_buffer(
    buf: *const u8,
    len: usize,
    format_hint: i32,
    out_report_json: *mut *mut c_char,
    out_is_compliant: *mut bool,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if buf.is_null() || len == 0 || out_report_json.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let slice = slice::from_raw_parts(buf, len);
        let format = match format_hint {
            1 => DetectedFormat::Zip,
            2 => DetectedFormat::SevenZip,
            3 => DetectedFormat::Tar,
            4 => DetectedFormat::Gzip,
            5 => DetectedFormat::Bzip2,
            6 => DetectedFormat::Xz,
            7 => DetectedFormat::Zstd,
            8 => DetectedFormat::Rar,
            9 => DetectedFormat::Cab,
            10 => DetectedFormat::Iso,
            11 => DetectedFormat::Dmg,
            12 => DetectedFormat::Xar,
            13 => DetectedFormat::Lzh,
            14 => DetectedFormat::Ar,
            15 => DetectedFormat::Lzfse,
            16 => DetectedFormat::Snappy,
            17 => DetectedFormat::Lz4,
            _ => DetectedFormat::Unknown,
        };

        let report = check_compliance_buffer(format, slice);

        if !out_is_compliant.is_null() {
            *out_is_compliant = report.is_compliant;
        }

        let json_str = report.to_json();
        match CString::new(json_str) {
            Ok(c_string) => {
                *out_report_json = c_string.into_raw();
                TTZipStatus::Ok
            }
            Err(_) => TTZipStatus::ErrOutOfMemory,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Validates format compliance on an archive file, outputting a structured JSON report.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_check_compliance_file(
    file_path: *const c_char,
    out_report_json: *mut *mut c_char,
    out_is_compliant: *mut bool,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if file_path.is_null() || out_report_json.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let c_str = CStr::from_ptr(file_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match check_compliance_file(Path::new(path_str)) {
            Ok(report) => {
                if !out_is_compliant.is_null() {
                    *out_is_compliant = report.is_compliant;
                }

                let json_str = report.to_json();
                match CString::new(json_str) {
                    Ok(c_string) => {
                        *out_report_json = c_string.into_raw();
                        TTZipStatus::Ok
                    }
                    Err(_) => TTZipStatus::ErrOutOfMemory,
                }
            }
            Err(_) => TTZipStatus::ErrFileNotFound,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Frees a JSON report allocated by compliance checking functions.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_free_compliance_report(report_ptr: *mut c_char) {
    if !report_ptr.is_null() {
        let _ = CString::from_raw(report_ptr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ptr;

    #[test]
    fn test_ffi_detect_format_buffer() {
        let mut zip_header = vec![0u8; 30];
        zip_header[0..4].copy_from_slice(b"PK\x03\x04");

        let mut format: i32 = 0;
        let mut is_sfx: bool = false;
        let mut sfx_offset: usize = 0;

        let status = unsafe {
            ttzip_rust_detect_format_buffer(
                zip_header.as_ptr(),
                zip_header.len(),
                ptr::null(),
                &mut format,
                &mut is_sfx,
                &mut sfx_offset,
            )
        };

        assert_eq!(status, TTZipStatus::Ok);
        assert_eq!(format, DetectedFormat::Zip as i32);
        assert_eq!(is_sfx, false);
    }

    #[test]
    fn test_ffi_check_compliance_buffer_and_free() {
        let mut gz_buf = vec![0u8; 18];
        gz_buf[0] = 0x1F;
        gz_buf[1] = 0x8B;
        gz_buf[2] = 8;

        let mut report_ptr: *mut c_char = ptr::null_mut();
        let mut is_compliant: bool = false;

        let status = unsafe {
            ttzip_rust_check_compliance_buffer(
                gz_buf.as_ptr(),
                gz_buf.len(),
                4, // Gzip
                &mut report_ptr,
                &mut is_compliant,
            )
        };

        assert_eq!(status, TTZipStatus::Ok);
        assert!(is_compliant);
        assert!(!report_ptr.is_null());

        let json = unsafe { CStr::from_ptr(report_ptr).to_str().unwrap() };
        assert!(json.contains("\"format\": \"Gzip\""));
        assert!(json.contains("\"is_compliant\": true"));

        unsafe {
            ttzip_rust_free_compliance_report(report_ptr);
        }
    }
}
