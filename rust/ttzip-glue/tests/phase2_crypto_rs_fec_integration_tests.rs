// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Integration tests for ZipCrypto, Reed-Solomon FEC, and Self-Healing Recovery Records.

use std::ffi::CString;
use std::time::Instant;
use tempfile::tempdir;
use ttzip_glue::crypto::rs_fec::gf8::gf8_mul_add_slice;
use ttzip_glue::crypto::zipcrypto::ZipCryptoKeys;
use ttzip_glue::ffi::{
    ttzip_rust_rs_append_recovery_record_file, ttzip_rust_rs_create_recovery_record,
    ttzip_rust_rs_decode, ttzip_rust_rs_encode, ttzip_rust_rs_free_buffer,
    ttzip_rust_rs_inspect_recovery_record_file, ttzip_rust_rs_repair_archive,
    ttzip_rust_rs_repair_archive_streaming, ttzip_rust_zipcrypto_decrypt_stream,
    ttzip_rust_zipcrypto_encrypt_stream, ttzip_rust_zipcrypto_init_keys,
};
use ttzip_glue::types::TTZipStatus;
use zeroize::Zeroize;

#[test]
fn test_zipcrypto_ffi_stream_crypt_roundtrip() {
    let password = CString::new("SecureZipPass2026!").unwrap();
    let mut key0 = 0u32;
    let mut key1 = 0u32;
    let mut key2 = 0u32;

    let init_res = unsafe {
        ttzip_rust_zipcrypto_init_keys(password.as_ptr(), &mut key0, &mut key1, &mut key2)
    };
    assert_eq!(init_res, TTZipStatus::Ok.to_i32());
    assert_ne!(key0, 0);

    let original = b"High-performance native archiving and compression engine for macOS TTZip!";
    let mut encrypted = vec![0u8; original.len()];
    let mut decrypted = vec![0u8; original.len()];

    let mut enc_k0 = key0;
    let mut enc_k1 = key1;
    let mut enc_k2 = key2;
    let enc_res = unsafe {
        ttzip_rust_zipcrypto_encrypt_stream(
            &mut enc_k0,
            &mut enc_k1,
            &mut enc_k2,
            original.as_ptr(),
            original.len(),
            encrypted.as_mut_ptr(),
        )
    };
    assert_eq!(enc_res, TTZipStatus::Ok.to_i32());
    assert_ne!(&encrypted[..], &original[..]);

    let mut dec_k0 = key0;
    let mut dec_k1 = key1;
    let mut dec_k2 = key2;
    let dec_res = unsafe {
        ttzip_rust_zipcrypto_decrypt_stream(
            &mut dec_k0,
            &mut dec_k1,
            &mut dec_k2,
            encrypted.as_ptr(),
            encrypted.len(),
            decrypted.as_mut_ptr(),
        )
    };
    assert_eq!(dec_res, TTZipStatus::Ok.to_i32());
    assert_eq!(&decrypted[..], &original[..]);
}

#[test]
fn test_zipcrypto_keys_zeroize() {
    let mut keys = ZipCryptoKeys::from_password(b"ZeroizeTestPassword");
    assert_ne!(keys.key0, 0);
    assert_ne!(keys.key1, 0);
    assert_ne!(keys.key2, 0);

    keys.zeroize();
    assert_eq!(keys.key0, 0);
    assert_eq!(keys.key1, 0);
    assert_eq!(keys.key2, 0);
}

