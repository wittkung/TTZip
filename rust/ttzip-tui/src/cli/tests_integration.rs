// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use super::*;
use std::fs;
use tempfile::tempdir;
use ttzip_glue::archive::tar::writer::TarWriter;
use ttzip_glue::codecs::brotli::brotli_compress_to_vec;
use ttzip_glue::codecs::snappy::snappy_frame_encode_to_vec;
use ttzip_glue::crypto::zipcrypto::ZipCryptoKeys;
use ttzip_glue::zip::writer::{assemble_zip_archive, ZipCompressedItem};

#[test]
fn test_headless_split_and_join_roundtrip() {
    let temp_dir = tempdir().expect("tempdir failed");
    let source_file = temp_dir.path().join("source_data.bin");
    let payload = vec![0x42u8; 2500];
    fs::write(&source_file, &payload).expect("write failed");

    let out_dir = temp_dir.path().join("volumes");
    let split_res = execute_split(&source_file, "1000B", Some(&out_dir), Some("numbered"));
    assert!(split_res.is_ok(), "execute_split failed: {:?}", split_res);

    let vol1 = out_dir.join("source_data.bin.001");
    let vol2 = out_dir.join("source_data.bin.002");
    let vol3 = out_dir.join("source_data.bin.003");
    assert!(vol1.exists());
    assert!(vol2.exists());
    assert!(vol3.exists());

    let joined_file = temp_dir.path().join("joined_data.bin");
    let join_res = execute_join(&vol1, &joined_file, false);
    assert!(join_res.is_ok(), "execute_join failed: {:?}", join_res);

    let joined_data = fs::read(&joined_file).expect("read joined failed");
    assert_eq!(joined_data, payload);
}

#[test]
fn test_headless_repair_damaged_zip_and_tar() {
    let temp_dir = tempdir().expect("tempdir failed");

    // 1. Repair ZIP
    let zip_item = ZipCompressedItem {
        rel_path: "salvaged_doc.txt".to_string(),
        uncompressed_size: 14,
        compressed_size: 14,
        crc32: 0x99887766,
        compression_method: 0,
        actual_method: 0,
        aes_strength: 0,
        payload: b"Salvaged Data!".to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
        is_encrypted: false,
    };
    let full_zip = assemble_zip_archive(&[zip_item]).unwrap();
    let truncated_zip = &full_zip[..30 + 16 + 14];

    let damaged_zip = temp_dir.path().join("damaged.zip");
    let repaired_zip = temp_dir.path().join("repaired.zip");
    fs::write(&damaged_zip, truncated_zip).unwrap();

    let rep_res = execute_repair(&damaged_zip, &repaired_zip, Some("zip"), true);
    assert!(rep_res.is_ok(), "execute_repair zip: {:?}", rep_res);
    assert!(repaired_zip.exists());

    // 2. Repair TAR
    let damaged_tar = temp_dir.path().join("damaged.tar");
    let repaired_tar = temp_dir.path().join("repaired.tar");
    let tar_file = fs::File::create(&damaged_tar).unwrap();
    let mut tar_writer = TarWriter::new(tar_file);
    tar_writer
        .append_file("tar_file.bin", b"Tar payload content", 0o644, 1700000000)
        .unwrap();
    tar_writer.finish().unwrap();

    let tar_rep_res = execute_repair(&damaged_tar, &repaired_tar, Some("tar"), false);
    assert!(tar_rep_res.is_ok(), "execute_repair tar: {:?}", tar_rep_res);
    assert!(repaired_tar.exists());
}

#[test]
fn test_snappy_and_brotli_format_detection_and_listing() {
    let temp_dir = tempdir().expect("tempdir failed");

    // 1. Snappy framed file
    let snappy_payload = b"Snappy compressed frame test data 2026";
    let snappy_encoded = snappy_frame_encode_to_vec(snappy_payload).unwrap();
    let sz_path = temp_dir.path().join("test_file.txt.sz");
    fs::write(&sz_path, &snappy_encoded).unwrap();

    let (fmt, entries) = parse_archive_entries(&sz_path, &snappy_encoded).unwrap();
    assert_eq!(fmt, ContainerFormat::Snappy);
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].name, "test_file.txt");
    assert_eq!(entries[0].uncompressed_size, snappy_payload.len() as u64);

    // 2. Brotli file
    let brotli_payload = b"Brotli compressed stream test data 2026";
    let brotli_encoded = brotli_compress_to_vec(brotli_payload, 5, 22).unwrap();
    let br_path = temp_dir.path().join("brotli_sample.dat.br");
    fs::write(&br_path, &brotli_encoded).unwrap();

    let (b_fmt, b_entries) = parse_archive_entries(&br_path, &brotli_encoded).unwrap();
    assert_eq!(b_fmt, ContainerFormat::Brotli);
    assert_eq!(b_entries.len(), 1);
    assert_eq!(b_entries[0].name, "brotli_sample.dat");
    assert_eq!(b_entries[0].uncompressed_size, brotli_payload.len() as u64);
}

#[test]
fn test_create_with_volume_size_and_transparent_chain_detection() {
    let temp_dir = tempdir().expect("tempdir failed");
    let source_file = temp_dir.path().join("large_payload.txt");
    let payload = vec![0xFEu8; 10000];
    fs::write(&source_file, &payload).unwrap();

    let base_archive = temp_dir.path().join("split_test.zip");
    let create_res = execute_create(
        &base_archive,
        &[source_file],
        Some("zip"),
        0,
        None,
        2,
        Some("2000B"),
    );
    assert!(create_res.is_ok(), "create_res split: {:?}", create_res);

    let vol1 = temp_dir.path().join("split_test.zip.001");
    assert!(vol1.exists());

    let chain = detect_volume_chain(&vol1).unwrap();
    assert!(chain.len() >= 2);

    let (_chain, combined_data) = read_archive_data_auto(&vol1).unwrap();
    let (fmt, entries) = parse_archive_entries(&vol1, &combined_data).unwrap();
    assert_eq!(fmt, ContainerFormat::Zip);
    assert_eq!(entries.len(), 1);
}

#[test]
fn test_headless_recover_zipcrypto() {
    let temp_dir = tempdir().expect("tempdir failed");

    let correct_pwd = "ZipSecretPassword2026";
    let mut keys = ZipCryptoKeys::from_password(correct_pwd.as_bytes());
    let mut enc_payload = vec![0u8; 12 + 10];
    let plain_header = [1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x77];
    for i in 0..12 {
        enc_payload[i] = keys.encrypt_byte(plain_header[i]);
    }
    for i in 0..10 {
        enc_payload[12 + i] = keys.encrypt_byte(b"SecretText"[i]);
    }

    let zip_item = ZipCompressedItem {
        rel_path: "confidential.txt".to_string(),
        uncompressed_size: 10,
        compressed_size: enc_payload.len() as u64,
        crc32: 0x77000000,
        compression_method: 0,
        actual_method: 0,
        aes_strength: 0,
        payload: enc_payload,
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
        is_encrypted: true,
    };
    let zip_bytes = assemble_zip_archive(&[zip_item]).unwrap();
    let enc_zip_path = temp_dir.path().join("encrypted.zip");
    fs::write(&enc_zip_path, &zip_bytes).unwrap();

    let dict_path = temp_dir.path().join("wordlist.txt");
    fs::write(&dict_path, "123456\nadmin\nZipSecretPassword2026\nqwerty\n").unwrap();

    let rec_res = execute_recover(&enc_zip_path, &dict_path, Some(4), true);
    assert!(rec_res.is_ok(), "execute_recover failed: {:?}", rec_res);
}
