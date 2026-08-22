// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Phase 4 Integration Tests: VFS LZ4 Cache Pool, In-Memory Password Recovery & Archive Self-Healing Repair.

use std::ffi::{CStr, CString};
use std::fs;
use ttzip_glue::archive::tar::writer::TarWriter;
use ttzip_glue::crypto::sha1::winzip_aes256_derive_keys;
use ttzip_glue::crypto::zipcrypto::ZipCryptoKeys;
use ttzip_glue::ffi::archive_ffi::*;
use ttzip_glue::ffi::crypto_ffi::*;
use ttzip_glue::ffi::vfs_ffi::*;
use ttzip_glue::types::TTZipStatus;
use ttzip_glue::zip::writer::{assemble_zip_archive, ZipCompressedItem};

#[test]
fn test_vfs_lz4_cache_pool_ffi_lifecycle_and_spill() {
    let temp_spill = std::env::temp_dir().join("ttzip_vfs_test_spill");
    let _ = fs::remove_dir_all(&temp_spill);
    let c_spill = CString::new(temp_spill.to_str().unwrap()).unwrap();

    let handle = unsafe { ttzip_rust_vfs_cache_new(1024 * 1024, c_spill.as_ptr()) };
    assert!(!handle.is_null());

    let c_sess = CString::new("session_101").unwrap();
    let raw_chunk = b"High speed LZ4 decompression buffer caching across 16 shards in TTZip.";

    let put_status = unsafe {
        ttzip_rust_vfs_cache_put(
            handle,
            c_sess.as_ptr(),
            0,
            raw_chunk.as_ptr(),
            raw_chunk.len(),
            1,
        )
    };
    assert_eq!(put_status, TTZipStatus::Ok);

    let mut out_buf = vec![0u8; 512];
    let mut out_len = 0usize;

    let get_status = unsafe {
        ttzip_rust_vfs_cache_get(
            handle,
            c_sess.as_ptr(),
            0,
            out_buf.as_mut_ptr(),
            out_buf.len(),
            &mut out_len,
        )
    };
    assert_eq!(get_status, TTZipStatus::Ok);
    assert_eq!(out_len, raw_chunk.len());
    assert_eq!(&out_buf[..out_len], raw_chunk);

    let mut ram_cnt = 0;
    let mut disk_cnt = 0;
    let mut ram_bytes = 0;
    unsafe {
        ttzip_rust_vfs_cache_get_stats(handle, &mut ram_cnt, &mut disk_cnt, &mut ram_bytes);
    }
    assert_eq!(ram_cnt, 1);
    assert_eq!(disk_cnt, 0);

    let clear_status = unsafe { ttzip_rust_vfs_cache_clear_session(handle, c_sess.as_ptr()) };
    assert_eq!(clear_status, TTZipStatus::Ok);

    unsafe {
        ttzip_rust_vfs_cache_free(handle);
    }
    let _ = fs::remove_dir_all(&temp_spill);
}