#[test]
fn test_rs_encode_decode_ffi_roundtrip() {
    let k_data = 6;
    let m_parity = 3;
    let block_size = 512;

    let data_bufs: Vec<Vec<u8>> = (0..k_data)
        .map(|i| (0..block_size).map(|b| ((b * 13 + i * 29) & 0xFF) as u8).collect())
        .collect();
    let mut parity_bufs: Vec<Vec<u8>> = vec![vec![0u8; block_size]; m_parity];

    let data_ptrs: Vec<*const u8> = data_bufs.iter().map(|b| b.as_ptr()).collect();
    let mut parity_ptrs: Vec<*mut u8> = parity_bufs.iter_mut().map(|b| b.as_mut_ptr()).collect();

    let enc_status = unsafe {
        ttzip_rust_rs_encode(
            data_ptrs.as_ptr(),
            k_data,
            parity_ptrs.as_mut_ptr(),
            m_parity,
            block_size,
        )
    };
    assert_eq!(enc_status, TTZipStatus::Ok.to_i32());

    // Corrupt / drop data shards 1 and 4. Use parities 0 and 2.
    // Available: data 0, 2, 3, 5 and parities 0, 2 (total 6 shards)
    let available_ptrs: Vec<*const u8> = vec![
        data_bufs[0].as_ptr(),
        data_bufs[2].as_ptr(),
        data_bufs[3].as_ptr(),
        data_bufs[5].as_ptr(),
        parity_bufs[0].as_ptr(),
        parity_bufs[2].as_ptr(),
    ];
    let available_indices: Vec<i32> = vec![0, 2, 3, 5, k_data as i32, (k_data + 2) as i32];
    let missing_indices: Vec<i32> = vec![1, 4];

    let mut recon1 = vec![0u8; block_size];
    let mut recon4 = vec![0u8; block_size];
    let mut recon_ptrs: Vec<*mut u8> = vec![recon1.as_mut_ptr(), recon4.as_mut_ptr()];

    let dec_status = unsafe {
        ttzip_rust_rs_decode(
            available_ptrs.as_ptr(),
            available_indices.as_ptr(),
            available_ptrs.len(),
            k_data,
            m_parity,
            missing_indices.as_ptr(),
            missing_indices.len(),
            recon_ptrs.as_mut_ptr(),
            block_size,
        )
    };
    assert_eq!(dec_status, TTZipStatus::Ok.to_i32());
    assert_eq!(recon1, data_bufs[1]);
    assert_eq!(recon4, data_bufs[4]);
}

#[test]
fn test_rs_recovery_record_ffi_create_and_repair() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("archive.tar");
    let original_payload: Vec<u8> = (0..64 * 1024)
        .map(|i| ((i * 31 + 7) & 0xFF) as u8)
        .collect();

    std::fs::write(&file_path, &original_payload).unwrap();

    let mut out_rec_ptr: *mut u8 = std::ptr::null_mut();
    let mut out_rec_len: usize = 0;

    let create_res = unsafe {
        ttzip_rust_rs_create_recovery_record(
            original_payload.as_ptr(),
            original_payload.len(),
            15.0,
            8192,
            &mut out_rec_ptr,
            &mut out_rec_len,
        )
    };
    assert_eq!(create_res, TTZipStatus::Ok.to_i32());
    assert!(!out_rec_ptr.is_null());
    assert!(out_rec_len > 0);

    let rec_bytes = unsafe { std::slice::from_raw_parts(out_rec_ptr, out_rec_len) };

    // Append to file
    let mut file_content = original_payload.clone();
    file_content.extend_from_slice(rec_bytes);
    std::fs::write(&file_path, &file_content).unwrap();

    unsafe {
        ttzip_rust_rs_free_buffer(out_rec_ptr, out_rec_len);
    }

    // Corrupt 200 bytes in shard 2
    let mut corrupted = std::fs::read(&file_path).unwrap();
    let corrupt_offset = 2 * 8192 + 50;
    for i in 0..200 {
        corrupted[corrupt_offset + i] ^= 0xFF;
    }
    std::fs::write(&file_path, &corrupted).unwrap();

    // Repair archive via FFI
    let c_path = CString::new(file_path.to_str().unwrap()).unwrap();
    let mut repaired = false;
    let repair_res = unsafe { ttzip_rust_rs_repair_archive(c_path.as_ptr(), &mut repaired) };
    assert_eq!(repair_res, TTZipStatus::Ok.to_i32());
    assert!(repaired, "Archive should be repaired successfully");

    let restored = std::fs::read(&file_path).unwrap();
    assert_eq!(&restored[..original_payload.len()], &original_payload[..]);
}

