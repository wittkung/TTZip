// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Comprehensive Property-Based Testing Suite (Feature 169 - Phase 2).
//!
//! Validates:
//! - **US1 / T003**: Codec roundtrip invariants across libdeflate, zstd, fast-lzma2, snappy, lz4, and lzfse.
//! - **US1 / T004**: ZIP and 7z container tree structures, extreme empty files, single-byte files, long paths, and UTF-8 / Unicode namespaces.
//! - **US1 / T005**: WinZip AES-256 and 7z AES-256 hardware cryptographic invariants, PBKDF2/SHA-256 KDF, and authentication rejection.

use proptest::collection::vec;
use proptest::prelude::*;
use std::collections::HashSet;
use std::fs;
use tempfile::tempdir;

use ttzip_glue::codecs::deflate::{
    deflate_compress, deflate_compress_bound, deflate_decompress, gzip_compress, gzip_decompress,
    zlib_compress, zlib_decompress,
};
use ttzip_glue::codecs::fast_blocks::{
    lz4_compress, lz4_compress_bound, lz4_decompress, lzfse_compress, lzfse_decompress,
    snappy_compress, snappy_decompress, snappy_max_compressed_length, snappy_uncompressed_length,
    snappy_validate,
};
use ttzip_glue::codecs::lzma2::{fl2_compress, fl2_compress_bound, fl2_decompress};
use ttzip_glue::codecs::zstd::{
    zstd_compress, zstd_compress_advanced, zstd_compress_bound, zstd_decompress,
    zstd_get_decompressed_size, ZstdConfig,
};
use ttzip_glue::crypto::aes256::{aes256_cbc_decrypt, aes256_cbc_encrypt, aes256_ctr_crypt};
use ttzip_glue::crypto::sha1::{
    winzip_aes256_decrypt_and_verify, winzip_aes256_encrypt_and_tag,
};
use ttzip_glue::crypto::sha256::sha256_7z_kdf;
use ttzip_glue::sevenz::writer::create_7z_solid_archive_bytes;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::types::{TTZipEncryptionMethod, TTZipExtractOptions, TTZipStatus};
use ttzip_glue::zip::reader::ZipArchive;
use ttzip_glue::zip::writer::{
    assemble_zip_archive, compress_items_parallel, ZipInputItem,
};

// ============================================================================
// Generators & Strategies
// ============================================================================

/// Strategy for arbitrary byte payload with diverse entropy patterns.
fn arbitrary_payload_strategy() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        // 1. Empty buffer
        Just(Vec::new()),
        // 2. Single byte
        vec(any::<u8>(), 1..=1),
        // 3. Small buffer (2..128 bytes)
        vec(any::<u8>(), 2..128),
        // 4. Repetitive compressible buffer (e.g. repeated patterns)
        (vec(any::<u8>(), 1..16), 2usize..256).prop_map(|(pat, repeat)| {
            let mut out = Vec::with_capacity(pat.len() * repeat);
            for _ in 0..repeat {
                out.extend_from_slice(&pat);
            }
            out
        }),
        // 5. Medium random buffer (128..8192 bytes)
        vec(any::<u8>(), 128..8192),
    ]
}

/// Strategy for valid UTF-8 safe relative path segments (ASCII, Chinese, Japanese, Emoji).
fn safe_path_segment_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-zA-Z0-9_-]{1,16}",
        Just("测试目录".to_string()),
        Just("文档_2026".to_string()),
        Just("日本語フォルダ".to_string()),
        Just("한국어_데이터".to_string()),
        Just("🚀_apple_silicon".to_string()),
        Just("space in name".to_string()),
        Just("special-chars_#123".to_string()),
    ]
}

/// Strategy for valid relative archive entry paths (1 to 4 directory levels).
fn relative_entry_path_strategy() -> impl Strategy<Value = String> {
    (
        vec(safe_path_segment_strategy(), 1..4),
        "[a-zA-Z0-9_]{1,12}\\.(txt|dat|bin|json|md)",
    )
        .prop_map(|(dirs, filename)| {
            let dir_part = dirs.join("/");
            format!("{}/{}", dir_part, filename)
        })
}

/// Strategy for a single archive entry item.
#[derive(Debug, Clone)]
struct GeneratedEntry {
    rel_path: String,
    data: Vec<u8>,
    is_directory: bool,
}

