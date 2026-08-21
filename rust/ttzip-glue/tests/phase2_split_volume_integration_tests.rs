// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Phase 2 Integration Tests: Multi-Volume Split Container & Virtual Continuous Reader.

use libc::{c_char, c_void};
use std::ffi::{CStr, CString};
use std::fs;
use tempfile::tempdir;
use ttzip_glue::archive::split::VolumeNamingScheme;
use ttzip_glue::ffi::archive_ffi::split::*;
use ttzip_glue::types::TTZipStatus;

unsafe extern "C" fn test_progress_cb(
    _processed: u64,
    _total: u64,
    _entry: *const c_char,
    user_data: *mut c_void,
) -> bool {
    if !user_data.is_null() {
        let counter = &mut *(user_data as *mut usize);
        *counter += 1;
    }
    true
}

#[test]
fn test_split_writer_and_reader_ffi_roundtrip() {
    let dir = tempdir().unwrap();
    let base_archive = dir.path().join("split_test.7z");
    let c_base = CString::new(base_archive.to_str().unwrap()).unwrap();
    let volume_size: u64 = 65536; // 64 KB

    unsafe {
        let writer = ttzip_rust_split_writer_new(
            c_base.as_ptr(),
            volume_size,
            VolumeNamingScheme::NumberedExtension as i32,
            true,
        );
        assert!(!writer.is_null());

        // 180 KB payload -> 3 volumes (64KB, 64KB, 52KB)
        let payload: Vec<u8> = (0..184320).map(|i| (i % 251) as u8).collect();
        let write_res = ttzip_rust_split_writer_write(writer, payload.as_ptr(), payload.len());
        assert_eq!(write_res, 0);

        let total_bytes = ttzip_rust_split_writer_get_total_bytes(writer);
        assert_eq!(total_bytes, 184320);

        let close_status = ttzip_rust_split_writer_close(writer);
        assert_eq!(close_status, TTZipStatus::Ok);

        let vol_count = ttzip_rust_split_writer_get_volume_count(writer);
        assert_eq!(vol_count, 3);

        let mut buf = [0 as c_char; 1024];
        let p_res = ttzip_rust_split_writer_get_volume_path(writer, 0, buf.as_mut_ptr(), buf.len());
        assert_eq!(p_res, TTZipStatus::Ok);
        let path0 = CStr::from_ptr(buf.as_ptr()).to_str().unwrap();
        assert!(path0.ends_with(".001"));

        ttzip_rust_split_writer_free(writer);

        // Open reader from volume 2 (middle of chain) to verify auto-topology discovery
        let vol2_path = format!("{}.002", base_archive.to_str().unwrap());
        let c_vol2 = CString::new(vol2_path).unwrap();

        let reader = ttzip_rust_split_reader_open(c_vol2.as_ptr());
        assert!(!reader.is_null());

        let total_size = ttzip_rust_split_reader_get_total_size(reader);
        assert_eq!(total_size, 184320);

        let reader_vol_count = ttzip_rust_split_reader_get_volume_count(reader);
        assert_eq!(reader_vol_count, 3);

        // Read back all bytes across volume boundaries
        let mut read_data = vec![0u8; 184320];
        let mut bytes_read: usize = 0;
        let read_status = ttzip_rust_split_reader_read(
            reader,
            read_data.as_mut_ptr(),
            read_data.len(),
            &mut bytes_read,
        );
        assert_eq!(read_status, TTZipStatus::Ok);
        assert_eq!(bytes_read, 184320);
        assert_eq!(read_data, payload);

        // Test seek
        let mut new_offset: u64 = 0;
        let seek_status = ttzip_rust_split_reader_seek(reader, 70000, 0, &mut new_offset);
        assert_eq!(seek_status, TTZipStatus::Ok);
        assert_eq!(new_offset, 70000);

        let mut chunk = [0u8; 100];
        let mut chunk_read = 0;
        let chunk_status = ttzip_rust_split_reader_read(
            reader,
            chunk.as_mut_ptr(),
            chunk.len(),
            &mut chunk_read,
        );
        assert_eq!(chunk_status, TTZipStatus::Ok);
        assert_eq!(chunk_read, 100);
        assert_eq!(&chunk[..], &payload[70000..70100]);

        ttzip_rust_split_reader_free(reader);
    }
}

