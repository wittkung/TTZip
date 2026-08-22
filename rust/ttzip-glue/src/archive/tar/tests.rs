// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unit tests for pure Rust TAR (POSIX ustar, GNU, PAX) parser and generator.

use crate::archive::tar::header::*;
use crate::archive::tar::reader::*;
use crate::archive::tar::writer::*;
use crate::types::TTZipExtractOptions;
use std::fs;

    #[test]
    fn test_tar_header_checksum_and_octal_roundtrip() {
        let header = TarHeader {
            name: "test/hello.txt".to_string(),
            mode: 0o644,
            uid: 501,
            gid: 20,
            size: 1024,
            mtime: 1700000000,
            chksum: 0,
            typeflag: TYPE_REGULAR,
            linkname: "".to_string(),
            magic: *MAGIC_USTAR,
            version: *VERSION_USTAR,
            uname: "ttzip".to_string(),
            gname: "staff".to_string(),
            devmajor: 0,
            devminor: 0,
            prefix: "".to_string(),
        };

        let block = build_tar_header_block(&header);
        assert!(verify_tar_checksum(&block));

        let parsed = parse_tar_header_block(&block).expect("parse header");
        assert_eq!(parsed.name, "test/hello.txt");
        assert_eq!(parsed.mode, 0o644);
        assert_eq!(parsed.uid, 501);
        assert_eq!(parsed.gid, 20);
        assert_eq!(parsed.size, 1024);
        assert_eq!(parsed.mtime, 1700000000);
        assert_eq!(parsed.typeflag, TYPE_REGULAR);
    }

    #[test]
    fn test_gnu_longname_and_longlink_scanning() {
        let mut archive_bytes = Vec::new();

        let long_path = "nested/deeply/embedded/directory/structure/with/a/very/long/filename_that_exceeds_one_hundred_characters_easily_1234567890.txt";
        let long_link = "target/deeply/nested/symlink/destination/that_also_exceeds_one_hundred_characters_in_total_length_for_tar.txt";

        // 1. GNU LongName header & payload
        let gnu_name_hdr = TarHeader {
            name: "././@LongLink".to_string(),
            mode: 0,
            uid: 0,
            gid: 0,
            size: (long_path.len() + 1) as u64,
            mtime: 0,
            chksum: 0,
            typeflag: TYPE_GNU_LONGNAME,
            linkname: "".to_string(),
            magic: *MAGIC_GNU,
            version: *b"  ",
            uname: "".to_string(),
            gname: "".to_string(),
            devmajor: 0,
            devminor: 0,
            prefix: "".to_string(),
        };
        archive_bytes.extend_from_slice(&build_tar_header_block(&gnu_name_hdr));
        let mut name_payload = long_path.as_bytes().to_vec();
        name_payload.push(0);
        let pad = (512 - (name_payload.len() % 512)) % 512;
        name_payload.extend(vec![0u8; pad]);
        archive_bytes.extend_from_slice(&name_payload);

        // 2. GNU LongLink header & payload
        let gnu_link_hdr = TarHeader {
            name: "././@LongLink".to_string(),
            mode: 0,
            uid: 0,
            gid: 0,
            size: (long_link.len() + 1) as u64,
            mtime: 0,
            chksum: 0,
            typeflag: TYPE_GNU_LONGLINK,
            linkname: "".to_string(),
            magic: *MAGIC_GNU,
            version: *b"  ",
            uname: "".to_string(),
            gname: "".to_string(),
            devmajor: 0,
            devminor: 0,
            prefix: "".to_string(),
        };
        archive_bytes.extend_from_slice(&build_tar_header_block(&gnu_link_hdr));
        let mut link_payload = long_link.as_bytes().to_vec();
        link_payload.push(0);
        let pad_link = (512 - (link_payload.len() % 512)) % 512;
        link_payload.extend(vec![0u8; pad_link]);
        archive_bytes.extend_from_slice(&link_payload);

        // 3. Main entry header
        let file_content = b"Content inside long path file!";
        let main_hdr = TarHeader {
            name: long_path[..100].to_string(),
            mode: 0o644,
            uid: 1000,
            gid: 1000,
            size: file_content.len() as u64,
            mtime: 1700000000,
            chksum: 0,
            typeflag: TYPE_SYMLINK,
            linkname: long_link[..100].to_string(),
            magic: *MAGIC_GNU,
            version: *b"  ",
            uname: "user".to_string(),
            gname: "user".to_string(),
            devmajor: 0,
            devminor: 0,
            prefix: "".to_string(),
        };
        archive_bytes.extend_from_slice(&build_tar_header_block(&main_hdr));
        let mut file_payload = file_content.to_vec();
        let pad_file = (512 - (file_payload.len() % 512)) % 512;
        file_payload.extend(vec![0u8; pad_file]);
        archive_bytes.extend_from_slice(&file_payload);

        // 4. End-of-Archive 1024 zero bytes
        archive_bytes.extend_from_slice(&[0u8; 1024]);

        let archive = TarArchive::open_slice(&archive_bytes).expect("open tar archive");
        assert_eq!(archive.len(), 1);
        let entry = &archive.entries()[0];
        assert_eq!(entry.path.as_ref(), long_path);
        assert_eq!(entry.link_target.as_deref(), Some(long_link));
        assert_eq!(entry.size, file_content.len() as u64);
        assert!(entry.is_symlink);

        let data = archive.extract_entry_bytes(0).expect("extract data");
        assert_eq!(data, file_content);
    }

    #[test]
    fn test_pax_large_file_and_extended_attributes() {
        let mut archive_bytes = Vec::new();
        let mut writer = TarWriter::new(&mut archive_bytes);

        let long_path = "directory/very_long_path_name_with_lots_of_characters_to_force_pax_extended_header_generation_abcdefghijklmnopqrstuvwxyz.bin";
        let payload = vec![0xABu8; 4096];

        writer.append_file(long_path, &payload, 0o755, 1700000000).expect("append file");
        writer.append_dir("empty_folder", 0o755, 1700000000).expect("append dir");
        writer.append_symlink("my_symlink", "target/destination.txt", 0o777, 1700000000).expect("append symlink");
        writer.finish().expect("finish archive");

        let archive = TarArchive::open_slice(&archive_bytes).expect("open slice");
        assert_eq!(archive.len(), 3);

        assert_eq!(archive.entries()[0].path.as_ref(), long_path);
        assert_eq!(archive.entries()[0].size, 4096);
        assert_eq!(archive.entries()[0].mode, 0o755);

        assert_eq!(archive.entries()[1].path.as_ref(), "empty_folder/");
        assert!(archive.entries()[1].is_directory);

        assert_eq!(archive.entries()[2].path.as_ref(), "my_symlink");
        assert!(archive.entries()[2].is_symlink);
        assert_eq!(archive.entries()[2].link_target.as_deref(), Some("target/destination.txt"));

        let bytes = archive.extract_entry_bytes(0).expect("extract 0");
        assert_eq!(bytes, payload);
    }

    #[test]
    fn test_tar_extract_all_to_disk() {
        let mut archive_bytes = Vec::new();
        let mut writer = TarWriter::new(&mut archive_bytes);

        writer.append_file("folder/sample.txt", b"Hello from pure Rust TAR engine!", 0o644, 1700000000).unwrap();
        writer.append_file("folder/sub/data.bin", &[1, 2, 3, 4, 5], 0o600, 1700000000).unwrap();
        writer.finish().unwrap();

        let temp_dir = std::env::temp_dir().join("ttzip_tar_test_extract");
        let _ = fs::remove_dir_all(&temp_dir);

        let archive = TarArchive::open_slice(&archive_bytes).unwrap();
        let options = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 2,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let report = archive.extract_all(&temp_dir, &options).unwrap();
        assert_eq!(report.processed_entries_count, 2);

        let content1 = fs::read(temp_dir.join("folder/sample.txt")).unwrap();
        assert_eq!(content1, b"Hello from pure Rust TAR engine!");

        let content2 = fs::read(temp_dir.join("folder/sub/data.bin")).unwrap();
        assert_eq!(content2, vec![1, 2, 3, 4, 5]);

        let _ = fs::remove_dir_all(&temp_dir);
    }
