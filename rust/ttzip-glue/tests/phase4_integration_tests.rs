// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Phase 4 Integration Tests:
//! - Stream adapter & micro-buffering (T015)
//! - Safe extraction, ZipSlip defense & bottom-up POSIX restoration (T016)
//! - APFS 16KB page alignment & extent preallocation (T017)
//! - Atomic cancellation tokens & cross-thread channel (T018)
//! - Structured logging router & Swift logger C-ABI bridge (T019)

use std::ffi::{CStr, CString};
use std::fs::{self, File};
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::io::AsRawFd;
use std::sync::atomic::{AtomicUsize, Ordering};

use ttzip_glue::ffi::*;
use ttzip_glue::fs::safe_extract::SafeExtractEngine;
use ttzip_glue::runtime::cancellation::CancellationReason;
use ttzip_glue::types::{TTZipLogLevel, TTZipStatus};

#[test]
fn test_phase4_stream_reader_writer_ffi_roundtrip() {
    let temp_file = std::env::temp_dir().join("ttzip_test_stream_ffi.bin");
    let c_path = CString::new(temp_file.to_str().unwrap()).unwrap();

    // 1. Write data using stream writer FFI
    let writer_handle = unsafe { ttzip_rust_stream_writer_new_file(c_path.as_ptr(), 64 * 1024) };
    assert!(!writer_handle.is_null());

    let payload = b"TTZip Stream Adapter Phase 4 Micro-buffering Invariant Test";
    let w_res = unsafe {
        ttzip_rust_stream_writer_write(writer_handle, payload.as_ptr(), payload.len())
    };
    assert_eq!(w_res, 0);

    let flush_res = unsafe { ttzip_rust_stream_writer_flush(writer_handle) };
    assert_eq!(flush_res, 0);
    unsafe { ttzip_rust_stream_writer_free(writer_handle) };

    // 2. Read data back using stream reader FFI
    let reader_handle = unsafe { ttzip_rust_stream_reader_new_file(c_path.as_ptr(), 64 * 1024) };
    assert!(!reader_handle.is_null());

    let mut out_ptr: *const u8 = std::ptr::null();
    let mut out_len: usize = 0;
    let r_res = unsafe {
        ttzip_rust_stream_reader_read(reader_handle, &mut out_ptr, &mut out_len)
    };
    assert_eq!(r_res, 0);
    assert_eq!(out_len, payload.len());

    let read_slice = unsafe { std::slice::from_raw_parts(out_ptr, out_len) };
    assert_eq!(read_slice, payload);

    unsafe { ttzip_rust_stream_reader_free(reader_handle) };
    let _ = fs::remove_file(&temp_file);
}

#[test]
fn test_phase4_zipslip_and_path_validation_ffi() {
    let dest_dir = CString::new("/tmp/ttzip_safe_test_dir").unwrap();
    let mut out_buf = [0i8; 1024];

    // Valid path
    let valid_entry = CString::new("folder/file.txt").unwrap();
    let status = unsafe {
        ttzip_rust_validate_path(
            dest_dir.as_ptr(),
            valid_entry.as_ptr(),
            out_buf.as_mut_ptr(),
            out_buf.len(),
        )
    };
    assert_eq!(status, TTZipStatus::Ok);
    let sanitized_str = unsafe { CStr::from_ptr(out_buf.as_ptr()).to_str().unwrap() };
    assert_eq!(sanitized_str, "/tmp/ttzip_safe_test_dir/folder/file.txt");

    // ZipSlip Traversal: ../../etc/passwd
    let evil_entry = CString::new("../../etc/passwd").unwrap();
    let evil_status = unsafe {
        ttzip_rust_validate_path(
            dest_dir.as_ptr(),
            evil_entry.as_ptr(),
            out_buf.as_mut_ptr(),
            out_buf.len(),
        )
    };
    assert_eq!(evil_status, TTZipStatus::ErrSecurityViolation);

    // Absolute path traversal: /System/Library
    let abs_entry = CString::new("/System/Library/CoreServices").unwrap();
    let abs_status = unsafe {
        ttzip_rust_validate_path(
            dest_dir.as_ptr(),
            abs_entry.as_ptr(),
            out_buf.as_mut_ptr(),
            out_buf.len(),
        )
    };
    assert_eq!(abs_status, TTZipStatus::ErrSecurityViolation);
}