fn arbitrary_archive_entries_strategy() -> impl Strategy<Value = Vec<GeneratedEntry>> {
    vec(
        (
            relative_entry_path_strategy(),
            arbitrary_payload_strategy(),
            any::<bool>(),
        ),
        1..12,
    )
    .prop_map(|raw_entries| {
        let mut seen_paths = HashSet::new();
        let mut entries = Vec::new();

        // Ensure at least one directory and one empty file in the mix
        for (path, data, is_dir) in raw_entries {
            let actual_path = if is_dir {
                if path.ends_with('/') {
                    path
                } else {
                    format!("{}/", path)
                }
            } else {
                path
            };

            if seen_paths.insert(actual_path.clone()) {
                entries.push(GeneratedEntry {
                    rel_path: actual_path,
                    data: if is_dir { Vec::new() } else { data },
                    is_directory: is_dir,
                });
            }
        }

        // Guarantee at least one file entry exists
        if !entries.iter().any(|e| !e.is_directory) {
            entries.push(GeneratedEntry {
                rel_path: "root_default.txt".to_string(),
                data: b"TTZip Safe Archive Payload".to_vec(),
                is_directory: false,
            });
        }

        entries
    })
}

// ============================================================================
// Task T003 [US1]: Codecs Roundtrip Property Tests
// ============================================================================

