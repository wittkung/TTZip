// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use super::*;
use clap::Parser;
use std::fs;
use std::path::PathBuf;
use tempfile::tempdir;

#[test]
fn test_format_bytes() {
    assert_eq!(format_bytes(18), "18 B");
    assert_eq!(format_bytes(1024), "1.0 KB");
    assert_eq!(format_bytes(1024 * 1024), "1.0 MB");
    assert_eq!(format_bytes(1024 * 1024 * 1024), "1.00 GB");
}

#[test]
fn test_cli_parsing_subcommands() {
    let cli = Cli::parse_from(["ttzip", "list", "test.zip"]);
    match cli.command {
        Some(Commands::List { archive, json, .. }) => {
            assert_eq!(archive, PathBuf::from("test.zip"));
            assert!(!json);
        }
        _ => panic!("Expected List subcommand"),
    }

    let cli_json = Cli::parse_from(["ttzip", "l", "test.7z", "--json"]);
    match cli_json.command {
        Some(Commands::List { archive, json, .. }) => {
            assert_eq!(archive, PathBuf::from("test.7z"));
            assert!(json);
        }
        _ => panic!("Expected List subcommand with alias l"),
    }

    let cli_extract = Cli::parse_from(["ttzip", "extract", "test.zip", "-o", "./out_dir", "-t", "8"]);
    match cli_extract.command {
        Some(Commands::Extract {
            archive,
            output,
            threads,
            ..
        }) => {
            assert_eq!(archive, PathBuf::from("test.zip"));
            assert_eq!(output, Some(PathBuf::from("./out_dir")));
            assert_eq!(threads, 8);
        }
        _ => panic!("Expected Extract subcommand"),
    }

    let cli_create = Cli::parse_from([
        "ttzip",
        "create",
        "out.7z",
        "file1.txt",
        "dir2",
        "-l",
        "9",
        "-f",
        "7z",
    ]);
    match cli_create.command {
        Some(Commands::Create {
            archive,
            sources,
            level,
            format,
            ..
        }) => {
            assert_eq!(archive, PathBuf::from("out.7z"));
            assert_eq!(sources, vec![PathBuf::from("file1.txt"), PathBuf::from("dir2")]);
            assert_eq!(level, 9);
            assert_eq!(format, Some("7z".to_string()));
        }
        _ => panic!("Expected Create subcommand"),
    }
}

#[test]
fn test_headless_create_list_extract_roundtrip_zip() {
    let temp_dir = tempdir().expect("tempdir failed");
    let source_file = temp_dir.path().join("sample.txt");
    fs::write(&source_file, b"Hello TTZip TUI headless test!").expect("write failed");

    let archive_file = temp_dir.path().join("test_archive.zip");
    let sources = vec![source_file.clone()];

    // 1. Create ZIP
    let create_res = execute_create(
        &archive_file,
        &sources,
        Some("zip"),
        6,
        None,
        2,
    );
    assert!(create_res.is_ok(), "create_res: {:?}", create_res);
    assert!(archive_file.exists());

    // 2. List ZIP (text)
    let list_res = execute_list(&archive_file, None, false);
    assert!(list_res.is_ok(), "list_res: {:?}", list_res);

    // 3. List ZIP (JSON conforming to TUIVfsTreeContract)
    let data = fs::read(&archive_file).expect("read failed");
    let (fmt, entries) = parse_archive_entries(&archive_file, &data).expect("parse failed");
    assert_eq!(fmt, ContainerFormat::Zip);
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].name, "sample.txt");
    assert_eq!(entries[0].uncompressed_size, 30);

    // 4. Extract ZIP
    let out_dir = temp_dir.path().join("extracted");
    let extract_res = execute_extract(&archive_file, Some(&out_dir), None, 2, false);
    assert!(extract_res.is_ok(), "extract_res: {:?}", extract_res);

    let extracted_file = out_dir.join("sample.txt");
    assert!(extracted_file.exists());
    let extracted_bytes = fs::read(&extracted_file).expect("read extracted failed");
    assert_eq!(extracted_bytes, b"Hello TTZip TUI headless test!");
}

#[test]
fn test_headless_create_list_extract_roundtrip_7z() {
    let temp_dir = tempdir().expect("tempdir failed");
    let source_file = temp_dir.path().join("doc.md");
    fs::write(&source_file, b"# 7z Compression Test in TTZip TUI").expect("write failed");

    let archive_file = temp_dir.path().join("test_archive.7z");
    let sources = vec![source_file.clone()];

    // 1. Create 7z
    let create_res = execute_create(
        &archive_file,
        &sources,
        Some("7z"),
        3,
        None,
        2,
    );
    assert!(create_res.is_ok(), "create_res 7z: {:?}", create_res);
    assert!(archive_file.exists());

    // 2. List 7z
    let list_res = execute_list(&archive_file, None, false);
    assert!(list_res.is_ok(), "list_res 7z: {:?}", list_res);

    // 3. Extract 7z
    let out_dir = temp_dir.path().join("extracted_7z");
    let extract_res = execute_extract(&archive_file, Some(&out_dir), None, 2, false);
    assert!(extract_res.is_ok(), "extract_res 7z: {:?}", extract_res);

    let extracted_file = out_dir.join("doc.md");
    assert!(extracted_file.exists());
    let extracted_bytes = fs::read(&extracted_file).expect("read extracted 7z failed");
    assert_eq!(extracted_bytes, b"# 7z Compression Test in TTZip TUI");
}
