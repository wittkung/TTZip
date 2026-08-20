// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Integration tests and C-ABI validation for TTZip single-format codecs (Phase 3).

use std::ffi::CStr;
use std::thread;
use ttzip_glue::*;

#[test]
fn test_deflate_zlib_gzip_ffi_roundtrip() {
    let payload = b"Antigravity TTZip DEFLATE / zlib / gzip Safe Rust C-ABI test payload with high repetition. "
        .repeat(50);

    // 1. Raw DEFLATE C-ABI
    let mut comp_buf = vec![0u8; ttzip_rust_deflate_compress_bound(payload.len(), 6)];
    let mut comp_len = 0;
    let status = ttzip_rust_deflate_compress(
        payload.as_ptr(),
        payload.len(),
        comp_buf.as_mut_ptr(),
        comp_buf.len(),
        6,
        &mut comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(comp_len > 0);

    let mut decomp_buf = vec![0u8; payload.len()];
    let mut decomp_len = 0;
    let status = ttzip_rust_deflate_decompress(
        comp_buf.as_ptr(),
        comp_len,
        decomp_buf.as_mut_ptr(),
        decomp_buf.len(),
        &mut decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(decomp_len, payload.len());
    assert_eq!(&decomp_buf[..decomp_len], &payload[..]);

    // 2. zlib C-ABI
    let mut zlib_comp_buf = vec![0u8; payload.len() + 1024];
    let mut zlib_comp_len = 0;
    let status = ttzip_rust_zlib_compress(
        payload.as_ptr(),
        payload.len(),
        zlib_comp_buf.as_mut_ptr(),
        zlib_comp_buf.len(),
        9,
        &mut zlib_comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(zlib_comp_len > 0);

    let mut zlib_decomp_buf = vec![0u8; payload.len()];
    let mut zlib_decomp_len = 0;
    let status = ttzip_rust_zlib_decompress(
        zlib_comp_buf.as_ptr(),
        zlib_comp_len,
        zlib_decomp_buf.as_mut_ptr(),
        zlib_decomp_buf.len(),
        &mut zlib_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(zlib_decomp_len, payload.len());
    assert_eq!(&zlib_decomp_buf[..zlib_decomp_len], &payload[..]);

    // 3. gzip C-ABI
    let mut gzip_comp_buf = vec![0u8; payload.len() + 1024];
    let mut gzip_comp_len = 0;
    let status = ttzip_rust_gzip_compress(
        payload.as_ptr(),
        payload.len(),
        gzip_comp_buf.as_mut_ptr(),
        gzip_comp_buf.len(),
        6,
        &mut gzip_comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(gzip_comp_len > 0);

    let mut gzip_decomp_buf = vec![0u8; payload.len()];
    let mut gzip_decomp_len = 0;
    let status = ttzip_rust_gzip_decompress(
        gzip_comp_buf.as_ptr(),
        gzip_comp_len,
        gzip_decomp_buf.as_mut_ptr(),
        gzip_decomp_buf.len(),
        &mut gzip_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(gzip_decomp_len, payload.len());
    assert_eq!(&gzip_decomp_buf[..gzip_decomp_len], &payload[..]);
}

#[test]
fn test_zstd_ffi_and_advanced_roundtrip() {
    let payload = b"Zstandard ultra-fast parallel compression test with workers and Long Distance Matching (LDM). "
        .repeat(200);

    // 1. Basic ZSTD
    let mut comp_buf = vec![0u8; ttzip_rust_zstd_compress_bound(payload.len())];
    let mut comp_len = 0;
    let status = ttzip_rust_zstd_compress(
        payload.as_ptr(),
        payload.len(),
        comp_buf.as_mut_ptr(),
        comp_buf.len(),
        3,
        &mut comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(comp_len > 0);

    let content_size = ttzip_rust_zstd_get_decompressed_size(comp_buf.as_ptr(), comp_len);
    assert_eq!(content_size, payload.len() as u64);

    let mut decomp_buf = vec![0u8; payload.len()];
    let mut decomp_len = 0;
    let status = ttzip_rust_zstd_decompress(
        comp_buf.as_ptr(),
        comp_len,
        decomp_buf.as_mut_ptr(),
        decomp_buf.len(),
        &mut decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(decomp_len, payload.len());
    assert_eq!(&decomp_buf[..decomp_len], &payload[..]);

    // 2. Advanced Multi-threaded ZSTD with LDM
    let mut adv_comp_buf = vec![0u8; ttzip_rust_zstd_compress_bound(payload.len())];
    let mut adv_comp_len = 0;
    let status = ttzip_rust_zstd_compress_advanced(
        payload.as_ptr(),
        payload.len(),
        adv_comp_buf.as_mut_ptr(),
        adv_comp_buf.len(),
        6,
        2,  // nb_workers
        1,  // job_size_mb
        2,  // overlap_log
        20, // window_log
        true, // enable_ldm
        &mut adv_comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(adv_comp_len > 0);

    let mut adv_decomp_buf = vec![0u8; payload.len()];
    let mut adv_decomp_len = 0;
    let status = ttzip_rust_zstd_decompress(
        adv_comp_buf.as_ptr(),
        adv_comp_len,
        adv_decomp_buf.as_mut_ptr(),
        adv_decomp_buf.len(),
        &mut adv_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(adv_decomp_len, payload.len());
    assert_eq!(&adv_decomp_buf[..adv_decomp_len], &payload[..]);
}

#[test]
fn test_fl2_lzma2_ffi_roundtrip() {
    let payload = b"Fast-LZMA2 Multi-threaded parallel LZMA2 block stream testing in TTZip Rust Glue layer. "
        .repeat(50);

    let mut comp_buf = vec![0u8; ttzip_rust_fl2_compress_bound(payload.len()) + 1024];
    let mut comp_len = 0;
    let status = ttzip_rust_fl2_compress(
        payload.as_ptr(),
        payload.len(),
        comp_buf.as_mut_ptr(),
        comp_buf.len(),
        3,
        2, // 2 threads
        &mut comp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(comp_len > 0);

    let mut decomp_buf = vec![0u8; payload.len()];
    let mut decomp_len = 0;
    let status = ttzip_rust_fl2_decompress(
        comp_buf.as_ptr(),
        comp_len,
        decomp_buf.as_mut_ptr(),
        decomp_buf.len(),
        2, // 2 threads
        &mut decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(decomp_len, payload.len());
    assert_eq!(&decomp_buf[..decomp_len], &payload[..]);
}

#[test]
fn test_fast_blocks_lz4_snappy_lzfse_ffi() {
    let payload = b"Fast Block Compression comparison: LZ4 vs Google Snappy vs Apple LZFSE on ARM64 Apple Silicon. "
        .repeat(30);

    // 1. LZ4
    let mut lz4_buf = vec![0u8; ttzip_rust_lz4_compress_bound(payload.len())];
    let mut lz4_len = 0;
    let status = ttzip_rust_lz4_compress(
        payload.as_ptr(),
        payload.len(),
        lz4_buf.as_mut_ptr(),
        lz4_buf.len(),
        &mut lz4_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(lz4_len > 0);

    let mut lz4_decomp = vec![0u8; payload.len()];
    let mut lz4_decomp_len = 0;
    let status = ttzip_rust_lz4_decompress(
        lz4_buf.as_ptr(),
        lz4_len,
        lz4_decomp.as_mut_ptr(),
        lz4_decomp.len(),
        &mut lz4_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(lz4_decomp_len, payload.len());
    assert_eq!(&lz4_decomp[..lz4_decomp_len], &payload[..]);

    // 2. Snappy
    let mut snappy_buf = vec![0u8; ttzip_rust_snappy_max_compressed_length(payload.len())];
    let mut snappy_len = 0;
    let status = ttzip_rust_snappy_compress(
        payload.as_ptr(),
        payload.len(),
        snappy_buf.as_mut_ptr(),
        snappy_buf.len(),
        &mut snappy_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(snappy_len > 0);
    assert!(ttzip_rust_snappy_validate(snappy_buf.as_ptr(), snappy_len));

    let mut uncomp_len = 0;
    let status = ttzip_rust_snappy_uncompressed_length(snappy_buf.as_ptr(), snappy_len, &mut uncomp_len);
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(uncomp_len, payload.len());

    let mut snappy_decomp = vec![0u8; payload.len()];
    let mut snappy_decomp_len = 0;
    let status = ttzip_rust_snappy_decompress(
        snappy_buf.as_ptr(),
        snappy_len,
        snappy_decomp.as_mut_ptr(),
        snappy_decomp.len(),
        &mut snappy_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(snappy_decomp_len, payload.len());
    assert_eq!(&snappy_decomp[..snappy_decomp_len], &payload[..]);

    // 3. Apple LZFSE with 2MB scratch
    let mut lzfse_buf = vec![0u8; payload.len() + 1024];
    let mut lzfse_len = 0;
    let status = ttzip_rust_lzfse_compress(
        payload.as_ptr(),
        payload.len(),
        lzfse_buf.as_mut_ptr(),
        lzfse_buf.len(),
        &mut lzfse_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert!(lzfse_len > 0);

    let mut lzfse_decomp = vec![0u8; payload.len()];
    let mut lzfse_decomp_len = 0;
    let status = ttzip_rust_lzfse_decompress(
        lzfse_buf.as_ptr(),
        lzfse_len,
        lzfse_decomp.as_mut_ptr(),
        lzfse_decomp.len(),
        &mut lzfse_decomp_len,
    );
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(lzfse_decomp_len, payload.len());
    assert_eq!(&lzfse_decomp[..lzfse_decomp_len], &payload[..]);
}

#[test]
fn test_chardet_ffi() {
    let utf8_sample = "TTZip 字符探测测试：你好世界，苹果 macOS 原生归档压缩。".as_bytes();
    let mut name_buf = [0i8; 64];
    let status = ttzip_rust_detect_charset(
        utf8_sample.as_ptr(),
        utf8_sample.len(),
        name_buf.as_mut_ptr(),
        name_buf.len(),
    );
    assert_eq!(status, TTZipStatus::Ok);

    let charset_name = unsafe { CStr::from_ptr(name_buf.as_ptr()) }.to_str().unwrap();
    assert!(charset_name.to_uppercase().contains("UTF-8") || charset_name.to_uppercase().contains("UTF8"));
}

#[test]
fn test_multi_threaded_codec_concurrency() {
    let handles: Vec<_> = (0..8)
        .map(|i| {
            thread::spawn(move || {
                let payload = format!("Thread {} concurrent testing of all codecs in parallel with TLS handles.", i)
                    .repeat(100);
                let bytes = payload.as_bytes();

                // Deflate
                let mut def_buf = vec![0u8; deflate_compress_bound(bytes.len(), 6)];
                let def_len = deflate_compress(bytes, &mut def_buf, 6).unwrap();
                let mut def_out = vec![0u8; bytes.len()];
                let def_out_len = deflate_decompress(&def_buf[..def_len], &mut def_out).unwrap();
                assert_eq!(&def_out[..def_out_len], bytes);

                // Zstd
                let mut zstd_buf = vec![0u8; zstd_compress_bound(bytes.len())];
                let zstd_len = zstd_compress(bytes, &mut zstd_buf, 3).unwrap();
                let mut zstd_out = vec![0u8; bytes.len()];
                let zstd_out_len = zstd_decompress(&zstd_buf[..zstd_len], &mut zstd_out).unwrap();
                assert_eq!(&zstd_out[..zstd_out_len], bytes);

                // LZ4
                let mut lz4_buf = vec![0u8; lz4_compress_bound(bytes.len())];
                let lz4_len = lz4_compress(bytes, &mut lz4_buf).unwrap();
                let mut lz4_out = vec![0u8; bytes.len()];
                let lz4_out_len = lz4_decompress(&lz4_buf[..lz4_len], &mut lz4_out).unwrap();
                assert_eq!(&lz4_out[..lz4_out_len], bytes);

                // LZFSE
                let mut lzfse_buf = vec![0u8; bytes.len() + 1024];
                let lzfse_len = lzfse_compress(bytes, &mut lzfse_buf).unwrap();
                let mut lzfse_out = vec![0u8; bytes.len()];
                let lzfse_out_len = lzfse_decompress(&lzfse_buf[..lzfse_len], &mut lzfse_out).unwrap();
                assert_eq!(&lzfse_out[..lzfse_out_len], bytes);
            })
        })
        .collect();

    for h in handles {
        h.join().expect("Thread panicked");
    }
}
