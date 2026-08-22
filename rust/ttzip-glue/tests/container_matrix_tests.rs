// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Container Format Matrix Integration Tests (Feature 186 - Task T002).
//!
//! Validates:
//! - 17 archive/compression format sniffing, magic identification, and compound/SFX extensions.
//! - Unified container creation, inspection, and extraction across ZIP, TAR, TAR.GZ, TAR.BZ2, TAR.XZ, TAR.ZSTD, and 7z.
//! - Pure codec framed streams (Snappy framed, Brotli streaming, LZ4, Apple LZFSE).
//! - Multi-volume split & merge (.001, .z01) with virtual continuous reading, seeking, and reassembly.
//! - ZipCrypto legacy and WinZip AES-256 hardware-accelerated encryption roundtrips.

use std::ffi::CString;
use std::fs;
use std::io::{Read, Seek, SeekFrom, Write};
use tempfile::tempdir;

use ttzip_glue::archive::split::{
    detect_volume_chain, SplitVolumeWriter, VirtualMultiVolumeReader, VolumeNamingScheme,
};
use ttzip_glue::archive::unified::UnifiedArchiveOrchestrator;
use ttzip_glue::codecs::brotli::{brotli_compress_to_vec, brotli_decompress_to_vec};
use ttzip_glue::codecs::fast_blocks::{
    lz4_compress, lz4_compress_bound, lz4_decompress, lzfse_compress, lzfse_decompress,
};
use ttzip_glue::codecs::snappy::{snappy_frame_decode_to_vec, snappy_frame_encode_to_vec};
use ttzip_glue::crypto::sha1::{winzip_aes256_decrypt_and_verify, winzip_aes256_encrypt_and_tag};
use ttzip_glue::crypto::zipcrypto::ZipCryptoKeys;
use ttzip_glue::ffi::archive_ffi::split::*;
use ttzip_glue::sevenz::{create_7z_solid_archive_bytes, SevenZArchive};
use ttzip_glue::standards::signatures::{CompoundFormat, DetectedFormat};
use ttzip_glue::standards::sniffer::detect_format_buffer;
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipExtractOptions, TTZipStatus,
};
use ttzip_glue::zip::{
    assemble_zip_archive, compress_items_parallel, parse_all_entries, ZipArchive, ZipInputItem,
};

