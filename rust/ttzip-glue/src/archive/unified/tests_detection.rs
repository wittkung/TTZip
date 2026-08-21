// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format detection and non-destructive inspection unit tests for Unified Orchestrator.

#[cfg(test)]
mod tests {
    use crate::archive::unified::UnifiedArchiveOrchestrator;
    use crate::standards::signatures::DetectedFormat;
    use crate::types::{
        TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
        TTZipEntryMetadata,
    };
    use libc::c_void;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_unified_format_auto_detection_17_formats() {
        let dir = tempdir().unwrap();
        let samples = [
            ("sample.zip", b"PK\x03\x04\x14\x00\x00\x00".to_vec(), DetectedFormat::Zip),
            ("sample.7z", b"7z\xBC\xAF\x27\x1C\x00".to_vec(), DetectedFormat::SevenZip),
            ("sample.tar", {
                let mut b = vec![0u8; 512];
                b[257..263].copy_from_slice(b"ustar\0");
                b
            }, DetectedFormat::Tar),
            ("sample.tar.gz", b"\x1F\x8B\x08\x00\x00\x00\x00\x00".to_vec(), DetectedFormat::Gzip),
            ("sample.tar.bz2", b"BZh91AY&SY".to_vec(), DetectedFormat::Bzip2),
            ("sample.tar.xz", b"\xFD7zXZ\x00".to_vec(), DetectedFormat::Xz),
            ("sample.tar.zst", b"\x28\xB5\x2F\xFD".to_vec(), DetectedFormat::Zstd),
            ("sample.rar", b"Rar!\x1A\x07\x01\x00".to_vec(), DetectedFormat::Rar),
            ("sample.cab", b"MSCF\x00\x00\x00\x00".to_vec(), DetectedFormat::Cab),
            ("sample.xar", b"xar!".to_vec(), DetectedFormat::Xar),
            ("sample.ar", b"!<arch>\n".to_vec(), DetectedFormat::Ar),
            ("sample.sz", b"\xFF\x06\x00\x00sNaPpY".to_vec(), DetectedFormat::Snappy),
            ("sample.lz", b"LZIP\x01\x0c".to_vec(), DetectedFormat::Lzip),
            ("sample.lz4", b"\x04\x22\x4D\x18".to_vec(), DetectedFormat::Lz4),
            ("sample.lzfse", b"bvx-".to_vec(), DetectedFormat::Lzfse),
            ("sample.dmg", {
                let mut b = vec![0u8; 512];
                b[0..4].copy_from_slice(b"koly");
                b
            }, DetectedFormat::Dmg),
            ("sample.iso", {
                let mut b = vec![0u8; 32768 + 2048];
                b[0x8001..0x8001 + 5].copy_from_slice(b"CD001");
                b
            }, DetectedFormat::Iso),
        ];

        for (name, content, expected_fmt) in samples {
            let file_path = dir.path().join(name);
            fs::write(&file_path, &content).unwrap();
            let (detected, _) = UnifiedArchiveOrchestrator::detect_format(&file_path).unwrap();
            assert_eq!(
                detected, expected_fmt,
                "Format mismatch for {}",
                name
            );
        }
    }

    #[test]
    fn test_unified_inspect_metadata_callback() {
        let dir = tempdir().unwrap();
        let f1 = dir.path().join("doc1.txt");
        let f2 = dir.path().join("doc2.txt");
        fs::write(&f1, b"File 1 bytes").unwrap();
        fs::write(&f2, b"File 2 bytes content").unwrap();

        let zip_out = dir.path().join("inspect_test.zip");
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
            &[f1, f2],
            &zip_out,
            &create_opt,
            0,
        )
        .unwrap();

        use std::sync::atomic::{AtomicUsize, Ordering};
        static SEEN_COUNT: AtomicUsize = AtomicUsize::new(0);
        SEEN_COUNT.store(0, Ordering::SeqCst);

        unsafe extern "C" fn inspect_cb(
            entry: *const TTZipEntryMetadata,
            _user_data: *mut c_void,
        ) -> bool {
            if !entry.is_null() {
                SEEN_COUNT.fetch_add(1, Ordering::SeqCst);
            }
            true
        }

        let count = UnifiedArchiveOrchestrator::inspect_archive(
            &zip_out,
            None,
            true,
            Some(inspect_cb),
            std::ptr::null_mut(),
        )
        .unwrap();

        assert_eq!(count, 2);
        assert_eq!(SEEN_COUNT.load(Ordering::SeqCst), 2);
    }
}
