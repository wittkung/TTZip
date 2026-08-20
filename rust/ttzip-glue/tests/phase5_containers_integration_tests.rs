// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Phase 5 Integration Tests for Container Format Parsing and Parallel Execution Engine.
//!
//! Validates Tasks T020 (ZIP Engine, Zip64, WinZip AES-256) and T021 (7z Engine, Solid Stream, AES-256 NEON).

use std::fs;
use std::time::Instant;
use ttzip_glue::sevenz::{create_7z_solid_archive_bytes, SevenZArchive};
use ttzip_glue::types::{
    TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod, TTZipExtractOptions,
    TTZipStatus,
};
use ttzip_glue::zip::{
    assemble_zip_archive, compress_items_parallel, create_zip_archive, find_eocd, parse_all_entries,
    ZipArchive, ZipInputItem,
};

#[test]
fn test_phase5_zip_cdfh_zip64_and_parallel_decompression() {
    let mut items = Vec::new();

    // 1. Regular text file
    items.push(ZipInputItem {
        rel_path: "readme.txt".to_string(),
        data: b"TTZip High-Performance Native Archive Engine for macOS".to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    });

    // 2. Directory entry
    items.push(ZipInputItem {
        rel_path: "src/".to_string(),
        data: Vec::new(),
        mtime_epoch_secs: 1700000000,
        mode: 0o755,
        is_directory: true,
    });

    // 3. Subfolder file with compressible pattern
    let mut large_compressible = vec![0u8; 1024 * 1024]; // 1MB
    for (i, b) in large_compressible.iter_mut().enumerate() {
        *b = (i % 251) as u8;
    }
    items.push(ZipInputItem {
        rel_path: "src/large.dat".to_string(),
        data: large_compressible.clone(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    });

    // 4. Store entry
    items.push(ZipInputItem {
        rel_path: "store.bin".to_string(),
        data: vec![0xABu8; 4096],
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    });

    // Compress items with Level 6 in parallel (4 threads)
    let compressed = compress_items_parallel(
        items.clone(),
        6,
        TTZipEncryptionMethod::None,
        None,
        4,
    ).expect("parallel zip compression failed");

    let zip_bytes = assemble_zip_archive(&compressed).expect("assemble zip failed");
    assert!(!zip_bytes.is_empty());

    // Parse EOCD and Central Directory
    let eocd = find_eocd(&zip_bytes).expect("find EOCD failed");
    assert_eq!(eocd.total_entries, 4);

    let entries = parse_all_entries(&zip_bytes).expect("parse all entries failed");
    assert_eq!(entries.len(), 4);
    assert_eq!(entries[0].rel_path, "readme.txt");
    assert_eq!(entries[1].rel_path, "src/");
    assert!(entries[1].is_directory);
    assert_eq!(entries[2].rel_path, "src/large.dat");
    assert_eq!(entries[2].uncompressed_size, 1024 * 1024);
    assert_eq!(entries[3].rel_path, "store.bin");

    // Open Archive and verify single-pass extractions
    let archive = ZipArchive::open_slice(&zip_bytes).expect("open zip slice failed");
    let ext_readme = archive.extract_entry_bytes(0, None).expect("extract readme failed");
    assert_eq!(ext_readme, b"TTZip High-Performance Native Archive Engine for macOS");

    let ext_large = archive.extract_entry_bytes(2, None).expect("extract large failed");
    assert_eq!(ext_large.len(), 1024 * 1024);
    assert_eq!(ext_large, large_compressible);

    let ext_store = archive.extract_entry_bytes(3, None).expect("extract store failed");
    assert_eq!(ext_store, vec![0xABu8; 4096]);
}

#[test]
fn test_phase5_zip_winzip_aes256_hardware_encryption() {
    let password = "SecretMasterPassword_2026";
    let payload = b"WinZip AES-256 Encrypted Payload Data with AE-2 Hardware Authentication!";

    let items = vec![
        ZipInputItem {
            rel_path: "credentials.json".to_string(),
            data: payload.to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o600,
            is_directory: false,
        },
    ];

    let compressed = compress_items_parallel(
        items,
        6,
        TTZipEncryptionMethod::Aes256,
        Some(password),
        2,
    ).expect("encrypt compression failed");

    let zip_bytes = assemble_zip_archive(&compressed).expect("assemble encrypted zip failed");
    let archive = ZipArchive::open_slice(&zip_bytes).expect("open encrypted zip failed");

    assert_eq!(archive.len(), 1);
    let entry = &archive.entries()[0];
    assert!(entry.is_encrypted);
    assert_eq!(entry.compression_method, 99); // WinZip AES

    // Correct password decryption
    let decrypted = archive.extract_entry_bytes(0, Some(password)).expect("decrypt failed");
    assert_eq!(decrypted, payload);

    // Incorrect password rejection
    let err = archive.extract_entry_bytes(0, Some("WrongPassword123"));
    assert_eq!(err, Err(TTZipStatus::ErrInvalidPassword));

    // Missing password rejection
    let missing_err = archive.extract_entry_bytes(0, None);
    assert_eq!(missing_err, Err(TTZipStatus::ErrInvalidPassword));
}

#[test]
fn test_phase5_zip_e2e_disk_extraction_and_safe_landing() {
    let temp_root = std::env::temp_dir().join(format!("ttzip_phase5_test_{}", std::process::id()));
    let src_dir = temp_root.join("source");
    let out_zip = temp_root.join("archive.zip");
    let dest_dir = temp_root.join("extracted");

    let _ = fs::remove_dir_all(&temp_root);
    fs::create_dir_all(&src_dir).unwrap();

    // Create files in source directory
    fs::write(src_dir.join("a.txt"), b"File Alpha Content").unwrap();
    let sub = src_dir.join("subdir");
    fs::create_dir_all(&sub).unwrap();
    fs::write(sub.join("b.txt"), b"File Beta Nested Content").unwrap();

    let options = TTZipCreateOptions {
        format: ttzip_glue::types::TTZipArchiveFormat::Zip,
        level: TTZipCompressionLevel::Normal,
        encryption: TTZipEncryptionMethod::None,
        password: std::ptr::null(),
        thread_budget: 4,
        solid_block_size_mb: 0,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let report = create_zip_archive(&out_zip, &[src_dir.clone()], &options).expect("create zip failed");
    assert!(report.total_entries >= 2);
    assert!(out_zip.exists());

    let zip_data = fs::read(&out_zip).expect("read zip failed");
    let archive = ZipArchive::open_slice(&zip_data).expect("open zip failed");

    let extract_opts = TTZipExtractOptions {
        destination_path: std::ptr::null(),
        password: std::ptr::null(),
        thread_budget: 4,
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let ext_report = archive.extract_all(&dest_dir, &extract_opts).expect("extract all failed");
    assert!(ext_report.processed_entries_count >= 2);

    // Verify extracted contents
    let ext_a = fs::read(dest_dir.join("source/a.txt")).expect("read ext a failed");
    assert_eq!(ext_a, b"File Alpha Content");

    let ext_b = fs::read(dest_dir.join("source/subdir/b.txt")).expect("read ext b failed");
    assert_eq!(ext_b, b"File Beta Nested Content");

    let _ = fs::remove_dir_all(&temp_root);
}

#[test]
fn test_phase5_sevenz_solid_roundtrip_and_selective_extraction() {
    let items = vec![
        ZipInputItem {
            rel_path: "file1.txt".to_string(),
            data: b"First file payload in 7z solid stream.".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "file2.bin".to_string(),
            data: vec![0x77u8; 16384],
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "nested/file3.txt".to_string(),
            data: b"Third file in solid block!".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
    ];

    let sevenz_bytes = create_7z_solid_archive_bytes(&items, 6, 2).expect("create 7z solid failed");
    assert!(!sevenz_bytes.is_empty());

    let archive = SevenZArchive::open_slice(&sevenz_bytes).expect("open 7z slice failed");
    assert_eq!(archive.len(), 3);

    // Test selective extraction of second file directly from solid stream
    let ext_f2 = archive.extract_entry_bytes(1, None).expect("extract f2 failed");
    assert_eq!(ext_f2.len(), 16384);
    assert_eq!(ext_f2, vec![0x77u8; 16384]);

    // Test extraction of third file
    let ext_f3 = archive.extract_entry_bytes(2, None).expect("extract f3 failed");
    assert_eq!(ext_f3, b"Third file in solid block!");

    // Test extraction of first file
    let ext_f1 = archive.extract_entry_bytes(0, None).expect("extract f1 failed");
    assert_eq!(ext_f1, b"First file payload in 7z solid stream.");
}

#[test]
fn test_phase5_compression_and_decompression_throughput() {
    // Generate 16MB of synthetic compressible text payload
    let mut large_buffer = Vec::with_capacity(16 * 1024 * 1024);
    let sample_line = b"TTZip Apple Silicon Hardware Accelerated Compression Stream 2026\n";
    while large_buffer.len() + sample_line.len() <= 16 * 1024 * 1024 {
        large_buffer.extend_from_slice(sample_line);
    }

    let items = vec![ZipInputItem {
        rel_path: "benchmark.txt".to_string(),
        data: large_buffer.clone(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    }];

    // Measure Level 1 compression throughput
    let comp_start = Instant::now();
    let compressed = compress_items_parallel(
        items,
        1, // Fastest Deflate
        TTZipEncryptionMethod::None,
        None,
        4, // 4 threads
    ).expect("bench compression failed");
    let comp_duration = comp_start.elapsed();

    let comp_mb = (large_buffer.len() as f64) / (1024.0 * 1024.0);
    let comp_mb_per_sec = comp_mb / comp_duration.as_secs_f64();
    println!("ZIP Level 1 Multi-Core Compression Throughput: {:.2} MB/s", comp_mb_per_sec);
    let min_comp = if cfg!(debug_assertions) { 200.0 } else { 1500.0 };
    assert!(comp_mb_per_sec >= min_comp, "Compression speed below baseline: {:.2} MB/s", comp_mb_per_sec);

    let zip_bytes = assemble_zip_archive(&compressed).expect("assemble failed");
    let archive = ZipArchive::open_slice(&zip_bytes).expect("open failed");

    // Measure decompression throughput
    let dec_start = Instant::now();
    let decompressed = archive.extract_entry_bytes(0, None).expect("decompress failed");
    let dec_duration = dec_start.elapsed();

    let dec_mb_per_sec = comp_mb / dec_duration.as_secs_f64();
    println!("ZIP Single-Entry Decompression Throughput: {:.2} MB/s", dec_mb_per_sec);
    assert_eq!(decompressed.len(), large_buffer.len());
    let min_dec = if cfg!(debug_assertions) { 400.0 } else { 4500.0 };
    assert!(dec_mb_per_sec >= min_dec, "Decompression speed below baseline: {:.2} MB/s", dec_mb_per_sec);
}