#[test]
fn test_split_file_and_join_volumes_ffi() {
    let dir = tempdir().unwrap();
    let src_file = dir.path().join("original_payload.bin");
    let split_base = dir.path().join("split_archive.dat");
    let reassembled_file = dir.path().join("reassembled_payload.bin");

    let test_data: Vec<u8> = (0..150000).map(|i| (i * 37 % 256) as u8).collect();
    fs::write(&src_file, &test_data).unwrap();

    let c_src = CString::new(src_file.to_str().unwrap()).unwrap();
    let c_dst_base = CString::new(split_base.to_str().unwrap()).unwrap();
    let c_reass = CString::new(reassembled_file.to_str().unwrap()).unwrap();

    unsafe {
        let split_status = ttzip_rust_split_file(
            c_src.as_ptr(),
            c_dst_base.as_ptr(),
            65536,
            VolumeNamingScheme::NumberedExtension as i32,
            true,
        );
        assert_eq!(split_status, TTZipStatus::Ok);

        let part1 = format!("{}.001", split_base.to_str().unwrap());
        let part2 = format!("{}.002", split_base.to_str().unwrap());
        let part3 = format!("{}.003", split_base.to_str().unwrap());
        assert!(fs::metadata(&part1).is_ok());
        assert!(fs::metadata(&part2).is_ok());
        assert!(fs::metadata(&part3).is_ok());

        let mut progress_count: usize = 0;
        let c_part1 = CString::new(part1).unwrap();
        let join_status = ttzip_rust_join_split_volumes(
            c_part1.as_ptr(),
            c_reass.as_ptr(),
            Some(test_progress_cb),
            &mut progress_count as *mut usize as *mut c_void,
        );
        assert_eq!(join_status, TTZipStatus::Ok);
        assert!(progress_count > 0);

        let reassembled_data = fs::read(&reassembled_file).unwrap();
        assert_eq!(reassembled_data, test_data);
    }
}

#[test]
fn test_pkzip_spanned_ffi_roundtrip() {
    let dir = tempdir().unwrap();
    let src_file = dir.path().join("document.zip");
    let split_base = dir.path().join("document.zip");

    let test_data: Vec<u8> = (0..140000).map(|i| (i ^ 0x5A) as u8).collect();
    fs::write(&src_file, &test_data).unwrap();

    let c_src = CString::new(src_file.to_str().unwrap()).unwrap();
    let c_dst_base = CString::new(split_base.to_str().unwrap()).unwrap();

    unsafe {
        let split_status = ttzip_rust_split_file(
            c_src.as_ptr(),
            c_dst_base.as_ptr(),
            65536,
            VolumeNamingScheme::PkzipSpanned as i32,
            true,
        );
        assert_eq!(split_status, TTZipStatus::Ok);

        let parent_dir = dir.path();
        assert!(parent_dir.join("document.z01").exists());
        assert!(parent_dir.join("document.z02").exists());
        assert!(parent_dir.join("document.zip").exists());

        // Probe chain from the final .zip file
        let final_zip = parent_dir.join("document.zip");
        let c_final_zip = CString::new(final_zip.to_str().unwrap()).unwrap();
        let reader = ttzip_rust_split_reader_open(c_final_zip.as_ptr());
        assert!(!reader.is_null());

        let total_size = ttzip_rust_split_reader_get_total_size(reader);
        assert_eq!(total_size, 140000);
        let vol_count = ttzip_rust_split_reader_get_volume_count(reader);
        assert_eq!(vol_count, 3);

        let mut read_data = vec![0u8; 140000];
        let mut bytes_read: usize = 0;
        let read_status = ttzip_rust_split_reader_read(
            reader,
            read_data.as_mut_ptr(),
            read_data.len(),
            &mut bytes_read,
        );
        assert_eq!(read_status, TTZipStatus::Ok);
        assert_eq!(bytes_read, 140000);
        assert_eq!(read_data, test_data);

        ttzip_rust_split_reader_free(reader);
    }
}