#[test]
fn test_crypto_password_recovery_ffi_zipcrypto_and_winzip() {
    // 1. ZipCrypto 12-byte header verification
    let correct_zip_pwd = "ZipPassword2026";
    let mut keys = ZipCryptoKeys::from_password(correct_zip_pwd.as_bytes());
    let mut enc_header = [0u8; 12];
    let plain_hdr = [1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x88];
    for i in 0..12 {
        enc_header[i] = keys.encrypt_byte(plain_hdr[i]);
    }

    let dict = [CString::new("123456").unwrap(),
        CString::new("admin").unwrap(),
        CString::new("ZipPassword2026").unwrap(),
        CString::new("guest").unwrap()];
    let dict_ptrs: Vec<*const libc::c_char> = dict.iter().map(|s| s.as_ptr()).collect();

    let mut out_found = vec![0u8; 64];
    let found = unsafe {
        ttzip_rust_crypto_recover_zipcrypto(
            dict_ptrs.as_ptr(),
            dict_ptrs.len(),
            enc_header.as_ptr(),
            0x88,
            out_found.as_mut_ptr() as *mut libc::c_char,
            out_found.len(),
        )
    };
    assert!(found);
    let found_str = unsafe { CStr::from_ptr(out_found.as_ptr() as *const libc::c_char) }
        .to_str()
        .unwrap();
    assert_eq!(found_str, correct_zip_pwd);

    // 2. WinZip AES-256 PVV verification
    let correct_aes_pwd = "AesVaultPass2026";
    let salt = [0x55u8; 16];
    let aes_keys = winzip_aes256_derive_keys(correct_aes_pwd, &salt).unwrap();

    let dict_aes = [CString::new("password").unwrap(),
        CString::new("AesVaultPass2026").unwrap()];
    let dict_aes_ptrs: Vec<*const libc::c_char> = dict_aes.iter().map(|s| s.as_ptr()).collect();

    let mut out_aes = vec![0u8; 64];
    let found_aes = unsafe {
        ttzip_rust_crypto_recover_winzip_aes(
            dict_aes_ptrs.as_ptr(),
            dict_aes_ptrs.len(),
            salt.as_ptr(),
            aes_keys.pvv.as_ptr(),
            out_aes.as_mut_ptr() as *mut libc::c_char,
            out_aes.len(),
        )
    };
    assert!(found_aes);
    let found_aes_str = unsafe { CStr::from_ptr(out_aes.as_ptr() as *const libc::c_char) }
        .to_str()
        .unwrap();
    assert_eq!(found_aes_str, correct_aes_pwd);
}

#[test]
fn test_archive_repair_zip_and_tar_ffi() {
    let temp_dir = std::env::temp_dir().join("ttzip_repair_ffi_test");
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    // 1. Corrupted ZIP Repair
    let zip_item = ZipCompressedItem {
        rel_path: "salvaged_doc.txt".to_string(),
        uncompressed_size: 14,
        compressed_size: 14,
        crc32: 0x99887766,
        compression_method: 0,
        actual_method: 0,
        aes_strength: 0,
        payload: b"Salvaged Data!".to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
        is_encrypted: false,
    };
    let full_zip = assemble_zip_archive(&[zip_item]).unwrap();
    let truncated_zip = &full_zip[..30 + 16 + 14]; // Truncated ZIP without Central Directory

    let damaged_zip_path = temp_dir.join("damaged.zip");
    let repaired_zip_path = temp_dir.join("repaired.zip");
    fs::write(&damaged_zip_path, truncated_zip).unwrap();

    let c_damaged = CString::new(damaged_zip_path.to_str().unwrap()).unwrap();
    let c_repaired = CString::new(repaired_zip_path.to_str().unwrap()).unwrap();
    let mut salvaged_count = 0usize;

    let rep_status = unsafe {
        ttzip_rust_archive_repair_zip(
            c_damaged.as_ptr(),
            c_repaired.as_ptr(),
            &mut salvaged_count,
        )
    };
    assert_eq!(rep_status, TTZipStatus::Ok);
    assert_eq!(salvaged_count, 1);
    assert!(repaired_zip_path.exists());

    // 2. Corrupted TAR Repair
    let damaged_tar_path = temp_dir.join("damaged.tar");
    let repaired_tar_path = temp_dir.join("repaired.tar");
    let tar_file = fs::File::create(&damaged_tar_path).unwrap();
    let mut tar_writer = TarWriter::new(tar_file);
    tar_writer.append_file("tar_file.bin", b"Tar payload content", 0o644, 1700000000).unwrap();
    tar_writer.finish().unwrap();

    let c_damaged_tar = CString::new(damaged_tar_path.to_str().unwrap()).unwrap();
    let c_repaired_tar = CString::new(repaired_tar_path.to_str().unwrap()).unwrap();
    let mut tar_salvaged = 0usize;

    let tar_status = unsafe {
        ttzip_rust_archive_repair_tar(
            c_damaged_tar.as_ptr(),
            c_repaired_tar.as_ptr(),
            &mut tar_salvaged,
        )
    };
    assert_eq!(tar_status, TTZipStatus::Ok);
    assert_eq!(tar_salvaged, 1);
    assert!(repaired_tar_path.exists());

    let _ = fs::remove_dir_all(&temp_dir);
}
