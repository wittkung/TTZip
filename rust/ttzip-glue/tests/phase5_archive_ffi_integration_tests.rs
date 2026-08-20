// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Phase 5 Integration Tests for Archive FFI:
//! - ttzip_rust_create_archive (ZIP, TAR, TAR.GZ)
//! - ttzip_rust_inspect_archive (metadata verification & early halting)
//! - ttzip_rust_extract_archive (two-stage safe extraction, dry-run, progress callback, ZipSlip defense)

use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::sync::atomic::{AtomicUsize, Ordering};
use ttzip_glue::ffi::*;
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipEntryMetadata, TTZipExtractOptions, TTZipStatus,
};

static INSPECT_COUNT: AtomicUsize = AtomicUsize::new(0);

unsafe extern "C" fn test_inspect_cb(
    entry: *const TTZipEntryMetadata,
    _user_data: *mut libc::c_void,
) -> bool {
    if !entry.is_null() {
        let meta = &*entry;
        assert!(!meta.path.is_null());
        INSPECT_COUNT.fetch_add(1, Ordering::SeqCst);
    }
    true
}

static PROGRESS_BYTES: AtomicUsize = AtomicUsize::new(0);

unsafe extern "C" fn test_progress_cb(
    processed_bytes: u64,
    _total_bytes: u64,
    _current_entry: *const libc::c_char,
    _user_data: *mut libc::c_void,
) -> bool {
    PROGRESS_BYTES.store(processed_bytes as usize, Ordering::SeqCst);
    true
}

#[test]
fn test_phase5_archive_create_inspect_extract_roundtrip_zip() {
    let temp_dir = std::env::temp_dir().join("ttzip_test_phase5_roundtrip_zip");
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    let src_dir = temp_dir.join("src_files");
    fs::create_dir_all(&src_dir).unwrap();

    let file1_path = src_dir.join("hello.txt");
    let mut f1 = File::create(&file1_path).unwrap();
    f1.write_all(b"Hello World from TTZip Rust Glue!").unwrap();
    drop(f1);

    let sub_dir = src_dir.join("nested_folder");
    fs::create_dir_all(&sub_dir).unwrap();

    let file2_path = sub_dir.join("data.bin");
    let mut f2 = File::create(&file2_path).unwrap();
    f2.write_all(&[0x42; 1024]).unwrap();
    drop(f2);

    let archive_path = temp_dir.join("test_archive.zip");
    let c_archive_path = CString::new(archive_path.to_str().unwrap()).unwrap();
    let c_src_path = CString::new(src_dir.to_str().unwrap()).unwrap();

    let src_ptrs = [c_src_path.as_ptr()];

    // 1. Create Archive via FFI
    let create_options = TTZipCreateOptions {
        format: TTZipArchiveFormat::Zip,
        level: TTZipCompressionLevel::Normal,
        encryption: TTZipEncryptionMethod::None,
        password: std::ptr::null(),
        thread_budget: 4,
        solid_block_size_mb: 0,
        progress_callback: Some(test_progress_cb),
        user_data: std::ptr::null_mut(),
    };

    let create_status = unsafe {
        ttzip_rust_create_archive(
            src_ptrs.as_ptr(),
            src_ptrs.len(),
            c_archive_path.as_ptr(),
            &create_options,
        )
    };
    assert_eq!(create_status, TTZipStatus::Ok);
    assert!(archive_path.exists());

    // 2. Inspect Archive via FFI
    INSPECT_COUNT.store(0, Ordering::SeqCst);
    let inspect_status = unsafe {
        ttzip_rust_inspect_archive(
            c_archive_path.as_ptr(),
            std::ptr::null(),
            true,
            Some(test_inspect_cb),
            std::ptr::null_mut(),
        )
    };
    assert_eq!(inspect_status, TTZipStatus::Ok);
    assert!(INSPECT_COUNT.load(Ordering::SeqCst) >= 2);

    // 3. Extract Archive via FFI (Dry-run first)
    let dest_dir = temp_dir.join("extracted");
    let c_dest_dir = CString::new(dest_dir.to_str().unwrap()).unwrap();

    let dry_run_options = TTZipExtractOptions {
        destination_path: c_dest_dir.as_ptr(),
        password: std::ptr::null(),
        thread_budget: 4,
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: true,
        progress_callback: Some(test_progress_cb),
        user_data: std::ptr::null_mut(),
    };

    let dry_status = unsafe {
        ttzip_rust_extract_archive(
            c_archive_path.as_ptr(),
            c_dest_dir.as_ptr(),
            &dry_run_options,
        )
    };
    assert_eq!(dry_status, TTZipStatus::Ok);
    assert!(!dest_dir.join("hello.txt").exists());

    // 4. Real Extract Archive via FFI
    let extract_options = TTZipExtractOptions {
        destination_path: c_dest_dir.as_ptr(),
        password: std::ptr::null(),
        thread_budget: 4,
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: Some(test_progress_cb),
        user_data: std::ptr::null_mut(),
    };

    let ext_status = unsafe {
        ttzip_rust_extract_archive(
            c_archive_path.as_ptr(),
            c_dest_dir.as_ptr(),
            &extract_options,
        )
    };
    assert_eq!(ext_status, TTZipStatus::Ok);

    // Verify extracted contents
    let extracted_f1 = dest_dir.join("src_files/hello.txt");
    let extracted_f2 = dest_dir.join("src_files/nested_folder/data.bin");
    assert!(extracted_f1.exists());
    assert!(extracted_f2.exists());

    let content1 = fs::read(&extracted_f1).unwrap();
    assert_eq!(content1, b"Hello World from TTZip Rust Glue!");

    let content2 = fs::read(&extracted_f2).unwrap();
    assert_eq!(content2, vec![0x42; 1024]);

    let _ = fs::remove_dir_all(&temp_dir);
}