#[test]
fn test_rs_recovery_record_streaming_file_ffi_roundtrip() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("archive_streaming.tar");
    let original_payload: Vec<u8> = (0..128 * 1024)
        .map(|i| ((i * 17 + 13) & 0xFF) as u8)
        .collect();

    std::fs::write(&file_path, &original_payload).unwrap();

    let c_path = CString::new(file_path.to_str().unwrap()).unwrap();
    let mut data_slices = 0usize;
    let mut parity_slices = 0usize;
    let mut protected_len = 0u64;
    let mut root_hash = [0u8; 32];

    let append_status = unsafe {
        ttzip_rust_rs_append_recovery_record_file(
            c_path.as_ptr(),
            25.0,
            16384,
            &mut data_slices,
            &mut parity_slices,
            &mut protected_len,
            root_hash.as_mut_ptr(),
        )
    };
    assert_eq!(append_status, TTZipStatus::Ok.to_i32());
    assert_eq!(data_slices, 8);
    assert_eq!(parity_slices, 2);
    assert_eq!(protected_len, original_payload.len() as u64);

    // Inspect via FFI
    let mut ins_slice_size = 0usize;
    let mut ins_k = 0usize;
    let mut ins_m = 0usize;
    let mut ins_len = 0u64;
    let mut ins_hash = [0u8; 32];
    let mut ins_has_record = false;

    let ins_status = unsafe {
        ttzip_rust_rs_inspect_recovery_record_file(
            c_path.as_ptr(),
            &mut ins_slice_size,
            &mut ins_k,
            &mut ins_m,
            &mut ins_len,
            ins_hash.as_mut_ptr(),
            &mut ins_has_record,
        )
    };
    assert_eq!(ins_status, TTZipStatus::Ok.to_i32());
    assert!(ins_has_record);
    assert_eq!(ins_slice_size, 16384);
    assert_eq!(ins_k, 8);
    assert_eq!(ins_m, 2);
    assert_eq!(ins_hash, root_hash);

    // Corrupt shard 3 and shard 7
    let mut damaged = std::fs::read(&file_path).unwrap();
    for i in 0..300 {
        damaged[3 * 16384 + i] ^= 0xCC;
        damaged[7 * 16384 + i] ^= 0x33;
    }
    std::fs::write(&file_path, &damaged).unwrap();

    // Repair via streaming FFI
    let mut repaired = false;
    let repair_status =
        unsafe { ttzip_rust_rs_repair_archive_streaming(c_path.as_ptr(), &mut repaired) };
    assert_eq!(repair_status, TTZipStatus::Ok.to_i32());
    assert!(repaired, "Streaming in-place repair must succeed");

    let restored = std::fs::read(&file_path).unwrap();
    assert_eq!(&restored[..original_payload.len()], &original_payload[..]);
}

#[test]
fn test_gf8_neon_simd_throughput_benchmark() {
    let size = 8 * 1024 * 1024; // 8 MB
    let src = vec![0xABu8; size];
    let mut dst = vec![0u8; size];
    let coeff = 42u8;

    let iters = 50;
    let start = Instant::now();
    for _ in 0..iters {
        gf8_mul_add_slice(coeff, &src, &mut dst);
    }
    let dur = start.elapsed();
    let gb = (size as f64 * iters as f64) / (1024.0 * 1024.0 * 1024.0);
    let speed = gb / dur.as_secs_f64();
    println!("GF(2^8) NEON SIMD Throughput: {:.2} GB/s", speed);
    assert!(speed > 1.0, "Throughput must be at least 1 GB/s");
}