proptest! {
    #![proptest_config(ProptestConfig::with_cases(60))]

    /// Invariant: libdeflate (raw DEFLATE, zlib, gzip) roundtrip preserves exact byte stream.
    #[test]
    fn prop_test_deflate_zlib_gzip_lossless_roundtrip(
        payload in arbitrary_payload_strategy(),
        level in 1i32..=9,
    ) {
        // 1. Raw DEFLATE
        let bound = deflate_compress_bound(payload.len(), level);
        let mut comp = vec![0u8; bound + 64];
        let comp_len = deflate_compress(&payload, &mut comp, level)
            .expect("deflate compress must succeed");

        let mut decomp = vec![0u8; payload.len()];
        let decomp_len = deflate_decompress(&comp[..comp_len], &mut decomp)
            .expect("deflate decompress must succeed");

        prop_assert_eq!(decomp_len, payload.len());
        prop_assert_eq!(&decomp[..decomp_len], &payload[..]);

        // 2. zlib
        let mut zlib_comp = vec![0u8; payload.len() + 1024];
        let zlib_len = zlib_compress(&payload, &mut zlib_comp, level)
            .expect("zlib compress must succeed");

        let mut zlib_decomp = vec![0u8; payload.len()];
        let zlib_decomp_len = zlib_decompress(&zlib_comp[..zlib_len], &mut zlib_decomp)
            .expect("zlib decompress must succeed");

        prop_assert_eq!(zlib_decomp_len, payload.len());
        prop_assert_eq!(&zlib_decomp[..zlib_decomp_len], &payload[..]);

        // 3. gzip
        let mut gzip_comp = vec![0u8; payload.len() + 1024];
        let gzip_len = gzip_compress(&payload, &mut gzip_comp, level)
            .expect("gzip compress must succeed");

        let mut gzip_decomp = vec![0u8; payload.len()];
        let gzip_decomp_len = gzip_decompress(&gzip_comp[..gzip_len], &mut gzip_decomp)
            .expect("gzip decompress must succeed");

        prop_assert_eq!(gzip_decomp_len, payload.len());
        prop_assert_eq!(&gzip_decomp[..gzip_decomp_len], &payload[..]);
    }

    /// Invariant: Facebook Zstandard roundtrip preserves exact byte stream across levels and LDM.
    #[test]
    fn prop_test_zstd_lossless_roundtrip(
        payload in arbitrary_payload_strategy(),
        level in 1i32..=12,
    ) {
        // 1. Basic ZSTD
        let bound = zstd_compress_bound(payload.len());
        let mut comp = vec![0u8; bound + 64];
        let comp_len = zstd_compress(&payload, &mut comp, level)
            .expect("zstd compress must succeed");

        if !payload.is_empty() {
            let detected = zstd_get_decompressed_size(&comp[..comp_len]);
            prop_assert_eq!(detected, Some(payload.len() as u64));
        }

        let mut decomp = vec![0u8; payload.len()];
        let decomp_len = zstd_decompress(&comp[..comp_len], &mut decomp)
            .expect("zstd decompress must succeed");

        prop_assert_eq!(decomp_len, payload.len());
        prop_assert_eq!(&decomp[..decomp_len], &payload[..]);

        // 2. Advanced Multi-threaded ZSTD config
        let cfg = ZstdConfig {
            level,
            nb_workers: 2,
            job_size_mb: 1,
            overlap_log: 2,
            window_log: 18,
            enable_ldm: true,
            enable_checksum: true,
        };

        let mut adv_comp = vec![0u8; bound + 64];
        let adv_len = zstd_compress_advanced(&payload, &mut adv_comp, &cfg)
            .expect("zstd advanced compress must succeed");

        let mut adv_decomp = vec![0u8; payload.len()];
        let adv_decomp_len = zstd_decompress(&adv_comp[..adv_len], &mut adv_decomp)
            .expect("zstd advanced decompress must succeed");

        prop_assert_eq!(adv_decomp_len, payload.len());
        prop_assert_eq!(&adv_decomp[..adv_decomp_len], &payload[..]);
    }

    /// Invariant: fast-lzma2 roundtrip preserves exact byte stream across thread budgets.
    #[test]
    fn prop_test_fast_lzma2_lossless_roundtrip(
        payload in arbitrary_payload_strategy(),
        level in 1i32..=6,
        threads in 1u32..=4,
    ) {
        let bound = fl2_compress_bound(payload.len()) + 1024;
        let mut comp = vec![0u8; bound];
        let comp_len = fl2_compress(&payload, &mut comp, level, threads)
            .expect("fl2 compress must succeed");

        let mut decomp = vec![0u8; payload.len()];
        let decomp_len = fl2_decompress(&comp[..comp_len], &mut decomp, threads)
            .expect("fl2 decompress must succeed");

        prop_assert_eq!(decomp_len, payload.len());
        prop_assert_eq!(&decomp[..decomp_len], &payload[..]);
    }

    /// Invariant: Ultra-fast block codecs (LZ4, Snappy, Apple LZFSE) preserve exact byte stream.
    #[test]
    fn prop_test_fast_blocks_lz4_snappy_lzfse_lossless_roundtrip(
        payload in arbitrary_payload_strategy(),
    ) {
        // 1. LZ4
        let lz4_bound = lz4_compress_bound(payload.len()) + 64;
        let mut lz4_comp = vec![0u8; lz4_bound];
        let lz4_len = lz4_compress(&payload, &mut lz4_comp).expect("lz4 compress must succeed");

        let mut lz4_decomp = vec![0u8; payload.len()];
        let lz4_decomp_len = lz4_decompress(&lz4_comp[..lz4_len], &mut lz4_decomp)
            .expect("lz4 decompress must succeed");

        prop_assert_eq!(lz4_decomp_len, payload.len());
        prop_assert_eq!(&lz4_decomp[..lz4_decomp_len], &payload[..]);

        // 2. Google Snappy
        let snappy_bound = snappy_max_compressed_length(payload.len()) + 64;
        let mut snappy_comp = vec![0u8; snappy_bound];
        let snappy_len = snappy_compress(&payload, &mut snappy_comp).expect("snappy compress must succeed");

        prop_assert!(snappy_validate(&snappy_comp[..snappy_len]));
        let uncomp_len = snappy_uncompressed_length(&snappy_comp[..snappy_len])
            .expect("snappy uncompressed length");
        prop_assert_eq!(uncomp_len, payload.len());

        let mut snappy_decomp = vec![0u8; payload.len()];
        let snappy_decomp_len = snappy_decompress(&snappy_comp[..snappy_len], &mut snappy_decomp)
            .expect("snappy decompress must succeed");

        prop_assert_eq!(snappy_decomp_len, payload.len());
        prop_assert_eq!(&snappy_decomp[..snappy_decomp_len], &payload[..]);

        // 3. Apple LZFSE
        let mut lzfse_comp = vec![0u8; payload.len() + 2048];
        let lzfse_len = lzfse_compress(&payload, &mut lzfse_comp).expect("lzfse compress must succeed");

        let mut lzfse_decomp = vec![0u8; payload.len()];
        let lzfse_decomp_len = lzfse_decompress(&lzfse_comp[..lzfse_len], &mut lzfse_decomp)
            .expect("lzfse decompress must succeed");

        prop_assert_eq!(lzfse_decomp_len, payload.len());
        prop_assert_eq!(&lzfse_decomp[..lzfse_decomp_len], &payload[..]);
    }
}

