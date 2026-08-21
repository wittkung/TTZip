// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Creation, extraction, split volume, cancellation, and repair unit tests for Unified Orchestrator.

#[cfg(test)]
mod tests {
    use crate::archive::split::detect_volume_chain;
    use crate::archive::unified::UnifiedArchiveOrchestrator;
    use crate::types::{
        TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
        TTZipExtractOptions, TTZipStatus,
    };
    use libc::c_void;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_unified_create_and_extract_roundtrip_zip() {
        let dir = tempdir().unwrap();
        let src_file = dir.path().join("hello.txt");
        fs::write(&src_file, b"Hello Unified Archive Engine!").unwrap();

        let zip_out = dir.path().join("test.zip");
        let extract_out = dir.path().join("extracted_zip");

        let create_opt = TTZipCreateOptions {
            format: TTZipArchiveFormat::Zip,
            level: TTZipCompressionLevel::Normal,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 0,
            solid_block_size_mb: 0,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::create_archive(
            &[src_file],
            &zip_out,
            &create_opt,
            0,
        )
        .expect("Create zip failed");

        assert!(zip_out.exists());

        let extract_opt = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 0,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::extract_archive(
            &zip_out,
            &extract_out,
            &extract_opt,
        )
        .expect("Extract zip failed");

        let restored_file = extract_out.join("hello.txt");
        assert!(restored_file.exists());
        assert_eq!(
            fs::read(&restored_file).unwrap(),
            b"Hello Unified Archive Engine!"
        );
    }

    #[test]
    fn test_unified_create_and_extract_tar_variants() {
        let dir = tempdir().unwrap();
        let src_file = dir.path().join("payload.dat");
        fs::write(&src_file, b"TAR.GZ payload data content").unwrap();

        let variants = [
            (TTZipArchiveFormat::TarGz, "archive.tar.gz"),
            (TTZipArchiveFormat::TarBz2, "archive.tar.bz2"),
            (TTZipArchiveFormat::TarXz, "archive.tar.xz"),
            (TTZipArchiveFormat::TarZstd, "archive.tar.zst"),
        ];

        for (fmt, filename) in variants {
            let out_archive = dir.path().join(filename);
            let extract_dir = dir.path().join(format!("ext_{}", filename));

            let create_opt = TTZipCreateOptions {
                format: fmt,
                level: TTZipCompressionLevel::Fast,
                encryption: TTZipEncryptionMethod::None,
                password: std::ptr::null(),
                thread_budget: 0,
                solid_block_size_mb: 0,
                progress_callback: None,
                user_data: std::ptr::null_mut(),
            };

            UnifiedArchiveOrchestrator::create_archive(
                &[src_file.clone()],
                &out_archive,
                &create_opt,
                0,
            )
            .unwrap_or_else(|_| panic!("Failed to create {}", filename));

            assert!(out_archive.exists());

            let extract_opt = TTZipExtractOptions {
                destination_path: std::ptr::null(),
                password: std::ptr::null(),
                thread_budget: 0,
                overwrite_existing: true,
                preserve_permissions: true,
                dry_run: false,
                progress_callback: None,
                user_data: std::ptr::null_mut(),
            };

            UnifiedArchiveOrchestrator::extract_archive(
                &out_archive,
                &extract_dir,
                &extract_opt,
            )
            .unwrap_or_else(|_| panic!("Failed to extract {}", filename));

            let restored = extract_dir.join("payload.dat");
            assert!(restored.exists());
            assert_eq!(fs::read(&restored).unwrap(), b"TAR.GZ payload data content");
        }
    }

    #[test]
    fn test_unified_split_volume_creation_and_extraction() {
        let dir = tempdir().unwrap();
        let payload_file = dir.path().join("large_payload.bin");
        let payload_data = vec![0x77u8; 3000];
        fs::write(&payload_file, &payload_data).unwrap();

        let split_out = dir.path().join("archive.zip");
        let create_opt = TTZipCreateOptions {
            format: TTZipArchiveFormat::Zip,
            level: TTZipCompressionLevel::Store,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 0,
            solid_block_size_mb: 0,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::create_archive(
            &[payload_file],
            &split_out,
            &create_opt,
            1000,
        )
        .expect("Split create failed");

        let chain = detect_volume_chain(&split_out).expect("detect volume chain");
        assert!(chain.len() >= 2);

        let ext_dir = dir.path().join("split_extracted");
        let extract_opt = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 0,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::extract_archive(
            &chain[0],
            &ext_dir,
            &extract_opt,
        )
        .expect("Split extract failed");

        let restored = ext_dir.join("large_payload.bin");
        assert!(restored.exists());
        assert_eq!(fs::read(&restored).unwrap(), payload_data);
    }

    #[test]
    fn test_unified_repair_damaged_archive() {
        let dir = tempdir().unwrap();
        let payload_file = dir.path().join("repair_source.txt");
        fs::write(&payload_file, b"Repairable Payload Data Content").unwrap();

        let zip_path = dir.path().join("corrupt.zip");
        let repaired_path = dir.path().join("repaired.zip");

        let create_opt = TTZipCreateOptions {
            format: TTZipArchiveFormat::Zip,
            level: TTZipCompressionLevel::Store,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 0,
            solid_block_size_mb: 0,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::create_archive(
            &[payload_file],
            &zip_path,
            &create_opt,
            0,
        )
        .expect("Create zip");

        let data = fs::read(&zip_path).unwrap();
        let truncated_len = data.len().saturating_sub(22);
        fs::write(&zip_path, &data[..truncated_len]).unwrap();

        let salvaged = UnifiedArchiveOrchestrator::repair_archive(&zip_path, &repaired_path)
            .expect("Repair archive");
        assert!(salvaged >= 1);
        assert!(repaired_path.exists());
    }

    #[test]
    fn test_unified_cancellation_callback() {
        let dir = tempdir().unwrap();
        let f1 = dir.path().join("cancel1.txt");
        let f2 = dir.path().join("cancel2.txt");
        fs::write(&f1, b"File 1 content").unwrap();
        fs::write(&f2, b"File 2 content").unwrap();

        let zip_out = dir.path().join("cancelled.zip");

        unsafe extern "C" fn cancel_cb(
            _proc: u64,
            _tot: u64,
            _entry: *const libc::c_char,
            _user_data: *mut c_void,
        ) -> bool {
            false
        }

        let create_opt = TTZipCreateOptions {
            format: TTZipArchiveFormat::Zip,
            level: TTZipCompressionLevel::Normal,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 0,
            solid_block_size_mb: 0,
            progress_callback: Some(cancel_cb),
            user_data: std::ptr::null_mut(),
        };

        let res = UnifiedArchiveOrchestrator::create_archive(
            &[f1, f2],
            &zip_out,
            &create_opt,
            0,
        );

        assert_eq!(res, Err(TTZipStatus::Cancelled));
    }
}
