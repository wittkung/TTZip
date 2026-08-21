// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for self-healing recovery records and streaming repair.

use crate::crypto::rs_fec;
use crate::types::TTZipStatus;
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::slice;

/// C-ABI exported recovery record generator.
///
/// # Safety
/// - `payload` points to `payload_len` bytes.
/// - `out_record` receives the pointer to allocated record bytes on success.
/// - `out_record_len` receives the length of allocated bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_create_recovery_record(
    payload: *const u8,
    payload_len: usize,
    redundancy_percent: f64,
    slice_size: usize,
    out_record: *mut *mut u8,
    out_record_len: *mut usize,
) -> i32 {
    let result = catch_unwind(|| {
        if payload.is_null()
            || payload_len == 0
            || out_record.is_null()
            || out_record_len.is_null()
        {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let payload_slice = slice::from_raw_parts(payload, payload_len);
        match rs_fec::create_recovery_record(payload_slice, redundancy_percent, slice_size) {
            Ok(mut block) => {
                block.shrink_to_fit();
                *out_record_len = block.len();
                let ptr = block.as_mut_ptr();
                std::mem::forget(block);
                *out_record = ptr;
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported streaming recovery record appending to file.
///
/// # Safety
/// - `archive_path` must be a valid null-terminated C string.
/// - Optional output pointers receive metadata on success.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_append_recovery_record_file(
    archive_path: *const libc::c_char,
    redundancy_percent: f64,
    slice_size: usize,
    out_data_slices: *mut usize,
    out_parity_slices: *mut usize,
    out_protected_len: *mut u64,
    out_root_hash: *mut u8,
) -> i32 {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }
        let c_str = CStr::from_ptr(archive_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam.to_i32(),
        };

        match rs_fec::append_recovery_record_to_file(
            std::path::Path::new(path_str),
            redundancy_percent,
            slice_size,
        ) {
            Ok(info) => {
                if !out_data_slices.is_null() {
                    *out_data_slices = info.data_slices_count;
                }
                if !out_parity_slices.is_null() {
                    *out_parity_slices = info.parity_slices_count;
                }
                if !out_protected_len.is_null() {
                    *out_protected_len = info.protected_payload_length;
                }
                if !out_root_hash.is_null() {
                    let hash_slice = slice::from_raw_parts_mut(out_root_hash, 32);
                    hash_slice.copy_from_slice(&info.root_hash);
                }
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported file recovery record inspector.
///
/// # Safety
/// - `archive_path` must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_inspect_recovery_record_file(
    archive_path: *const libc::c_char,
    out_slice_size: *mut usize,
    out_data_slices: *mut usize,
    out_parity_slices: *mut usize,
    out_protected_len: *mut u64,
    out_root_hash: *mut u8,
    out_has_record: *mut bool,
) -> i32 {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let c_str = CStr::from_ptr(archive_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam.to_i32(),
        };

        let mut file = match std::fs::File::open(std::path::Path::new(path_str)) {
            Ok(f) => f,
            Err(_) => return TTZipStatus::ErrFileNotFound.to_i32(),
        };

        match rs_fec::inspect_recovery_record_reader(&mut file) {
            Ok(Some(info)) => {
                if !out_has_record.is_null() {
                    *out_has_record = true;
                }
                if !out_slice_size.is_null() {
                    *out_slice_size = info.slice_size;
                }
                if !out_data_slices.is_null() {
                    *out_data_slices = info.data_slices_count;
                }
                if !out_parity_slices.is_null() {
                    *out_parity_slices = info.parity_slices_count;
                }
                if !out_protected_len.is_null() {
                    *out_protected_len = info.protected_payload_length;
                }
                if !out_root_hash.is_null() {
                    let hash_slice = slice::from_raw_parts_mut(out_root_hash, 32);
                    hash_slice.copy_from_slice(&info.root_hash);
                }
                TTZipStatus::Ok.to_i32()
            }
            Ok(None) => {
                if !out_has_record.is_null() {
                    *out_has_record = false;
                }
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported in-place streaming archive self-healing repair.
///
/// # Safety
/// - `archive_path` must be a valid null-terminated C string.
/// - `out_repaired` receives 1 if repaired or already intact, 0 on repair failure.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_repair_archive_streaming(
    archive_path: *const libc::c_char,
    out_repaired: *mut bool,
) -> i32 {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let c_str = CStr::from_ptr(archive_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam.to_i32(),
        };

        match rs_fec::repair_archive_file_streaming(std::path::Path::new(path_str)) {
            Ok(repaired) => {
                if !out_repaired.is_null() {
                    *out_repaired = repaired;
                }
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported in-place archive self-healing repair alias.
///
/// # Safety
/// - `archive_path` must be a valid null-terminated C string.
/// - `out_repaired` receives 1 if repaired or already intact, 0 on repair failure.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_repair_archive(
    archive_path: *const libc::c_char,
    out_repaired: *mut bool,
) -> i32 {
    ttzip_rust_rs_repair_archive_streaming(archive_path, out_repaired)
}

/// C-ABI free allocated recovery record buffer.
///
/// # Safety
/// - `ptr` must be a pointer returned by `ttzip_rust_rs_create_recovery_record` with size `len`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        let _ = Vec::from_raw_parts(ptr, len, len);
    }
}
