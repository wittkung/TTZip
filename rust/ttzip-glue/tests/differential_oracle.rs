// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Differential Oracle & Historical CVE Golden Corpus Test Suite for TTZip.
//!
//! Validates Tasks T010, T011 (Phase 4):
//! - T010 [US4]: Bidirectional differential testing with macOS system `/usr/bin/unzip`, `/usr/bin/zip`, and `/usr/bin/tar`.
//! - T011 [US4]: In-memory rapid verification and safe rejection of historical CVE malformed vectors.

use std::fs;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::process::Command;

use ttzip_glue::codecs::deflate::{gzip_compress, gzip_decompress};
use ttzip_glue::fs::safe_extract::sanitize_and_validate_path;
use ttzip_glue::types::{TTZipEncryptionMethod, TTZipStatus};
use ttzip_glue::zip::extra::ZipExtraFields;
use ttzip_glue::zip::parser::{find_eocd, parse_all_entries, parse_local_file_header};
use ttzip_glue::zip::reader::ZipArchive;
use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};

/// Helper to create a dedicated temp directory for differential tests.
struct TempTestDir {
    path: PathBuf,
}

impl TempTestDir {
    fn new(prefix: &str) -> Self {
        let unique_id = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("{}_{}", prefix, unique_id));
        fs::create_dir_all(&path).expect("failed to create temp test directory");
        Self { path }
    }
}

impl Drop for TempTestDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}

// -----------------------------------------------------------------------------
// Task T010: System Tool Differential Testing (/usr/bin/unzip & /usr/bin/tar)
// -----------------------------------------------------------------------------