#[test]
fn test_17_formats_sniffing_and_sfx_matrix() {
    let mut wim_buf = vec![0u8; 208];
    wim_buf[0..8].copy_from_slice(b"MSWIM\x00\x00\x00");

    let sniff_matrix: Vec<(&[u8], Option<&str>, DetectedFormat)> = vec![
        (b"7z\xBC\xAF\x27\x1C\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::SevenZip),
        (b"\xFD7zXZ\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Xz),
        (b"Rar!\x1A\x07\x01\x00", None, DetectedFormat::Rar),
        (b"Rar!\x1A\x07\x00", None, DetectedFormat::Rar),
        (b"\x28\xB5\x2F\xFD\x20\x00", None, DetectedFormat::Zstd),
        (b"xar!\x00\x1C\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01", None, DetectedFormat::Xar),
        (&wim_buf, None, DetectedFormat::Wim),
        (b"MSCF\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Cab),
        (b"!<arch>\n`\n\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Ar),
        (b"\xFF\x06\x00\x00sNaPpY", None, DetectedFormat::Snappy),
        (b"LZIP\x01\x00", None, DetectedFormat::Lzip),
        (b"LRZI\x00\x00", None, DetectedFormat::Lrzip),
        (b"AA01\x00\x00", None, DetectedFormat::Aar),
        (b"AEA1\x00\x00", None, DetectedFormat::Aar),
        (b"\x04\x22\x4D\x18\x60\x70\x73", None, DetectedFormat::Lz4),
        (b"bvx-\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Lzfse),
        (b"PK\x03\x04\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Zip),
        (b"\x1F\x8B\x08\x00\x00\x00\x00\x00\x02\x03", None, DetectedFormat::Gzip),
        (b"BZh91AY&SY\x00\x00\x00\x00", None, DetectedFormat::Bzip2),
    ];

    for (bytes, hint, expected) in sniff_matrix {
        let res = detect_format_buffer(bytes, hint);
        assert_eq!(res.format, expected, "Failed detecting magic for {:?}", expected);
    }

    // Compound TAR extension matrix
    let gz_magic = b"\x1F\x8B\x08\x00\x00\x00\x00\x00\x00\x03";
    let bz2_magic = b"BZh91AY&SY\x00\x00\x00\x00";
    let xz_magic = b"\xFD7zXZ\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    let zst_magic = b"\x28\xB5\x2F\xFD";
    let lz4_magic = b"\x04\x22\x4D\x18";

    assert_eq!(detect_format_buffer(gz_magic, Some("bundle.tar.gz")).compound_format, Some(CompoundFormat::TarGz));
    assert_eq!(detect_format_buffer(gz_magic, Some("bundle.tgz")).compound_format, Some(CompoundFormat::TarGz));
    assert_eq!(detect_format_buffer(bz2_magic, Some("bundle.tar.bz2")).compound_format, Some(CompoundFormat::TarBz2));
    assert_eq!(detect_format_buffer(bz2_magic, Some("bundle.tbz2")).compound_format, Some(CompoundFormat::TarBz2));
    assert_eq!(detect_format_buffer(xz_magic, Some("bundle.tar.xz")).compound_format, Some(CompoundFormat::TarXz));
    assert_eq!(detect_format_buffer(xz_magic, Some("bundle.txz")).compound_format, Some(CompoundFormat::TarXz));
    assert_eq!(detect_format_buffer(zst_magic, Some("bundle.tar.zst")).compound_format, Some(CompoundFormat::TarZstd));
    assert_eq!(detect_format_buffer(zst_magic, Some("bundle.tzst")).compound_format, Some(CompoundFormat::TarZstd));
    assert_eq!(detect_format_buffer(lz4_magic, Some("bundle.tar.lz4")).compound_format, Some(CompoundFormat::TarLz4));

    // Self-Extracting (SFX) archive detection
    let mut pe_stub = vec![0u8; 2048];
    pe_stub[0] = b'M';
    pe_stub[1] = b'Z';
    pe_stub[512..516].copy_from_slice(b"PK\x03\x04");

    let sfx_res = detect_format_buffer(&pe_stub, Some("installer.exe"));
    assert_eq!(sfx_res.format, DetectedFormat::Zip);
    assert!(sfx_res.is_sfx);
    assert_eq!(sfx_res.sfx_offset, 512);

    pe_stub[512..518].copy_from_slice(b"7z\xBC\xAF\x27\x1C");
    let sfx_7z = detect_format_buffer(&pe_stub, Some("setup.exe"));
    assert_eq!(sfx_7z.format, DetectedFormat::SevenZip);
    assert!(sfx_7z.is_sfx);
    assert_eq!(sfx_7z.sfx_offset, 512);
}

#[test]
fn test_container_creation_and_extraction_matrix() {
    let dir = tempdir().unwrap();
    let src_dir = dir.path().join("source_tree");
    fs::create_dir_all(&src_dir).unwrap();

    let f1 = src_dir.join("document.txt");
    let f2 = src_dir.join("payload.bin");
    fs::write(&f1, b"Matrix Testing Text Content 2026").unwrap();
    fs::write(&f2, vec![0x33u8; 16384]).unwrap();

    let sub = src_dir.join("nested_dir");
    fs::create_dir_all(&sub).unwrap();
    let f3 = sub.join("inner.dat");
    fs::write(&f3, b"Inner Nested Directory File Payload").unwrap();

    let formats_to_test = vec![
        (TTZipArchiveFormat::Zip, "test.zip"),
        (TTZipArchiveFormat::Tar, "test.tar"),
        (TTZipArchiveFormat::TarGz, "test.tar.gz"),
        (TTZipArchiveFormat::TarBz2, "test.tar.bz2"),
        (TTZipArchiveFormat::TarXz, "test.tar.xz"),
        (TTZipArchiveFormat::TarZstd, "test.tar.zst"),
    ];

    for (fmt, filename) in formats_to_test {
        let arch_path = dir.path().join(filename);
        let out_dir = dir.path().join(format!("out_{}", filename));

        let create_opt = TTZipCreateOptions {
            format: fmt,
            level: TTZipCompressionLevel::Normal,
            encryption: TTZipEncryptionMethod::None,
            password: std::ptr::null(),
            thread_budget: 2,
            solid_block_size_mb: 0,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::create_archive(&[src_dir.clone()], &arch_path, &create_opt, 0)
            .expect("Unified create archive failed");
        assert!(arch_path.exists());

        let extract_opt = TTZipExtractOptions {
            destination_path: std::ptr::null(),
            password: std::ptr::null(),
            thread_budget: 2,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        UnifiedArchiveOrchestrator::extract_archive(&arch_path, &out_dir, &extract_opt)
            .expect("Unified extract archive failed");

        // Verify extracted files
        let ext_f1 = out_dir.join("source_tree/document.txt");
        let ext_f2 = out_dir.join("source_tree/payload.bin");
        let ext_f3 = out_dir.join("source_tree/nested_dir/inner.dat");

        assert!(ext_f1.exists(), "Missing {} for format {:?}", ext_f1.display(), fmt);
        assert!(ext_f2.exists(), "Missing {} for format {:?}", ext_f2.display(), fmt);
        assert!(ext_f3.exists(), "Missing {} for format {:?}", ext_f3.display(), fmt);

        assert_eq!(fs::read(&ext_f1).unwrap(), b"Matrix Testing Text Content 2026");
        assert_eq!(fs::read(&ext_f2).unwrap(), vec![0x33u8; 16384]);
        assert_eq!(fs::read(&ext_f3).unwrap(), b"Inner Nested Directory File Payload");
    }

    // 7z Solid Stream Archive Matrix
    let sz_items = vec![
        ZipInputItem { rel_path: "sz_doc.txt".to_string(), data: b"7z Solid Stream File Alpha".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ZipInputItem { rel_path: "sz_data.bin".to_string(), data: vec![0x88u8; 8192], mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
    ];
    let sz_bytes = create_7z_solid_archive_bytes(&sz_items, 6, 2).expect("create 7z failed");
    let sz_archive = SevenZArchive::open_slice(&sz_bytes).expect("open 7z slice failed");
    assert_eq!(sz_archive.len(), 2);
    let sz_ext0 = sz_archive.extract_entry_bytes(0, None).expect("extract sz0");
    assert_eq!(sz_ext0, b"7z Solid Stream File Alpha");
    let sz_ext1 = sz_archive.extract_entry_bytes(1, None).expect("extract sz1");
    assert_eq!(sz_ext1, vec![0x88u8; 8192]);

    // Pure Codec Framed Streams
    let raw_sample = b"TTZip Hardware Accelerated Codec Framed Stream Matrix Validation 2026.";

    // 1. Snappy Framed
    let sn_framed = snappy_frame_encode_to_vec(raw_sample).unwrap();
    let sn_decoded = snappy_frame_decode_to_vec(&sn_framed, raw_sample.len() + 1024).unwrap();
    assert_eq!(sn_decoded, raw_sample);

    // 2. Brotli Streaming
    let br_encoded = brotli_compress_to_vec(raw_sample, 6, 22).unwrap();
    let br_decoded = brotli_decompress_to_vec(&br_encoded, raw_sample.len() + 1024).unwrap();
    assert_eq!(br_decoded, raw_sample);

    // 3. LZ4 Block
    let mut lz4_buf = vec![0u8; lz4_compress_bound(raw_sample.len())];
    let lz4_len = lz4_compress(raw_sample, &mut lz4_buf).unwrap();
    let mut lz4_dec = vec![0u8; raw_sample.len()];
    let lz4_dec_len = lz4_decompress(&lz4_buf[..lz4_len], &mut lz4_dec).unwrap();
    assert_eq!(lz4_dec_len, raw_sample.len());
    assert_eq!(&lz4_dec[..], raw_sample);

    // 4. Apple LZFSE
    let mut lzfse_buf = vec![0u8; raw_sample.len() + 1024];
    let lzfse_len = lzfse_compress(raw_sample, &mut lzfse_buf).unwrap();
    let mut lzfse_dec = vec![0u8; raw_sample.len()];
    let lzfse_dec_len = lzfse_decompress(&lzfse_buf[..lzfse_len], &mut lzfse_dec).unwrap();
    assert_eq!(lzfse_dec_len, raw_sample.len());
    assert_eq!(&lzfse_dec[..], raw_sample);
}

#[test]
fn test_multivolume_split_and_merge_matrix() {
    let dir = tempdir().unwrap();

    // 1. Numbered Extension Scheme (.001, .002, .003)
    let base_archive = dir.path().join("split_data.tar");
    let vol_size = 512u64;
    let mut writer = SplitVolumeWriter::new(&base_archive, vol_size, VolumeNamingScheme::NumberedExtension).unwrap();

    let mut payload = Vec::with_capacity(1600);
    for i in 0..1600 {
        payload.push((i * 17 % 256) as u8);
    }
    writer.write_all(&payload).unwrap();
    let volumes = writer.close().unwrap();

    assert_eq!(volumes.len(), 4); // 512, 512, 512, 62
    assert!(volumes[0].to_string_lossy().ends_with(".001"));
    assert!(volumes[1].to_string_lossy().ends_with(".002"));
    assert!(volumes[2].to_string_lossy().ends_with(".003"));
    assert!(volumes[3].to_string_lossy().ends_with(".004"));

    // Open reader starting from middle volume (.002) - validates auto chain discovery
    let mut reader = VirtualMultiVolumeReader::open_from_any_volume(&volumes[1]).unwrap();
    assert_eq!(reader.total_size(), 1600);
    assert_eq!(reader.volume_paths().len(), 4);

    let mut full_read = Vec::new();
    reader.read_to_end(&mut full_read).unwrap();
    assert_eq!(full_read, payload);

    // Cross-volume seek and read
    reader.seek(SeekFrom::Start(600)).unwrap(); // in volume 2
    let mut chunk = [0u8; 100];
    reader.read_exact(&mut chunk).unwrap();
    assert_eq!(&chunk[..], &payload[600..700]);

    reader.seek(SeekFrom::Start(1100)).unwrap(); // in volume 3
    let mut chunk2 = [0u8; 100];
    reader.read_exact(&mut chunk2).unwrap();
    assert_eq!(&chunk2[..], &payload[1100..1200]);

    // 2. PKZIP Spanned Scheme (.z01, .z02, .zip)
    let pkzip_base = dir.path().join("spanned.zip");
    let mut pk_writer = SplitVolumeWriter::new(&pkzip_base, 600, VolumeNamingScheme::PkzipSpanned).unwrap();
    pk_writer.write_all(&payload).unwrap();
    let pk_volumes = pk_writer.close().unwrap();

    assert_eq!(pk_volumes.len(), 3); // 600 (.z01), 600 (.z02), 400 (.zip)
    assert!(pk_volumes[0].to_string_lossy().ends_with(".z01"));
    assert!(pk_volumes[1].to_string_lossy().ends_with(".z02"));
    assert!(pk_volumes[2].to_string_lossy().ends_with(".zip"));

    let mut pk_reader = VirtualMultiVolumeReader::open_from_any_volume(&pk_volumes[2]).unwrap(); // Opened from .zip
    assert_eq!(pk_reader.total_size(), 1600);
    let mut pk_read = Vec::new();
    pk_reader.read_to_end(&mut pk_read).unwrap();
    assert_eq!(pk_read, payload);

    // 3. FFI Split and Join APIs
    let src_file = dir.path().join("orig.bin");
    let split_out = dir.path().join("split_ffi.dat");
    let joined_out = dir.path().join("joined_ffi.bin");
    fs::write(&src_file, &payload).unwrap();

    let c_src = CString::new(src_file.to_str().unwrap()).unwrap();
    let c_split = CString::new(split_out.to_str().unwrap()).unwrap();
    let c_joined = CString::new(joined_out.to_str().unwrap()).unwrap();

    unsafe {
        let st_split = ttzip_rust_split_file(
            c_src.as_ptr(),
            c_split.as_ptr(),
            500,
            VolumeNamingScheme::NumberedExtension as i32,
            true,
        );
        assert_eq!(st_split, TTZipStatus::Ok);

        let part1 = format!("{}.001", split_out.to_str().unwrap());
        let c_part1 = CString::new(part1).unwrap();
        let st_join = ttzip_rust_join_split_volumes(
            c_part1.as_ptr(),
            c_joined.as_ptr(),
            None,
            std::ptr::null_mut(),
        );
        assert_eq!(st_join, TTZipStatus::Ok);
        assert_eq!(fs::read(&joined_out).unwrap(), payload);
    }

    // 4. Unified Orchestrator Split Volume Archive Creation and Extraction
    let u_src_dir = dir.path().join("u_src");
    fs::create_dir_all(&u_src_dir).unwrap();
    let uncompressible: Vec<u8> = (0..8000).map(|i| (i * 37 % 256) as u8).collect();
    fs::write(u_src_dir.join("heavy.bin"), &uncompressible).unwrap();

    let u_dest_zip = dir.path().join("split_archive.zip");
    let create_opt = TTZipCreateOptions {
        format: TTZipArchiveFormat::Zip,
        level: TTZipCompressionLevel::Store,
        encryption: TTZipEncryptionMethod::None,
        password: std::ptr::null(),
        thread_budget: 2,
        solid_block_size_mb: 0,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    // Split size: 2000 bytes (8000 bytes payload will generate 4 volumes)
    UnifiedArchiveOrchestrator::create_archive(&[u_src_dir.clone()], &u_dest_zip, &create_opt, 2000)
        .expect("Create split volume archive failed");

    let chain = detect_volume_chain(&u_dest_zip).unwrap();
    assert!(chain.len() > 1);

    let u_out_dir = dir.path().join("u_extracted");
    let extract_opt = TTZipExtractOptions {
        destination_path: std::ptr::null(),
        password: std::ptr::null(),
        thread_budget: 2,
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    UnifiedArchiveOrchestrator::extract_archive(&u_dest_zip, &u_out_dir, &extract_opt)
        .expect("Extract split volume archive failed");

    assert_eq!(fs::read(u_out_dir.join("u_src/heavy.bin")).unwrap(), uncompressible);
}

#[test]
fn test_zipcrypto_and_winzip_aes_encryption_roundtrip() {
    let password = "SecureMatrixPassword_2026";
    let payload = b"Confidential High-Security Archive Content Payload with AES & ZipCrypto!";

    // 1. ZipCrypto Stream Cryptography Roundtrip
    let mut zipcrypto_keys = ZipCryptoKeys::from_password(password.as_bytes());
    let mut header = [0x55u8; 12];
    header[11] = 0xAA; // Check byte
    zipcrypto_keys.encrypt_slice(&mut header);

    let mut ciphertext = payload.to_vec();
    zipcrypto_keys.encrypt_slice(&mut ciphertext);
    assert_ne!(&ciphertext[..], payload);

    let mut dec_keys = ZipCryptoKeys::from_password(password.as_bytes());
    dec_keys.decrypt_slice(&mut header);
    assert_eq!(header[11], 0xAA);
    dec_keys.decrypt_slice(&mut ciphertext);
    assert_eq!(&ciphertext[..], payload);

    // ZipCrypto Full ZIP Archive Creation & Extraction
    let zc_items = vec![ZipInputItem {
        rel_path: "secret_legacy.txt".to_string(),
        data: payload.to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    }];
    let zc_comp = compress_items_parallel(zc_items, 6, TTZipEncryptionMethod::ZipCrypto, Some(password), 2).unwrap();
    let zc_zip = assemble_zip_archive(&zc_comp).unwrap();
    let zc_entries = parse_all_entries(&zc_zip).unwrap();
    assert_eq!(zc_entries.len(), 1);
    assert!(zc_entries[0].is_encrypted);

    // 2. WinZip AES-256 AE-2 Encryption & Decryption
    let salt = [0x99u8; 16];
    let mut enc_payload = Vec::new();
    winzip_aes256_encrypt_and_tag(password, &salt, payload, &mut enc_payload).unwrap();
    assert_eq!(enc_payload.len(), 16 + 2 + payload.len() + 10); // salt (16) + pv (2) + cipher + tag (10)

    let mut dec_storage = vec![0u8; payload.len()];
    let dec_len = winzip_aes256_decrypt_and_verify(password, &enc_payload, &mut dec_storage).unwrap();
    assert_eq!(dec_len, payload.len());
    assert_eq!(&dec_storage[..dec_len], payload);

    // Tampering test on WinZip AES-256
    let mut tampered_enc = enc_payload.clone();
    tampered_enc[20] ^= 0x01; // Tamper 1 bit in ciphertext
    let mut dec_tampered = vec![0u8; payload.len()];
    let err_tamper = winzip_aes256_decrypt_and_verify(password, &tampered_enc, &mut dec_tampered);
    assert_eq!(err_tamper, Err(TTZipStatus::ErrInvalidPassword));

    // Wrong password test on WinZip AES-256
    let err_wrong = winzip_aes256_decrypt_and_verify("IncorrectPassword_999", &enc_payload, &mut dec_tampered);
    assert_eq!(err_wrong, Err(TTZipStatus::ErrInvalidPassword));

    // 3. Full WinZip AES-256 Multi-File ZIP Archive Roundtrip
    let aes_items = vec![
        ZipInputItem { rel_path: "credentials.env".to_string(), data: b"DB_PASS=SuperSecret123".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o600, is_directory: false },
        ZipInputItem { rel_path: "data/config.json".to_string(), data: b"{\"encrypted\": true}".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
    ];

    let aes_comp = compress_items_parallel(aes_items, 6, TTZipEncryptionMethod::Aes256, Some(password), 4).unwrap();
    let aes_zip = assemble_zip_archive(&aes_comp).unwrap();

    let archive = ZipArchive::open_slice(&aes_zip).unwrap();
    assert_eq!(archive.len(), 2);
    assert!(archive.entries()[0].is_encrypted);
    assert_eq!(archive.entries()[0].compression_method, 99); // WinZip AES

    let ext0 = archive.extract_entry_bytes(0, Some(password)).unwrap();
    assert_eq!(ext0, b"DB_PASS=SuperSecret123");

    let ext1 = archive.extract_entry_bytes(1, Some(password)).unwrap();
    assert_eq!(ext1, b"{\"encrypted\": true}");

    // Reject incorrect password on entry extraction
    assert_eq!(archive.extract_entry_bytes(0, Some("WrongPass")), Err(TTZipStatus::ErrInvalidPassword));
    assert_eq!(archive.extract_entry_bytes(0, None), Err(TTZipStatus::ErrInvalidPassword));
}
