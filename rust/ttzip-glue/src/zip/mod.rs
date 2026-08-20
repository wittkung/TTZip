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
}
