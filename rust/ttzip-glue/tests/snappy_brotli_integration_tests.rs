// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Integration tests for Pure Rust Google Snappy Framing & Google Brotli Streaming codecs.

use std::fs::File;
use std::io::Write;
use tempfile::tempdir;
use ttzip_glue::*;

#[test]
fn test_snappy_pure_rust_framing_ffi_roundtrip() {
    let payload = b"Antigravity Pure Rust Snappy Framing (.sz) standard Castagnoli CRC-32C verification test payload. "
        .repeat(50);

    // 1. Snappy Framing in-memory encode & decode
    let bound = ttzip_rust_snappy_frame_max_encoded_length(payload.len());
    let mut framed_buf = vec![0u8; bound];
    let mut framed_len = 0;
    let status = ttzip_rust_snappy_frame_encode(
        payload.as_ptr(),
        payload.len(),
        framed_buf.as_mut_ptr(),
        framed_buf.len(),
        &mut framed_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(framed_len > 0);
    assert!(ttzip_rust_snappy_is_framed(framed_buf.as_ptr(), framed_len));

    let mut decomp_buf = vec![0u8; payload.len() + 1024];
    let mut decomp_len = 0;
    let status = ttzip_rust_snappy_frame_decode(
        framed_buf.as_ptr(),
        framed_len,
        decomp_buf.as_mut_ptr(),
        decomp_buf.len(),
        &mut decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(decomp_len, payload.len());
    assert_eq!(&decomp_buf[..decomp_len], &payload[..]);
}

#[test]
fn test_snappy_streaming_file_pipe() {
    let dir = tempdir().unwrap();
    let src_path = dir.path().join("snappy_raw.dat");
    let sz_path = dir.path().join("snappy_raw.dat.sz");
    let restored_path = dir.path().join("snappy_restored.dat");

    let payload = vec![0xA5u8; 3 * 1024 * 1024]; // 3MB
    {
        let mut f = File::create(&src_path).unwrap();
        f.write_all(&payload).unwrap();
    }

    let src_c = std::ffi::CString::new(src_path.to_str().unwrap()).unwrap();
    let sz_c = std::ffi::CString::new(sz_path.to_str().unwrap()).unwrap();
    let res_c = std::ffi::CString::new(restored_path.to_str().unwrap()).unwrap();

    let c_status = unsafe {
        ttzip_rust_snappy_compress_file_stream(
            src_c.as_ptr(),
            sz_c.as_ptr(),
            None,
            std::ptr::null_mut(),
        )
    };
    assert_eq!(c_status, TTZipStatus::Ok);

    let d_status = unsafe {
        ttzip_rust_snappy_decompress_file_stream(
            sz_c.as_ptr(),
            res_c.as_ptr(),
            None,
            std::ptr::null_mut(),
        )
    };
    assert_eq!(d_status, TTZipStatus::Ok);

    let restored_bytes = std::fs::read(&restored_path).unwrap();
    assert_eq!(restored_bytes, payload);
}

#[test]
fn test_brotli_pure_rust_streaming_ffi_roundtrip() {
    let payload = b"Google Brotli Pure Rust streaming codec validation with multi-block test payload. "
        .repeat(60);

    // 1. One-shot buffer compress / decompress
    let bound = ttzip_rust_brotli_compress_bound(payload.len());
    let mut comp_buf = vec![0u8; bound];
    let mut comp_len = 0;
    let status = ttzip_rust_brotli_compress(
        payload.as_ptr(),
        payload.len(),
        comp_buf.as_mut_ptr(),
        comp_buf.len(),
        6,
        22,
        &mut comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(comp_len > 0);

    let mut decomp_buf = vec![0u8; payload.len()];
    let mut decomp_len = 0;
    let status = ttzip_rust_brotli_decompress(
        comp_buf.as_ptr(),
        comp_len,
        decomp_buf.as_mut_ptr(),
        decomp_buf.len(),
        &mut decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(decomp_len, payload.len());
    assert_eq!(&decomp_buf[..decomp_len], &payload[..]);
}

#[test]
fn test_brotli_streaming_file_pipe() {
    let dir = tempdir().unwrap();
    let src_path = dir.path().join("brotli_raw.txt");
    let br_path = dir.path().join("brotli_raw.txt.br");
    let restored_path = dir.path().join("brotli_restored.txt");

    let payload = b"Brotli multi-megabyte file compression streaming test with 4MB chunk buffer boundary.\n"
        .repeat(50000); // ~4.3MB
    {
        let mut f = File::create(&src_path).unwrap();
        f.write_all(&payload).unwrap();
    }

    let src_c = std::ffi::CString::new(src_path.to_str().unwrap()).unwrap();
    let br_c = std::ffi::CString::new(br_path.to_str().unwrap()).unwrap();
    let res_c = std::ffi::CString::new(restored_path.to_str().unwrap()).unwrap();

    let c_status = unsafe {
        ttzip_rust_brotli_compress_file_stream(
            src_c.as_ptr(),
            br_c.as_ptr(),
            5,
            22,
            None,
            std::ptr::null_mut(),
        )
    };
    assert_eq!(c_status, TTZipStatus::Ok);

    let d_status = unsafe {
        ttzip_rust_brotli_decompress_file_stream(
            br_c.as_ptr(),
            res_c.as_ptr(),
            None,
            std::ptr::null_mut(),
        )
    };
    assert_eq!(d_status, TTZipStatus::Ok);

    let restored_bytes = std::fs::read(&restored_path).unwrap();
    assert_eq!(restored_bytes, payload);
}
