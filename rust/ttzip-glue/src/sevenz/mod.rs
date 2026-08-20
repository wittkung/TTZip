// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Native 7-Zip (7z) Engine module.
//!
//! Provides zero-copy 7z header parsing, Solid stream selective decoding,
//! ARM64 8-way NEON AES-256-CBC hardware decryption with SHA-256 KDF,
//! and multi-threaded Fast-LZMA2 solid archive creation.

pub mod decoder;
pub mod format;
pub mod header;
pub mod writer;

pub use decoder::{decode_7z_solid_payload, SevenZArchive};
pub use format::{
    read_varint, write_varint, SevenZSignatureHeader, K_CODERS_UNPACK_SIZE, K_CRC, K_EMPTY_STREAM,
    K_END, K_ENCODED_HEADER, K_FILES_INFO, K_FOLDER, K_HEADER, K_MAIN_STREAMS_INFO, K_NAME,
    K_NUM_UNPACK_STREAM, K_PACK_INFO, K_SIZE, K_SUB_STREAMS_INFO, K_UNPACK_INFO, K_WIN_ATTRIBUTES,
    METHOD_AES, METHOD_COPY, METHOD_DEFLATE, METHOD_LZMA, METHOD_LZMA2, SEVENZ_SIGNATURE,
};
pub use header::{parse_7z_metadata, SevenZCoder, SevenZFileMeta, SevenZFolder, SevenZHeaderInfo};
pub use writer::{
    build_7z_metadata_header, create_7z_archive, create_7z_solid_archive_bytes,
};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::zip::writer::ZipInputItem;

    #[test]
    fn test_7z_solid_roundtrip_lzma2_and_store() {
        let items = vec![
            ZipInputItem {
                rel_path: "doc.txt".to_string(),
                data: b"Document content for 7z native Rust test.".to_vec(),
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
            ZipInputItem {
                rel_path: "assets/".to_string(),
                data: Vec::new(),
                mtime_epoch_secs: 1700000000,
                mode: 0o755,
                is_directory: true,
            },
            ZipInputItem {
                rel_path: "assets/data.bin".to_string(),
                data: vec![0x33u8; 8192],
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
        ];

        // Test LZMA2 level 3
        let archive_bytes = create_7z_solid_archive_bytes(&items, 3, 2).expect("7z creation failed");
        assert!(!archive_bytes.is_empty());

        let archive = SevenZArchive::open_slice(&archive_bytes).expect("7z open failed");
        assert_eq!(archive.len(), 3);

        let f0 = archive.extract_entry_bytes(0, None).expect("extract f0 failed");
        assert_eq!(f0, b"Document content for 7z native Rust test.");

        let f1 = archive.extract_entry_bytes(1, None).expect("extract f1 failed");
        assert!(f1.is_empty());

        let f2 = archive.extract_entry_bytes(2, None).expect("extract f2 failed");
        assert_eq!(f2, vec![0x33u8; 8192]);
    }
}
