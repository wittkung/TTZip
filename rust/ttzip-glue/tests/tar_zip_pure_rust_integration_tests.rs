// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Integration tests for pure Rust TAR and ZIP C-ABI direct scan and extract entry points.

use std::ffi::{CStr, CString};
use std::fs;
use std::sync::atomic::{AtomicUsize, Ordering};
use ttzip_glue::archive::tar::writer::TarWriter;
use ttzip_glue::ffi::*;
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipEntryMetadata, TTZipStatus,
};
use ttzip_glue::zip::writer::create_zip_archive;

static TAR_SCANNED_COUNT: AtomicUsize = AtomicUsize::new(0);
static ZIP_SCANNED_COUNT: AtomicUsize = AtomicUsize::new(0);

unsafe extern "C" fn tar_scan_cb(
    entry: *const TTZipEntryMetadata,
    _user_data: *mut libc::c_void,
) -> bool {
    if !entry.is_null() {
        let meta = &*entry;
        assert!(!meta.path.is_null());
        let _name = CStr::from_ptr(meta.path).to_str().unwrap();
        TAR_SCANNED_COUNT.fetch_add(1, Ordering::SeqCst);
    }
    true
}

unsafe extern "C" fn zip_scan_cb(
    entry: *const TTZipEntryMetadata,
    _user_data: *mut libc::c_void,
) -> bool {
    if !entry.is_null() {
        let meta = &*entry;
        assert!(!meta.path.is_null());
        let _name = CStr::from_ptr(meta.path).to_str().unwrap();
        ZIP_SCANNED_COUNT.fetch_add(1, Ordering::SeqCst);
    }
    true
}

#[test]
fn test_pure_rust_tar_scan_and_extract_ffi() {
    let temp_dir = std::env::temp_dir().join("ttzip_test_tar_ffi");
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    let tar_path = temp_dir.join("test_archive.tar");
    let file = fs::File::create(&tar_path).unwrap();
    let mut writer = TarWriter::new(file);

    let content1 = b"Hello Pure Rust TAR C-ABI Scanner!";
    let content2 = vec![0x55u8; 2048];
    let long_path = "deeply/nested/directory/path/structure/that/is/designed/to/test/posix/pax/long/path/name/handling/in/tar_scan_ffi.txt";

    writer.append_file("simple.txt", content1, 0o644, 1700000000).unwrap();
    writer.append_file(long_path, &content2, 0o755, 1700000000).unwrap();
    writer.append_dir("empty_folder", 0o755, 1700000000).unwrap();
    writer.finish().unwrap();

    let c_tar_path = CString::new(tar_path.to_str().unwrap()).unwrap();

    // 1. Test ttzip_rust_tar_scan_entries
    TAR_SCANNED_COUNT.store(0, Ordering::SeqCst);
    let status = unsafe {
        ttzip_rust_tar_scan_entries(
            c_tar_path.as_ptr(),
            Some(tar_scan_cb),
            std::ptr::null_mut(),
        )
    };
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(TAR_SCANNED_COUNT.load(Ordering::SeqCst), 3);

    // 2. Test ttzip_rust_tar_extract_entry
    let mut buf = vec![0u8; 4096];
    let mut extracted_len: usize = 0;

    let ext_status = unsafe {
        ttzip_rust_tar_extract_entry(
            c_tar_path.as_ptr(),
            0,
            buf.as_mut_ptr(),
            buf.len(),
            &mut extracted_len,
        )
    };
    assert_eq!(ext_status, TTZipStatus::Ok);
    assert_eq!(extracted_len, content1.len());
    assert_eq!(&buf[..extracted_len], content1);

    // Extract entry 1 (long path file)
    let ext_status2 = unsafe {
        ttzip_rust_tar_extract_entry(
            c_tar_path.as_ptr(),
            1,
            buf.as_mut_ptr(),
            buf.len(),
            &mut extracted_len,
        )
    };
    assert_eq!(ext_status2, TTZipStatus::Ok);
    assert_eq!(extracted_len, content2.len());
    assert_eq!(&buf[..extracted_len], &content2[..]);

    // Test out of bounds index
    let oob_status = unsafe {
        ttzip_rust_tar_extract_entry(
            c_tar_path.as_ptr(),
            99,
            buf.as_mut_ptr(),
            buf.len(),
            &mut extracted_len,
        )
    };
    assert_eq!(oob_status, TTZipStatus::ErrInvalidOffset);

    let _ = fs::remove_dir_all(&temp_dir);
}

#[test]
fn test_pure_rust_zip_scan_entries_ffi() {
    let temp_dir = std::env::temp_dir().join("ttzip_test_zip_scan_ffi");
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    let src_file1 = temp_dir.join("a.txt");
    let src_file2 = temp_dir.join("b.bin");
    fs::write(&src_file1, b"File A").unwrap();
    fs::write(&src_file2, b"File B payload").unwrap();

    let zip_path = temp_dir.join("test_scan.zip");
    let create_opt = TTZipCreateOptions {
        format: TTZipArchiveFormat::Zip,
        level: TTZipCompressionLevel::Fastest,
        encryption: TTZipEncryptionMethod::None,
        password: std::ptr::null(),
        thread_budget: 2,
        solid_block_size_mb: 0,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    create_zip_archive(&zip_path, &[src_file1, src_file2], &create_opt).unwrap();

    let c_zip_path = CString::new(zip_path.to_str().unwrap()).unwrap();

    ZIP_SCANNED_COUNT.store(0, Ordering::SeqCst);
    let status = unsafe {
        ttzip_rust_zip_scan_entries(
            c_zip_path.as_ptr(),
            Some(zip_scan_cb),
            std::ptr::null_mut(),
        )
    };
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(ZIP_SCANNED_COUNT.load(Ordering::SeqCst), 2);

    let _ = fs::remove_dir_all(&temp_dir);
}