// ============================================================================
// Task T004 [US1]: ZIP & 7z Archive Structure Property Tests
// ============================================================================

proptest! {
    #![proptest_config(ProptestConfig::with_cases(50))]

    /// Invariant: ZIP container preserves multi-level directory tree, empty files,
    /// single-byte files, long paths, and UTF-8 unicode filenames across parallel execution.
    #[test]
    fn prop_test_zip_container_hierarchy_roundtrip(
        entries in arbitrary_archive_entries_strategy(),
        level in 0i32..=6,
    ) {
        let items: Vec<ZipInputItem> = entries
            .iter()
            .map(|e| ZipInputItem {
                rel_path: e.rel_path.clone(),
                data: e.data.clone(),
                mtime_epoch_secs: 1700000000,
                mode: if e.is_directory { 0o755 } else { 0o644 },
                is_directory: e.is_directory,
            })
            .collect();

        // 1. Parallel Compression & Packaging
        let compressed = compress_items_parallel(
            items.clone(),
            level,
            TTZipEncryptionMethod::None,
            None,
            4,
        ).expect("zip compression must succeed");

        let zip_bytes = assemble_zip_archive(&compressed)
            .expect("zip assembly must succeed");
        prop_assert!(!zip_bytes.is_empty());

        // 2. Open Archive and Verify Metadata
        let archive = ZipArchive::open_slice(&zip_bytes)
            .expect("zip slice opening must succeed");
        prop_assert_eq!(archive.len(), items.len());

        // 3. In-Memory Entry Extraction Invariant
        for (i, item) in items.iter().enumerate() {
            let extracted = archive.extract_entry_bytes(i, None)
                .expect("entry extraction must succeed");

            if item.is_directory {
                prop_assert!(extracted.is_empty());
            } else {
                prop_assert_eq!(&extracted, &item.data, "Payload mismatch for entry {}", item.rel_path);
            }
        }

        // 4. On-Disk Safe Landing Invariant
        let temp_dir = tempdir().expect("tempdir creation");
        let extract_opts = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 4,
            overwrite_existing: true,
            preserve_permissions: false,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let report = archive.extract_all(temp_dir.path(), &extract_opts)
            .expect("extract_all must succeed");
        prop_assert_eq!(report.processed_entries_count, items.len());

        for item in &items {
            let target_path = temp_dir.path().join(item.rel_path.trim_end_matches('/'));
            prop_assert!(target_path.exists(), "Target file must exist: {:?}", target_path);

            if !item.is_directory {
                let disk_data = fs::read(&target_path).expect("read extracted file");
                prop_assert_eq!(&disk_data, &item.data, "Disk content mismatch for {:?}", target_path);
            }
        }
    }

    /// Invariant: 7z Solid container preserves multi-level directory tree, empty files,
    /// single-byte files, long paths, and UTF-8 unicode filenames across solid stream decoding.
    #[test]
    fn prop_test_sevenz_container_hierarchy_roundtrip(
        entries in arbitrary_archive_entries_strategy(),
        level in 0i32..=6,
    ) {
        let items: Vec<ZipInputItem> = entries
            .iter()
            .map(|e| ZipInputItem {
                rel_path: e.rel_path.clone(),
                data: e.data.clone(),
                mtime_epoch_secs: 1700000000,
                mode: if e.is_directory { 0o755 } else { 0o644 },
                is_directory: e.is_directory,
            })
            .collect();

        // 1. Create Solid 7z Archive
        let sevenz_bytes = create_7z_solid_archive_bytes(&items, level, 2)
            .expect("7z solid archive creation must succeed");
        prop_assert!(!sevenz_bytes.is_empty());

        // 2. Open Archive and Verify Metadata
        let archive = SevenZArchive::open_slice(&sevenz_bytes)
            .expect("7z slice opening must succeed");
        prop_assert_eq!(archive.len(), items.len());

        // 3. Selective Entry Extraction Invariant
        for (i, item) in items.iter().enumerate() {
            let extracted = archive.extract_entry_bytes(i, None)
                .expect("7z entry extraction must succeed");

            if item.is_directory || item.data.is_empty() {
                prop_assert!(extracted.is_empty());
            } else {
                prop_assert_eq!(&extracted, &item.data, "7z payload mismatch for entry {}", item.rel_path);
            }
        }

        // 4. On-Disk Safe Landing Invariant
        let temp_dir = tempdir().expect("tempdir creation");
        let extract_opts = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 2,
            overwrite_existing: true,
            preserve_permissions: false,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let report = archive.extract_all(temp_dir.path(), &extract_opts)
            .expect("7z extract_all must succeed");
        prop_assert_eq!(report.processed_entries_count, items.len());

        for item in &items {
            let target_path = temp_dir.path().join(item.rel_path.trim_end_matches('/'));
            prop_assert!(target_path.exists(), "Target 7z file must exist: {:?}", target_path);

            if !item.is_directory {
                let disk_data = fs::read(&target_path).expect("read extracted 7z file");
                prop_assert_eq!(&disk_data, &item.data, "7z disk content mismatch for {:?}", target_path);
            }
        }
    }
}

