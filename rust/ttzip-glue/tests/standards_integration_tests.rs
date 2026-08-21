// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! End-to-end integration tests for Standards Compliance & 16-Format Magic Sniffing.

use std::ffi::{CStr, CString};
use std::fs::File;
use std::io::Write;
use std::ptr;
use tempfile::tempdir;

use ttzip_glue::crypto::crc32::crc32_fast;
use ttzip_glue::standards::*;
use ttzip_glue::types::TTZipStatus;

#[test]
fn test_16_formats_sniffing_coverage() {
    let test_cases: Vec<(&[u8], Option<&str>, DetectedFormat)> = vec![
        // 1. 7-Zip
        (b"7z\xBC\xAF\x27\x1C\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::SevenZip),
        // 2. XZ
        (b"\xFD7zXZ\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Xz),
        // 3. RAR5
        (b"Rar!\x1A\x07\x01\x00", None, DetectedFormat::Rar),
        // 4. RAR4
        (b"Rar!\x1A\x07\x00", None, DetectedFormat::Rar),
        // 5. Zstandard
        (b"\x28\xB5\x2F\xFD\x20\x00", None, DetectedFormat::Zstd),
        // 6. XAR
        (b"xar!\x00\x1C\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01", None, DetectedFormat::Xar),
        // 7. CAB
        (b"MSCF\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Cab),
        // 8. AR / DEB
        (b"!<arch>\n`\n\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Ar),
        // 9. Snappy Framed
        (b"\xFF\x06\x00\x00sNaPpY", None, DetectedFormat::Snappy),
        // 10. LZ4 Framed
        (b"\x04\x22\x4D\x18\x60\x70\x73", None, DetectedFormat::Lz4),
        // 11. Apple LZFSE
        (b"bvx-\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Lzfse),
        // 12. ZIP
        (b"PK\x03\x04\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", None, DetectedFormat::Zip),
        // 13. GZIP
        (b"\x1F\x8B\x08\x00\x00\x00\x00\x00\x02\x03", None, DetectedFormat::Gzip),
        // 14. BZIP2
        (b"BZh91AY&SY\x00\x00\x00\x00", None, DetectedFormat::Bzip2),
    ];

    for (bytes, hint, expected_format) in test_cases {
        let res = detect_format_buffer(bytes, hint);
        assert_eq!(res.format, expected_format, "Failed detecting format for {:?}", expected_format);
    }
}

#[test]
fn test_compound_tar_extensions() {
    let gz_header = b"\x1F\x8B\x08\x00\x00\x00\x00\x00\x00\x03";
    let bz2_header = b"BZh91AY&SY\x00\x00\x00\x00";
    let xz_header = b"\xFD7zXZ\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    let zst_header = b"\x28\xB5\x2F\xFD";

    assert_eq!(detect_format_buffer(gz_header, Some("dist.tar.gz")).compound_format, Some(CompoundFormat::TarGz));
    assert_eq!(detect_format_buffer(gz_header, Some("dist.tgz")).compound_format, Some(CompoundFormat::TarGz));

    assert_eq!(detect_format_buffer(bz2_header, Some("dist.tar.bz2")).compound_format, Some(CompoundFormat::TarBz2));
    assert_eq!(detect_format_buffer(bz2_header, Some("dist.tbz2")).compound_format, Some(CompoundFormat::TarBz2));

    assert_eq!(detect_format_buffer(xz_header, Some("dist.tar.xz")).compound_format, Some(CompoundFormat::TarXz));
    assert_eq!(detect_format_buffer(xz_header, Some("dist.txz")).compound_format, Some(CompoundFormat::TarXz));

    assert_eq!(detect_format_buffer(zst_header, Some("dist.tar.zst")).compound_format, Some(CompoundFormat::TarZstd));
    assert_eq!(detect_format_buffer(zst_header, Some("dist.tzst")).compound_format, Some(CompoundFormat::TarZstd));
}

#[test]
fn test_sfx_mz_pe_scanning() {
    // Generate simulated MZ PE stub with embedded ZIP
    let mut exe_data = vec![0u8; 4096];
    exe_data[0] = b'M';
    exe_data[1] = b'Z';

    // Embed ZIP at offset 1024
    exe_data[1024..1028].copy_from_slice(b"PK\x03\x04");

    let sniff = detect_format_buffer(&exe_data, Some("installer.exe"));
    assert_eq!(sniff.format, DetectedFormat::Zip);
    assert!(sniff.is_sfx);
    assert_eq!(sniff.sfx_offset, 1024);
}

#[test]
fn test_extra_fields_zero_copy_suite() {
    let mut extra = Vec::new();

    // 1. Zip64: uncompressed=10000000000, compressed=5000000000, offset=2000000000, disk=1
    extra.extend_from_slice(&0x0001u16.to_le_bytes());
    extra.extend_from_slice(&28u16.to_le_bytes());
    extra.extend_from_slice(&10000000000u64.to_le_bytes());
    extra.extend_from_slice(&5000000000u64.to_le_bytes());
    extra.extend_from_slice(&2000000000u64.to_le_bytes());
    extra.extend_from_slice(&1u32.to_le_bytes());

    // 2. Info-ZIP Unix: version=1, uid_size=4 (501), gid_size=4 (20)
    extra.extend_from_slice(&0x7875u16.to_le_bytes());
    extra.extend_from_slice(&11u16.to_le_bytes());
    extra.push(1); // version
    extra.push(4); // uid size
    extra.extend_from_slice(&501u32.to_le_bytes());
    extra.push(4); // gid size
    extra.extend_from_slice(&20u32.to_le_bytes());

    let parsed = ParsedExtraFields::parse(&extra, true, true, true, true);
    assert_eq!(parsed.raw_count, 2);

    let z64 = parsed.zip64.expect("Zip64 extra field missing");
    assert_eq!(z64.uncompressed_size, Some(10000000000));
    assert_eq!(z64.compressed_size, Some(5000000000));
    assert_eq!(z64.local_header_offset, Some(2000000000));
    assert_eq!(z64.disk_start_number, Some(1));

    let unix = parsed.infozip_unix.expect("InfoZip Unix extra field missing");
    assert_eq!(unix.uid, Some(501));
    assert_eq!(unix.gid, Some(20));
}

#[test]
fn test_compliance_checkers_all_formats() {
    // 1. ZIP Check
    let mut zip_buf = vec![0u8; 22];
    zip_buf[0..4].copy_from_slice(b"PK\x05\x06");
    let zip_rep = check_compliance_buffer(DetectedFormat::Zip, &zip_buf);
    assert!(zip_rep.is_compliant);

    // 2. 7z Check
    let mut sevenz_buf = vec![0u8; 32];
    sevenz_buf[0..6].copy_from_slice(&[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]);
    sevenz_buf[6] = 0;
    sevenz_buf[7] = 4;
    let crc = crc32_fast(0, &sevenz_buf[12..32]);
    sevenz_buf[8..12].copy_from_slice(&crc.to_le_bytes());
    let sevenz_rep = check_compliance_buffer(DetectedFormat::SevenZip, &sevenz_buf);
    assert!(sevenz_rep.is_compliant);

    // 3. GZIP Check
    let mut gzip_buf = vec![0u8; 18];
    gzip_buf[0] = 0x1F;
    gzip_buf[1] = 0x8B;
    gzip_buf[2] = 8;
    let gzip_rep = check_compliance_buffer(DetectedFormat::Gzip, &gzip_buf);
    assert!(gzip_rep.is_compliant);

    // 4. ZSTD Check
    let mut zstd_buf = vec![0u8; 16];
    zstd_buf[0..4].copy_from_slice(&0xFD2FB528u32.to_le_bytes());
    zstd_buf[4] = 0x20;
    let zstd_rep = check_compliance_buffer(DetectedFormat::Zstd, &zstd_buf);
    assert!(zstd_rep.is_compliant);

    // 5. BZIP2 Check
    let mut bz2_buf = vec![0u8; 14];
    bz2_buf[0..3].copy_from_slice(b"BZh");
    bz2_buf[3] = b'9';
    bz2_buf[4..10].copy_from_slice(&[0x31, 0x41, 0x59, 0x26, 0x53, 0x59]);
    let bz2_rep = check_compliance_buffer(DetectedFormat::Bzip2, &bz2_buf);
    assert!(bz2_rep.is_compliant);

    // 6. XZ Check
    let mut xz_buf = vec![0u8; 12];
    xz_buf[0..6].copy_from_slice(&[0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]);
    xz_buf[6] = 0;
    xz_buf[7] = 1;
    let xz_crc = crc32_fast(0, &xz_buf[6..8]);
    xz_buf[8..12].copy_from_slice(&xz_crc.to_le_bytes());
    let xz_rep = check_compliance_buffer(DetectedFormat::Xz, &xz_buf);
    assert!(xz_rep.is_compliant);
}

#[test]
fn test_compliance_report_violations() {
    // Malformed GZIP with invalid compression method ID 99
    let mut bad_gzip = vec![0u8; 18];
    bad_gzip[0] = 0x1F;
    bad_gzip[1] = 0x8B;
    bad_gzip[2] = 99; // Invalid CM

    let rep = check_compliance_buffer(DetectedFormat::Gzip, &bad_gzip);
    assert!(!rep.is_compliant);
    assert!(rep.issues.iter().any(|i| i.message.contains("Unsupported GZIP compression method ID: 99")));
}

#[test]
fn test_standards_ffi_c_abi_end_to_end() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("archive.zip");

    // Write empty ZIP
    let mut file = File::create(&file_path).unwrap();
    let mut zip_data = vec![0u8; 22];
    zip_data[0..4].copy_from_slice(b"PK\x05\x06");
    file.write_all(&zip_data).unwrap();

    let c_path = CString::new(file_path.to_str().unwrap()).unwrap();

    // 1. Test FFI File Sniffing
    let mut detected_format: i32 = 0;
    let mut is_sfx: bool = false;
    let mut sfx_offset: usize = 0;

    let status = unsafe {
        ttzip_rust_detect_format_file(
            c_path.as_ptr(),
            &mut detected_format,
            &mut is_sfx,
            &mut sfx_offset,
        )
    };
    assert_eq!(status, TTZipStatus::Ok);
    assert_eq!(detected_format, DetectedFormat::Zip as i32);

    // 2. Test FFI Compliance Checking on File
    let mut report_json: *mut std::os::raw::c_char = ptr::null_mut();
    let mut is_compliant: bool = false;

    let comp_status = unsafe {
        ttzip_rust_check_compliance_file(
            c_path.as_ptr(),
            &mut report_json,
            &mut is_compliant,
        )
    };
    assert_eq!(comp_status, TTZipStatus::Ok);
    assert!(is_compliant);
    assert!(!report_json.is_null());

    let json_slice = unsafe { CStr::from_ptr(report_json).to_str().unwrap() };
    assert!(json_slice.contains("\"format\": \"Zip\""));
    assert!(json_slice.contains("\"is_compliant\": true"));

    // 3. Free JSON
    unsafe {
        ttzip_rust_free_compliance_report(report_json);
    }
}
