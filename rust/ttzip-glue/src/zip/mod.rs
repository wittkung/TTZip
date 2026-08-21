// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Native ZIP Engine module.
//!
//! Provides zero-copy Central Directory parsing, Zip64 large-catalog support,
//! WinZip AES-256 hardware decryption passthrough, multi-core parallel Deflate/Store
//! compression and decompression, and ZipSlip-immune safe file landing.

pub mod extra;
pub mod parser;
pub mod reader;
pub mod writer;

pub use extra::ZipExtraFields;
pub use parser::{
    dos_to_unix_time, find_eocd, parse_all_entries, parse_cdfh_entry, parse_local_file_header,
    EocdInfo, ZipEntry, MAGIC_CDFH, MAGIC_EOCD, MAGIC_LFH, MAGIC_ZIP64_EOCD, MAGIC_ZIP64_LOCATOR,
};
pub use reader::{ZipArchive, ZipExtractReport};
pub use writer::{
    assemble_zip_archive, collect_zip_input_items, compress_items_parallel, create_zip_archive,
    unix_to_dos_time, ZipCompressedItem, ZipCreateReport, ZipInputItem,
};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{TTZipEncryptionMethod, TTZipStatus};

    #[test]
    fn test_zip_in_memory_roundtrip_store_and_deflate() {
        let items = vec![
            ZipInputItem {
                rel_path: "hello.txt".to_string(),
                data: b"Hello TTZip Native Rust ZIP Engine!".to_vec(),
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
            ZipInputItem {
                rel_path: "subfolder/".to_string(),
                data: Vec::new(),
                mtime_epoch_secs: 1700000000,
                mode: 0o755,
                is_directory: true,
            },
            ZipInputItem {
                rel_path: "subfolder/repeated.bin".to_string(),
                data: vec![0x42u8; 10000],
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
        ];

        let compressed = compress_items_parallel(
            items.clone(),
            6,
            TTZipEncryptionMethod::None,
            None,
            4,
        ).expect("compression failed");

        let zip_bytes = assemble_zip_archive(&compressed).expect("assembly failed");
        assert!(!zip_bytes.is_empty());

        let archive = ZipArchive::open_slice(&zip_bytes).expect("open slice failed");
        assert_eq!(archive.len(), 3);

        let e0 = archive.extract_entry_bytes(0, None).expect("extract e0 failed");
        assert_eq!(e0, b"Hello TTZip Native Rust ZIP Engine!");

        let e1 = archive.extract_entry_bytes(1, None).expect("extract e1 failed");
        assert!(e1.is_empty());

        let e2 = archive.extract_entry_bytes(2, None).expect("extract e2 failed");
        assert_eq!(e2, vec![0x42u8; 10000]);
    }

    #[test]
    fn test_zip_winzip_aes256_roundtrip() {
        let password = "SuperSecretPassword2026!";
        let plaintext = b"Sensitive payload encrypted with WinZip AES-256 in Rust Native Engine.";

        let items = vec![ZipInputItem {
            rel_path: "secret.txt".to_string(),
            data: plaintext.to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o600,
            is_directory: false,
        }];

        let compressed = compress_items_parallel(
            items,
            6,
            TTZipEncryptionMethod::Aes256,
            Some(password),
            2,
        ).expect("encrypted compression failed");

        let zip_bytes = assemble_zip_archive(&compressed).expect("assembly failed");
        let archive = ZipArchive::open_slice(&zip_bytes).expect("open slice failed");

        assert_eq!(archive.len(), 1);
        assert!(archive.entries()[0].is_encrypted);
        assert_eq!(archive.entries()[0].compression_method, 99);

        // Extract with correct password
        let decrypted = archive.extract_entry_bytes(0, Some(password)).expect("decryption failed");
        assert_eq!(decrypted, plaintext);

        // Extract with wrong password
        let wrong_res = archive.extract_entry_bytes(0, Some("WrongPassword"));
        assert_eq!(wrong_res, Err(TTZipStatus::ErrInvalidPassword));
    }

    #[test]
    fn test_zip_store_parallel_disk_roundtrip() {
        use crate::types::{TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipExtractOptions};
        use std::fs;

        let temp_src = std::env::temp_dir().join("ttzip_test_store_src");
        let temp_dst_zip = std::env::temp_dir().join("ttzip_test_store_out.zip");
        let temp_extract = std::env::temp_dir().join("ttzip_test_store_extracted");

        let _ = fs::remove_dir_all(&temp_src);
        let _ = fs::remove_file(&temp_dst_zip);
        let _ = fs::remove_dir_all(&temp_extract);

        fs::create_dir_all(temp_src.join("nested")).unwrap();
        fs::write(temp_src.join("file1.txt"), b"Hello Store Stream!").unwrap();
        fs::write(temp_src.join("nested/file2.bin"), vec![0x33u8; 8192]).unwrap();

        let create_opt = TTZipCreateOptions {
            format: TTZipArchiveFormat::Zip,
            level: TTZipCompressionLevel::Store,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 4,
            solid_block_size_mb: 0,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let report = create_zip_archive(&temp_dst_zip, &[temp_src.clone()], &create_opt).unwrap();
        assert_eq!(report.total_entries, 4); // root dir + nested dir + 2 files

        let zip_bytes = fs::read(&temp_dst_zip).unwrap();
        let archive = ZipArchive::open_slice(&zip_bytes).unwrap();
        assert_eq!(archive.len(), 4);

        let extract_opt = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 4,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let ext_report = archive.extract_all(&temp_extract, &extract_opt).unwrap();
        assert_eq!(ext_report.processed_entries_count, 4);

        let c1 = fs::read(temp_extract.join("ttzip_test_store_src/file1.txt")).unwrap();
        assert_eq!(c1, b"Hello Store Stream!");

        let c2 = fs::read(temp_extract.join("ttzip_test_store_src/nested/file2.bin")).unwrap();
        assert_eq!(c2, vec![0x33u8; 8192]);

        let _ = fs::remove_dir_all(&temp_src);
        let _ = fs::remove_file(&temp_dst_zip);
        let _ = fs::remove_dir_all(&temp_extract);
    }
}