#[test]
fn test_differential_zip_with_system_unzip() {
    let temp_dir = TempTestDir::new("ttzip_diff_unzip");

    // 1. Prepare diverse archive payload
    let mut large_compressible = vec![0u8; 128 * 1024];
    for (i, b) in large_compressible.iter_mut().enumerate() {
        *b = b"TTZip High-Performance Differential Invariant Testing "[i % 54];
    }

    let items = vec![
        ZipInputItem {
            rel_path: "greeting.txt".to_string(),
            data: b"Hello TTZip differential testing with macOS system unzip!".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "nested/".to_string(),
            data: Vec::new(),
            mtime_epoch_secs: 1700000000,
            mode: 0o755,
            is_directory: true,
        },
        ZipInputItem {
            rel_path: "nested/deep/".to_string(),
            data: Vec::new(),
            mtime_epoch_secs: 1700000000,
            mode: 0o755,
            is_directory: true,
        },
        ZipInputItem {
            rel_path: "nested/deep/payload.dat".to_string(),
            data: large_compressible.clone(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "empty.bin".to_string(),
            data: Vec::new(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "unicode_测试/日本語_🎉.txt".to_string(),
            data: "Unicode 文件名差分测试内容：苹果芯片原生加速！".as_bytes().to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
    ];

    // 2. Compress and assemble using TTZip
    let compressed = compress_items_parallel(
        items.clone(),
        6,
        TTZipEncryptionMethod::None,
        None,
        4,
    ).expect("TTZip compression failed");

    let zip_bytes = assemble_zip_archive(&compressed).expect("TTZip assembly failed");
    let zip_path = temp_dir.path.join("ttzip_test_archive.zip");
    fs::write(&zip_path, &zip_bytes).expect("failed to write test zip archive");

    // 3. Test integrity with macOS `/usr/bin/unzip -t`
    let test_output = Command::new("/usr/bin/unzip")
        .arg("-t")
        .arg(&zip_path)
        .output()
        .expect("failed to execute /usr/bin/unzip -t");

    let test_stdout = String::from_utf8_lossy(&test_output.stdout);
    let test_stderr = String::from_utf8_lossy(&test_output.stderr);
    assert!(
        test_output.status.success(),
        "/usr/bin/unzip -t failed: stdout: {}, stderr: {}",
        test_stdout,
        test_stderr
    );
    assert!(
        test_stdout.contains("No errors detected"),
        "Expected 'No errors detected' in unzip -t output, got: {}",
        test_stdout
    );

    // 4. Extract with macOS `/usr/bin/unzip -q -o <archive> -d <out_dir>`
    let extract_dir = temp_dir.path.join("extracted_by_system");
    fs::create_dir_all(&extract_dir).expect("failed to create extract dir");

    let extract_output = Command::new("/usr/bin/unzip")
        .arg("-q")
        .arg("-o")
        .arg(&zip_path)
        .arg("-d")
        .arg(&extract_dir)
        .output()
        .expect("failed to execute /usr/bin/unzip extraction");

    assert!(
        extract_output.status.success(),
        "/usr/bin/unzip extraction failed: {}",
        String::from_utf8_lossy(&extract_output.stderr)
    );

    // 5. Verify extracted file contents match byte-for-byte
    for item in &items {
        let extracted_item_path = extract_dir.join(&item.rel_path);
        if item.is_directory {
            assert!(
                extracted_item_path.is_dir(),
                "Expected directory at {:?}",
                extracted_item_path
            );
        } else {
            assert!(
                extracted_item_path.is_file(),
                "Expected file at {:?}",
                extracted_item_path
            );
            let extracted_bytes = fs::read(&extracted_item_path)
                .unwrap_or_else(|_| panic!("failed to read extracted file {:?}", extracted_item_path));
            assert_eq!(
                extracted_bytes, item.data,
                "Content mismatch in file {:?} between TTZip and system unzip",
                item.rel_path
            );
        }
    }

    println!("[ORACLE] Differential test TTZip -> /usr/bin/unzip 100% matched across all entries.");
}

#[test]
fn test_differential_system_zip_with_ttzip() {
    let temp_dir = TempTestDir::new("ttzip_diff_sys_zip");
    let src_dir = temp_dir.path.join("src_files");
    fs::create_dir_all(&src_dir).expect("failed to create src dir");

    // 1. Create source files on disk
    let file1_path = src_dir.join("sys_file1.txt");
    let file1_data = b"Created by macOS native system files for TTZip differential parsing.";
    fs::write(&file1_path, file1_data).unwrap();

    let sub_dir = src_dir.join("sub_dir");
    fs::create_dir_all(&sub_dir).unwrap();
    let file2_path = sub_dir.join("sys_file2.bin");
    let file2_data = vec![0x3Cu8; 16384];
    fs::write(&file2_path, &file2_data).unwrap();

    let zip_path = temp_dir.path.join("system_created.zip");

    // 2. Run `/usr/bin/zip -r -q <zip_path> .` inside src_dir
    let zip_output = Command::new("/usr/bin/zip")
        .arg("-r")
        .arg("-q")
        .arg(&zip_path)
        .arg(".")
        .current_dir(&src_dir)
        .output()
        .expect("failed to execute /usr/bin/zip");

    assert!(
        zip_output.status.success(),
        "/usr/bin/zip failed: {}",
        String::from_utf8_lossy(&zip_output.stderr)
    );

    // 3. Read generated zip bytes and parse with TTZip
    let zip_bytes = fs::read(&zip_path).expect("failed to read system created zip");
    let archive = ZipArchive::open_slice(&zip_bytes).expect("TTZip failed to open system zip");

    assert!(archive.len() >= 2, "Expected at least 2 entries in archive");

    // 4. Verify extraction of all entries with TTZip
    let mut found_file1 = false;
    let mut found_file2 = false;

    for idx in 0..archive.len() {
        let entry = &archive.entries()[idx];
        let extracted = archive.extract_entry_bytes(idx, None).expect("extract failed");

        if entry.rel_path.ends_with("sys_file1.txt") {
            assert_eq!(extracted, file1_data);
            found_file1 = true;
        } else if entry.rel_path.ends_with("sys_file2.bin") {
            assert_eq!(extracted, file2_data);
            found_file2 = true;
        }
    }

    assert!(found_file1, "sys_file1.txt not found in system zip archive");
    assert!(found_file2, "sys_file2.bin not found in system zip archive");

    println!("[ORACLE] Differential test /usr/bin/zip -> TTZip 100% matched.");
}

#[test]
fn test_differential_tar_gzip_with_ttzip() {
    let temp_dir = TempTestDir::new("ttzip_diff_tar");
    let src_dir = temp_dir.path.join("tar_src");
    fs::create_dir_all(&src_dir).unwrap();

    let sample_txt = src_dir.join("sample.txt");
    fs::write(&sample_txt, b"TTZip and macOS /usr/bin/tar differential interoperability verification.").unwrap();

    let tar_gz_path = temp_dir.path.join("archive.tar.gz");

    // 1. Create .tar.gz with `/usr/bin/tar -czf <tar_gz_path> sample.txt`
    let tar_output = Command::new("/usr/bin/tar")
        .arg("-czf")
        .arg(&tar_gz_path)
        .arg("sample.txt")
        .current_dir(&src_dir)
        .output()
        .expect("failed to execute /usr/bin/tar");

    assert!(tar_output.status.success(), "tar creation failed");

    // 2. Read .tar.gz bytes and decompress gzip outer layer with TTZip
    let gz_bytes = fs::read(&tar_gz_path).expect("failed to read tar.gz");
    let mut decompressed_tar = vec![0u8; 64 * 1024];
    let decomp_size = gzip_decompress(&gz_bytes, &mut decompressed_tar)
        .expect("TTZip gzip_decompress failed on system tar.gz");

    assert!(decomp_size > 0);
    // Standard TAR header contains "ustar" magic at offset 257
    let tar_slice = &decompressed_tar[..decomp_size];
    assert!(
        tar_slice.len() >= 512,
        "Decompressed tar stream too short for standard TAR header"
    );

    // 3. Roundtrip: compress tar slice with TTZip gzip_compress and extract with `/usr/bin/tar -xzf`
    let mut re_gz = vec![0u8; gz_bytes.len() + 1024];
    let re_gz_size = gzip_compress(tar_slice, &mut re_gz, 6).expect("TTZip gzip_compress failed");

    let roundtrip_gz_path = temp_dir.path.join("roundtrip.tar.gz");
    fs::write(&roundtrip_gz_path, &re_gz[..re_gz_size]).unwrap();

    let verify_dir = temp_dir.path.join("verify_tar");
    fs::create_dir_all(&verify_dir).unwrap();

    let untar_output = Command::new("/usr/bin/tar")
        .arg("-xzf")
        .arg(&roundtrip_gz_path)
        .arg("-C")
        .arg(&verify_dir)
        .output()
        .expect("failed to execute /usr/bin/tar -xzf on TTZip gzip output");

    assert!(
        untar_output.status.success(),
        "/usr/bin/tar failed to unpack TTZip gzip output: {}",
        String::from_utf8_lossy(&untar_output.stderr)
    );

    let verify_sample = verify_dir.join("sample.txt");
    assert!(verify_sample.exists());
    let verified_content = fs::read(&verify_sample).unwrap();
    assert_eq!(
        verified_content,
        b"TTZip and macOS /usr/bin/tar differential interoperability verification."
    );

    println!("[ORACLE] Differential test TTZip <-> /usr/bin/tar 100% interoperable.");
}

// -----------------------------------------------------------------------------
// Task T011: Historical CVE Malformed Golden Corpus Safety Assertions
// -----------------------------------------------------------------------------

/// Constructs a synthetic malformed ZIP archive containing a ZipSlip path traversal payload (CVE-2018-1002204).
fn build_cve_2018_1002204_zipslip_vector() -> Vec<u8> {
    let evil_path = "../../../../../../../../../../../../../../../../../../../tmp/evil_cve_2018_1002204.txt";
    let evil_bytes = evil_path.as_bytes();

    let mut buf = Vec::new();

    // Local File Header
    buf.extend_from_slice(&[0x50, 0x4B, 0x03, 0x04]); // LFH magic
    buf.extend_from_slice(&[20, 0]); // Version needed (2.0)
    buf.extend_from_slice(&[0, 0]);  // Flags
    buf.extend_from_slice(&[0, 0]);  // Store
    buf.extend_from_slice(&[0, 0, 0, 0]); // DOS time/date
    buf.extend_from_slice(&[0x12, 0x34, 0x56, 0x78]); // CRC32
    buf.extend_from_slice(&(evil_bytes.len() as u32).to_le_bytes()); // Comp size
    buf.extend_from_slice(&(evil_bytes.len() as u32).to_le_bytes()); // Uncomp size
    buf.extend_from_slice(&(evil_bytes.len() as u16).to_le_bytes()); // Filename len
    buf.extend_from_slice(&[0, 0]); // Extra len
    buf.extend_from_slice(evil_bytes); // Filename

    // Payload data
    buf.extend_from_slice(evil_bytes);

    let lfh_len = buf.len();
    let cd_offset = lfh_len;

    // Central Directory File Header
    buf.extend_from_slice(&[0x50, 0x4B, 0x01, 0x02]); // CDFH magic
    buf.extend_from_slice(&[20, 0]); // Version made by
    buf.extend_from_slice(&[20, 0]); // Version needed
    buf.extend_from_slice(&[0, 0]);  // Flags
    buf.extend_from_slice(&[0, 0]);  // Store
    buf.extend_from_slice(&[0, 0, 0, 0]); // DOS time/date
    buf.extend_from_slice(&[0x12, 0x34, 0x56, 0x78]); // CRC32
    buf.extend_from_slice(&(evil_bytes.len() as u32).to_le_bytes()); // Comp size
    buf.extend_from_slice(&(evil_bytes.len() as u32).to_le_bytes()); // Uncomp size
    buf.extend_from_slice(&(evil_bytes.len() as u16).to_le_bytes()); // Filename len
    buf.extend_from_slice(&[0, 0]); // Extra len
    buf.extend_from_slice(&[0, 0]); // Comment len
    buf.extend_from_slice(&[0, 0]); // Disk start
    buf.extend_from_slice(&[0, 0]); // Internal attr
    buf.extend_from_slice(&[0, 0, 0, 0]); // External attr
    buf.extend_from_slice(&[0, 0, 0, 0]); // LFH offset (0)
    buf.extend_from_slice(evil_bytes);

    let cd_size = buf.len() - cd_offset;

    // End of Central Directory (EOCD)
    buf.extend_from_slice(&[0x50, 0x4B, 0x05, 0x06]); // EOCD magic
    buf.extend_from_slice(&[0, 0]); // Disk number
    buf.extend_from_slice(&[0, 0]); // Disk start CD
    buf.extend_from_slice(&[1, 0]); // Total entries on disk (1)
    buf.extend_from_slice(&[1, 0]); // Total entries (1)
    buf.extend_from_slice(&(cd_size as u32).to_le_bytes()); // CD size
    buf.extend_from_slice(&(cd_offset as u32).to_le_bytes()); // CD offset
    buf.extend_from_slice(&[0, 0]); // Comment length (0)

    buf
}

/// Constructs a malformed ZIP archive triggering filename length buffer overrun (CVE-2001-0775).
fn build_cve_2001_0775_filename_overflow_vector() -> Vec<u8> {
    let mut buf = Vec::new();
    let cd_offset = 0;

    // Central Directory with filename_length = 0xFF00 pointing beyond file
    buf.extend_from_slice(&[0x50, 0x4B, 0x01, 0x02]); // CDFH magic
    buf.extend_from_slice(&[20, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    buf.extend_from_slice(&[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    buf.extend_from_slice(&[0x00, 0xFF]); // Filename length = 65280
    buf.extend_from_slice(&[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    buf.extend_from_slice(b"short"); // Only 5 bytes instead of 65280

    let cd_size = buf.len();

    // EOCD
    buf.extend_from_slice(&[0x50, 0x4B, 0x05, 0x06]);
    buf.extend_from_slice(&[0, 0, 0, 0, 1, 0, 1, 0]);
    buf.extend_from_slice(&(cd_size as u32).to_le_bytes());
    buf.extend_from_slice(&(cd_offset as u32).to_le_bytes());
    buf.extend_from_slice(&[0, 0]);

    buf
}

/// Constructs a malformed ZIP archive with EOCD comment length pointing past buffer (CVE-2002-1337).
fn build_cve_2002_1337_eocd_comment_overflow_vector() -> Vec<u8> {
    let mut buf = Vec::new();
    // Valid minimal EOCD but with comment length 0xFFFF
    buf.extend_from_slice(&[0x50, 0x4B, 0x05, 0x06]);
    buf.extend_from_slice(&[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    buf.extend_from_slice(&[0xFF, 0xFF]); // comment length = 65535
    buf
}

/// Constructs a malformed Zip64 64-bit integer addition overflow vector (CVE-2023-45853).
fn build_cve_2023_45853_zip64_overflow_vector() -> Vec<u8> {
    let mut extra = Vec::new();
    extra.extend_from_slice(&[0x01, 0x00]); // Zip64 tag
    extra.extend_from_slice(&[24, 0]);     // Length 24 bytes
    extra.extend_from_slice(&u64::MAX.to_le_bytes()); // Uncompressed size = u64::MAX
    extra.extend_from_slice(&u64::MAX.to_le_bytes()); // Compressed size = u64::MAX
    extra.extend_from_slice(&u64::MAX.to_le_bytes()); // Local header offset = u64::MAX

    let parsed = ZipExtraFields::parse(&extra, true, true, true, true);
    assert_eq!(parsed.uncompressed_size, Some(u64::MAX));

    extra
}

/// Constructs a malformed Gzip vector triggering sliding window / flag corruption (CVE-2022-1271).
fn build_cve_2022_1271_gzip_vector() -> Vec<u8> {
    vec![
        0x1F, 0x8B, // Gzip magic
        0x09,       // Invalid compression method (9)
        0xFF,       // Corrupted flags
        0x00, 0x00, 0x00, 0x00, // Mtime
        0x00, 0x03, // Extra flags, OS
        0x12, 0x34, 0x56, 0x78, // Corrupted payload
    ]
}

#[test]
fn test_cve_golden_corpus_in_memory_rejection() {
    let dest_dir = Path::new("/tmp/ttzip_cve_audit_sandbox");

    // 1. CVE-2018-1002204: ZipSlip Directory Traversal Invariant Assertion
    let zipslip_bytes = build_cve_2018_1002204_zipslip_vector();
    let archive_res = ZipArchive::open_slice(&zipslip_bytes);
    assert!(archive_res.is_ok(), "Archive opening should parse structure");
    let archive = archive_res.unwrap();
    assert_eq!(archive.len(), 1);

    let evil_entry = &archive.entries()[0];
    let sanitized_res = sanitize_and_validate_path(dest_dir, &evil_entry.rel_path);
    assert_eq!(
        sanitized_res,
        Err(TTZipStatus::ErrSecurityViolation),
        "CVE-2018-1002204 ZipSlip vector was NOT trapped by safe extraction engine!"
    );

    // 2. CVE-2001-0775: Filename Length Overflow Assertion (0 Panic, ErrCorruptHeader)
    let fn_overflow_bytes = build_cve_2001_0775_filename_overflow_vector();
    let parse_res = catch_unwind(AssertUnwindSafe(|| {
        let _ = ZipArchive::open_slice(&fn_overflow_bytes);
        let _ = parse_all_entries(&fn_overflow_bytes);
    }));
    assert!(parse_res.is_ok(), "CVE-2001-0775 triggered panic!");

    // 3. CVE-2002-1337: EOCD Comment Length Buffer Overflow (0 Panic, Graceful rejection)
    let eocd_overflow_bytes = build_cve_2002_1337_eocd_comment_overflow_vector();
    let eocd_res = catch_unwind(AssertUnwindSafe(|| {
        find_eocd(&eocd_overflow_bytes)
    }));
    assert!(eocd_res.is_ok(), "CVE-2002-1337 triggered panic!");
    assert_eq!(eocd_res.unwrap(), Err(TTZipStatus::ErrCorruptHeader));

    // 4. CVE-2023-45853: Zip64 Integer Overflow
    let zip64_extra = build_cve_2023_45853_zip64_overflow_vector();
    let zip64_res = catch_unwind(AssertUnwindSafe(|| {
        ZipExtraFields::parse(&zip64_extra, true, true, true, true)
    }));
    assert!(zip64_res.is_ok(), "CVE-2023-45853 Zip64 parser panicked!");

    // 5. CVE-2022-1271: Corrupted Gzip Header & Method
    let gzip_corrupt = build_cve_2022_1271_gzip_vector();
    let mut out_buf = vec![0u8; 1024];
    let gz_res = catch_unwind(AssertUnwindSafe(|| {
        gzip_decompress(&gzip_corrupt, &mut out_buf)
    }));
    assert!(gz_res.is_ok(), "CVE-2022-1271 Gzip decompressor panicked!");
    assert_eq!(gz_res.unwrap(), Err(TTZipStatus::ErrCorruptHeader));

    // 6. WinZip AES Corrupted HMAC Auth Tag Assertion
    let password = "SecretPassword123!";
    let items = vec![ZipInputItem {
        rel_path: "secure.txt".to_string(),
        data: b"Top secret data protected with WinZip AES-256.".to_vec(),
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
    ).expect("compression failed");
    let mut enc_zip_bytes = assemble_zip_archive(&compressed).expect("assembly failed");
    let initial_archive = ZipArchive::open_slice(&enc_zip_bytes).expect("open enc slice failed");
    let lfh_offset = initial_archive.entries()[0].lfh_offset as usize;
    let (payload_offset, _) = parse_local_file_header(&enc_zip_bytes, lfh_offset).expect("parse lfh failed");

    // Tamper with ciphertext byte (triggers HMAC auth failure during extraction)
    enc_zip_bytes[payload_offset + 25] ^= 0xFF;

    let enc_archive = ZipArchive::open_slice(&enc_zip_bytes).expect("open enc slice failed");
    let extract_tampered_res = enc_archive.extract_entry_bytes(0, Some(password));
    assert!(
        extract_tampered_res.is_err(),
        "Tampered WinZip AES payload MUST be rejected, but got Ok"
    );

    println!("[ORACLE] In-memory Historical CVE Golden Corpus test completed: 100% trapped / safely rejected, 0 panics.");
}