#[test]
fn test_phase4_safe_extract_bottom_up_permission_engine() {
    let temp_root = std::env::temp_dir().join("ttzip_test_safe_extract_integration");
    let _ = fs::remove_dir_all(&temp_root);
    fs::create_dir_all(&temp_root).unwrap();

    let mut engine = SafeExtractEngine::new();

    // Create 3 levels of nested folders
    let level1 = temp_root.join("deep_a");
    let level2 = level1.join("deep_b");
    let level3 = level2.join("deep_c");

    engine.create_dir_all_secure(&level1, 0o755, 1700000001).unwrap();
    engine.create_dir_all_secure(&level2, 0o750, 1700000002).unwrap();
    engine.create_dir_all_secure(&level3, 0o700, 1700000003).unwrap();

    let file_path = level3.join("secure_file.bin");
    let mut file = engine.create_file_secure(&file_path, 0o640, 1700000004, true).unwrap();
    file.write_all(b"Verified extraction content").unwrap();
    drop(file);

    // Apply deferred metadata bottom-up
    let apply_res = engine.apply_deferred_metadata(true);
    assert_eq!(apply_res, Ok(()));

    // Verify all permissions were applied correctly
    let meta_file = fs::metadata(&file_path).unwrap();
    assert_eq!(meta_file.permissions().mode() & 0o777, 0o640);

    let meta_l3 = fs::metadata(&level3).unwrap();
    assert_eq!(meta_l3.permissions().mode() & 0o777, 0o700);

    let meta_l2 = fs::metadata(&level2).unwrap();
    assert_eq!(meta_l2.permissions().mode() & 0o777, 0o750);

    let meta_l1 = fs::metadata(&level1).unwrap();
    assert_eq!(meta_l1.permissions().mode() & 0o777, 0o755);

    let _ = fs::remove_dir_all(&temp_root);
}

#[test]
fn test_phase4_apfs_preallocate_and_mac_junk_ffi() {
    let temp_file = std::env::temp_dir().join("ttzip_test_apfs_ffi.bin");
    let file = File::create(&temp_file).unwrap();
    let fd = file.as_raw_fd();

    let prealloc_res = ttzip_rust_apfs_preallocate(fd, 131072);
    assert_eq!(prealloc_res, 0);
    drop(file);

    let c_temp_path = CString::new(temp_file.to_str().unwrap()).unwrap();
    let remove_res = unsafe { ttzip_rust_remove_path_fast(c_temp_path.as_ptr()) };
    assert_eq!(remove_res, 0);

    // Junk detector test
    let junk_ds = CString::new("__MACOSX/._archive.zip").unwrap();
    let valid_doc = CString::new("Documents/Project.pdf").unwrap();

    assert!(unsafe { ttzip_rust_is_mac_junk(junk_ds.as_ptr()) });
    assert!(!unsafe { ttzip_rust_is_mac_junk(valid_doc.as_ptr()) });
}

#[test]
fn test_phase4_cancellation_token_ffi() {
    let token = ttzip_rust_cancellation_token_new();
    assert!(!token.is_null());

    assert!(!unsafe { ttzip_rust_cancellation_token_is_cancelled(token) });

    unsafe {
        ttzip_rust_cancellation_token_cancel(token, CancellationReason::UserRequested as u8);
    }

    assert!(unsafe { ttzip_rust_cancellation_token_is_cancelled(token) });
    unsafe { ttzip_rust_cancellation_token_free(token) };
}

static RECEIVED_LOG_COUNT: AtomicUsize = AtomicUsize::new(0);

unsafe extern "C" fn phase4_test_logger_callback(
    level: TTZipLogLevel,
    target: *const libc::c_char,
    message: *const libc::c_char,
    _file: *const libc::c_char,
    _line: i32,
    _user_data: *mut libc::c_void,
) {
    RECEIVED_LOG_COUNT.fetch_add(1, Ordering::SeqCst);
    assert_eq!(level, TTZipLogLevel::Info);
    let target_str = CStr::from_ptr(target).to_str().unwrap();
    let msg_str = CStr::from_ptr(message).to_str().unwrap();
    assert_eq!(target_str, "TTZipCore::Streaming");
    assert_eq!(msg_str, "Micro-buffer stream initialized with 64KB");
}

#[test]
fn test_phase4_structured_logging_ffi_routing() {
    RECEIVED_LOG_COUNT.store(0, Ordering::SeqCst);

    let status = unsafe {
        ttzip_rust_set_logger(
            Some(phase4_test_logger_callback),
            TTZipLogLevel::Debug,
            std::ptr::null_mut(),
        )
    };
    assert_eq!(status, TTZipStatus::Ok);

    let target_c = CString::new("TTZipCore::Streaming").unwrap();
    let msg_c = CString::new("Micro-buffer stream initialized with 64KB").unwrap();
    let file_c = CString::new("stream_adapter.rs").unwrap();

    unsafe {
        ttzip_rust_log(
            TTZipLogLevel::Info,
            target_c.as_ptr(),
            msg_c.as_ptr(),
            file_c.as_ptr(),
            100,
        );
    }

    assert_eq!(RECEIVED_LOG_COUNT.load(Ordering::SeqCst), 1);
}