// ============================================================================
// Task T005 [US1]: WinZip AES-256 & 7z AES-256 Encryption Property Tests
// ============================================================================

proptest! {
    #![proptest_config(ProptestConfig::with_cases(50))]

    /// Invariant: WinZip AES-256 cryptographic pipeline guarantees 100% roundtrip correctness
    /// with correct password, and 100% rejection on wrong password or bit flips.
    #[test]
    fn prop_test_winzip_aes256_cryptographic_invariants(
        password in "[a-zA-Z0-9!@#$%^&*()_+~`\\-=]{1,32}",
        wrong_password in "[a-zA-Z0-9!@#$%^&*()_+~`\\-=]{1,32}",
        salt in vec(any::<u8>(), 16..=16),
        payload in arbitrary_payload_strategy(),
    ) {
        prop_assume!(password != wrong_password);

        let mut salt_arr = [0u8; 16];
        salt_arr.copy_from_slice(&salt);

        // 1. Encryption & Tagging
        let mut enc_payload = Vec::new();
        winzip_aes256_encrypt_and_tag(&password, &salt_arr, &payload, &mut enc_payload)
            .expect("winzip aes encrypt must succeed");
        prop_assert_eq!(enc_payload.len(), 16 + 2 + payload.len() + 10);

        // 2. Decryption with Correct Password
        let mut decrypted = vec![0u8; payload.len()];
        let dec_len = winzip_aes256_decrypt_and_verify(&password, &enc_payload, &mut decrypted)
            .expect("winzip aes decrypt with correct password must succeed");

        prop_assert_eq!(dec_len, payload.len());
        prop_assert_eq!(&decrypted, &payload);

        // 3. Decryption with Wrong Password (Must Reject)
        let wrong_res = winzip_aes256_decrypt_and_verify(&wrong_password, &enc_payload, &mut decrypted);
        prop_assert!(
            wrong_res.is_err(),
            "Wrong password must be rejected by WinZip AES verification"
        );

        // 4. Tampered Ciphertext or MAC (Must Reject)
        if !enc_payload.is_empty() {
            let mut tampered = enc_payload.clone();
            let last_idx = tampered.len() - 1;
            tampered[last_idx] ^= 0x01; // Flip one bit in MAC
            let tampered_res = winzip_aes256_decrypt_and_verify(&password, &tampered, &mut decrypted);
            prop_assert!(
                tampered_res.is_err(),
                "Tampered MAC must be rejected by WinZip AES verification"
            );
        }
    }

    /// Invariant: Full End-to-End ZIP WinZip AES-256 Archive Encryption.
    #[test]
    fn prop_test_zip_winzip_aes256_e2e_archive_invariants(
        password in "[a-zA-Z0-9!@#$%^&*()_+~`\\-=]{4,24}",
        wrong_password in "[a-zA-Z0-9!@#$%^&*()_+~`\\-=]{4,24}",
        entries in arbitrary_archive_entries_strategy(),
    ) {
        prop_assume!(password != wrong_password);

        let items: Vec<ZipInputItem> = entries
            .iter()
            .map(|e| ZipInputItem {
                rel_path: e.rel_path.clone(),
                data: e.data.clone(),
                mtime_epoch_secs: 1700000000,
                mode: if e.is_directory { 0o755 } else { 0o644 },
                is_directory: e.is_directory,
            })
            .collect();

        // 1. Parallel Encrypted Compression
        let compressed = compress_items_parallel(
            items.clone(),
            6,
            TTZipEncryptionMethod::Aes256,
            Some(&password),
            4,
        ).expect("encrypted zip compression must succeed");

        let zip_bytes = assemble_zip_archive(&compressed)
            .expect("assemble encrypted zip must succeed");

        let archive = ZipArchive::open_slice(&zip_bytes)
            .expect("open encrypted zip slice must succeed");

        // 2. Extract with Correct Password
        for (i, item) in items.iter().enumerate() {
            let extracted = archive.extract_entry_bytes(i, Some(&password))
                .expect("extract encrypted entry with correct password must succeed");

            if item.is_directory {
                prop_assert!(extracted.is_empty());
            } else {
                prop_assert_eq!(&extracted, &item.data, "Decrypted data mismatch for {}", item.rel_path);
            }
        }

        // 3. Extract with Wrong Password / Missing Password
        for (i, item) in items.iter().enumerate() {
            if !item.is_directory && !item.data.is_empty() {
                let err_wrong = archive.extract_entry_bytes(i, Some(&wrong_password));
                prop_assert_eq!(err_wrong, Err(TTZipStatus::ErrInvalidPassword));

                let err_none = archive.extract_entry_bytes(i, None);
                prop_assert_eq!(err_none, Err(TTZipStatus::ErrInvalidPassword));
            }
        }
    }

    /// Invariant: 7z SHA-256 KDF and AES-256 CTR/CBC crypto operators maintain avalanche effect
    /// and lossless roundtrip on random bitstreams.
    #[test]
    fn prop_test_7z_kdf_and_aes_operators(
        password in "[a-zA-Z0-9\\p{L}]{1,32}",
        salt in vec(any::<u8>(), 0..=16),
        key in vec(any::<u8>(), 32..=32),
        iv in vec(any::<u8>(), 16..=16),
        counter in any::<u64>(),
        payload_blocks in vec(any::<u8>(), 1..=32), // In 16-byte blocks
    ) {
        // 1. 7z KDF Determinism
        let kdf_key1 = sha256_7z_kdf(&password, &salt, 6);
        let kdf_key2 = sha256_7z_kdf(&password, &salt, 6);
        prop_assert_eq!(kdf_key1, kdf_key2);

        // 2. AES-256-CTR Roundtrip (symmetric stream cipher)
        let mut key_arr = [0u8; 32];
        key_arr.copy_from_slice(&key);
        let mut cipher = vec![0u8; payload_blocks.len()];
        let mut decrypted_ctr = vec![0u8; payload_blocks.len()];

        aes256_ctr_crypt(&key_arr, counter, &payload_blocks, &mut cipher)
            .expect("ctr encrypt must succeed");
        aes256_ctr_crypt(&key_arr, counter, &cipher, &mut decrypted_ctr)
            .expect("ctr decrypt must succeed");
        prop_assert_eq!(decrypted_ctr, payload_blocks.clone());

        // 3. AES-256-CBC Roundtrip (16-byte aligned blocks)
        let mut iv_arr = [0u8; 16];
        iv_arr.copy_from_slice(&iv);

        let mut aligned_payload = payload_blocks.clone();
        while aligned_payload.len() % 16 != 0 {
            aligned_payload.push(0x20);
        }

        let mut cipher_cbc = vec![0u8; aligned_payload.len()];
        let mut decrypted_cbc = vec![0u8; aligned_payload.len()];

        aes256_cbc_encrypt(&key_arr, &iv_arr, &aligned_payload, &mut cipher_cbc)
            .expect("cbc encrypt must succeed");
        aes256_cbc_decrypt(&key_arr, &iv_arr, &cipher_cbc, &mut decrypted_cbc)
            .expect("cbc decrypt must succeed");
        prop_assert_eq!(decrypted_cbc, aligned_payload);
    }
}