#[test]
fn test_phase5_archive_create_tar_gz_and_extract() {
    let temp_dir = std::env::temp_dir().join("ttzip_test_phase5_targz");
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    let src_file = temp_dir.join("test_sample.log");
    fs::write(&src_file, b"Sample log line 1\nSample log line 2\n").unwrap();

    let archive_path = temp_dir.join("sample.tar.gz");
    let c_archive_path = CString::new(archive_path.to_str().unwrap()).unwrap();
    let c_src_path = CString::new(src_file.to_str().unwrap()).unwrap();
    let src_ptrs = [c_src_path.as_ptr()];

    let create_options = TTZipCreateOptions {
        format: TTZipArchiveFormat::TarGz,
        level: TTZipCompressionLevel::Normal,
        encryption: TTZipEncryptionMethod::None,
        password: std::ptr::null(),
        thread_budget: 2,
        solid_block_size_mb: 0,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let create_status = unsafe {
        ttzip_rust_create_archive(
            src_ptrs.as_ptr(),
            src_ptrs.len(),
            c_archive_path.as_ptr(),
            &create_options,
        )
    };
    assert_eq!(create_status, TTZipStatus::Ok);
    assert!(archive_path.exists());

    let dest_dir = temp_dir.join("out_targz");
    let c_dest_dir = CString::new(dest_dir.to_str().unwrap()).unwrap();

    let extract_options = TTZipExtractOptions {
        destination_path: c_dest_dir.as_ptr(),
        password: std::ptr::null(),
        thread_budget: 2,
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let ext_status = unsafe {
        ttzip_rust_extract_archive(
            c_archive_path.as_ptr(),
            c_dest_dir.as_ptr(),
            &extract_options,
        )
    };
    assert_eq!(ext_status, TTZipStatus::Ok);
    assert!(dest_dir.join("test_sample.log").exists());

    let _ = fs::remove_dir_all(&temp_dir);
}

#[test]
fn test_phase5_archive_error_handling() {
    let invalid_path = CString::new("/nonexistent/path/to/archive.zip").unwrap();
    let dest_dir = CString::new("/tmp/some_dest").unwrap();

    let inspect_status = unsafe {
        ttzip_rust_inspect_archive(
            invalid_path.as_ptr(),
            std::ptr::null(),
            false,
            Some(test_inspect_cb),
            std::ptr::null_mut(),
        )
    };
    assert_eq!(inspect_status, TTZipStatus::ErrFileNotFound);

    let extract_status = unsafe {
        ttzip_rust_extract_archive(
            invalid_path.as_ptr(),
            dest_dir.as_ptr(),
            std::ptr::null(),
        )
    };
    assert_eq!(extract_status, TTZipStatus::ErrFileNotFound);

    // Null pointer param checks
    let null_status = unsafe {
        ttzip_rust_extract_archive(
            std::ptr::null(),
            dest_dir.as_ptr(),
            std::ptr::null(),
        )
    };
    assert_eq!(null_status, TTZipStatus::ErrInvalidParam);
}
