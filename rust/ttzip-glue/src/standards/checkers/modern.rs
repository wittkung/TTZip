// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format compliance checkers for modern container and compression standards:
//! XAR, LZFSE, Snappy, LZ4, Unix AR, RAR, and CAB.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

/// Checks XAR (eXtensible ARchive) format compliance.
pub fn check_xar_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Xar);

    if buffer.len() < 28 {
        let citation = StandardCitation::new(ComplianceStandard::XarSpec, "1.0", "Header Size");
        report.add_error(citation, "Buffer is smaller than 28-byte XAR header", Some(0));
        return report;
    }

    if &buffer[0..4] != b"xar!" {
        let citation = StandardCitation::new(ComplianceStandard::XarSpec, "1.1", "Magic Identifier");
        report.add_error(citation, "Invalid XAR magic bytes (expected 'xar!')", Some(0));
        return report;
    }

    let size = u16::from_be_bytes([buffer[4], buffer[5]]);
    let version = u16::from_be_bytes([buffer[6], buffer[7]]);
    let toc_comp_len = u64::from_be_bytes(buffer[8..16].try_into().unwrap());
    let toc_uncomp_len = u64::from_be_bytes(buffer[16..24].try_into().unwrap());
    let cksum_alg = u32::from_be_bytes(buffer[24..28].try_into().unwrap());

    if size != 28 {
        let citation = StandardCitation::new(ComplianceStandard::XarSpec, "1.2", "Header Size Field");
        report.add_error(citation, format!("Invalid XAR header size field: {} (expected 28)", size), Some(4));
    }

    if version != 1 {
        let citation = StandardCitation::new(ComplianceStandard::XarSpec, "1.3", "Header Version");
        report.add_error(citation, format!("Invalid XAR version: {} (expected 1)", version), Some(6));
    }

    report.add_metadata("toc_compressed_length", toc_comp_len.to_string());
    report.add_metadata("toc_uncompressed_length", toc_uncomp_len.to_string());
    report.add_metadata("checksum_algorithm_id", cksum_alg.to_string());
    report
}

/// Checks Apple LZFSE stream compliance.
pub fn check_lzfse_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Lzfse);

    if buffer.len() < 12 {
        let citation = StandardCitation::new(ComplianceStandard::LzfseSpec, "1.0", "Block Header Size");
        report.add_error(citation, "Buffer is smaller than 12-byte LZFSE block header", Some(0));
        return report;
    }

    let magic = &buffer[0..4];
    if magic != b"bvx-" && magic != b"bvx1" && magic != b"bvx2" && magic != b"bvxn" {
        let citation = StandardCitation::new(ComplianceStandard::LzfseSpec, "1.1", "Block Magic");
        report.add_error(citation, "Invalid LZFSE block magic bytes", Some(0));
        return report;
    }

    let n_raw_bytes = u32::from_le_bytes(buffer[4..8].try_into().unwrap());
    report.add_metadata("block_magic", String::from_utf8_lossy(magic).to_string());
    report.add_metadata("n_raw_bytes", n_raw_bytes.to_string());
    report
}

/// Checks Snappy framed stream compliance.
pub fn check_snappy_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Snappy);

    if buffer.len() < 10 {
        let citation = StandardCitation::new(ComplianceStandard::SnappySpec, "1.0", "Stream Identifier Chunk");
        report.add_error(citation, "Snappy: Stream truncated before 10-byte identifier chunk", Some(0));
        return report;
    }

    // Must start with Stream Identifier: 0xFF, [0x06, 0x00, 0x00], "sNaPpY"
    if buffer[0] == 0xFF && &buffer[1..4] == &[0x06, 0x00, 0x00] && &buffer[4..10] == b"sNaPpY" {
        report.add_validated_header("Snappy: Stream Identifier Chunk (0xFF 0x060000 sNaPpY)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::SnappySpec, "1.1", "Identifier Chunk Magic");
        report.add_error(citation, "Snappy: Invalid Stream Identifier chunk magic", Some(0));
        return report;
    }

    report.add_metadata("stream_type", "snappy_framed");
    report
}

/// Checks LZ4 framed stream compliance.
pub fn check_lz4_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Lz4);

    if buffer.len() < 4 {
        let citation = StandardCitation::new(ComplianceStandard::Lz4Spec, "1.0", "Frame Descriptor Size");
        report.add_error(citation, "LZ4: Stream truncated before 4-byte magic number", Some(0));
        return report;
    }

    let magic = u32::from_le_bytes(buffer[0..4].try_into().unwrap());
    if magic == 0x184D2204 {
        report.add_validated_header("LZ4: Frame Magic Number (0x184D2204)");
        if buffer.len() >= 7 {
            report.add_validated_header("LZ4: Frame Descriptor (FLG, BD, HC)");
        }
    } else if magic == 0x184C2102 {
        report.add_validated_header("LZ4: Legacy Frame Magic (0x184C2102)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Lz4Spec, "1.1", "Frame Magic");
        report.add_error(citation, format!("LZ4: Invalid frame magic number (0x{:08X})", magic), Some(0));
        return report;
    }

    if buffer.len() >= 5 {
        let flg = buffer[4];
        let version = (flg >> 6) & 0x03;
        if version != 1 {
            let citation = StandardCitation::new(ComplianceStandard::Lz4Spec, "1.2", "Version Number");
            report.add_error(citation, format!("Invalid LZ4 frame version: {} (expected 1)", version), Some(4));
        }
        report.add_metadata("version", version.to_string());
    }

    report
}

/// Checks Lzip format compliance.
pub fn check_lzip_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Lzip);

    if buffer.len() < 6 {
        let citation = StandardCitation::new(ComplianceStandard::LzipSpec, "1.0", "Header Size");
        report.add_error(citation, "Lzip: Stream truncated before 6-byte header", Some(0));
        return report;
    }

    if buffer.starts_with(b"LZIP") {
        let ver = buffer[4];
        report.add_validated_header(format!("Lzip: LZIP Header Magic and Version {}", ver));
        report.add_validated_header("Lzip: Dictionary Size Descriptor");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::LzipSpec, "1.1", "Header Magic");
        report.add_error(citation, "Lzip: Invalid LZIP header magic", Some(0));
    }

    report
}

/// Checks LRZIP format compliance.
pub fn check_lrzip_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Lrzip);

    if buffer.len() < 6 {
        let citation = StandardCitation::new(ComplianceStandard::LrzipSpec, "1.0", "Header Size");
        report.add_error(citation, "LRZIP: Stream truncated before 6-byte header", Some(0));
        return report;
    }

    if buffer.starts_with(b"LRZI") {
        let maj = buffer[4];
        let min = buffer[5];
        report.add_validated_header(format!("LRZIP: LRZI Header Magic and Version ({}.{})", maj, min));
    } else {
        let citation = StandardCitation::new(ComplianceStandard::LrzipSpec, "1.1", "Header Magic");
        report.add_error(citation, "LRZIP: Invalid LRZI magic header", Some(0));
    }

    report
}

/// Checks Apple Archive (AAR / AEA) format compliance.
pub fn check_aar_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Aar);

    if buffer.len() < 4 {
        let citation = StandardCitation::new(ComplianceStandard::AarSpec, "1.0", "Header Size");
        report.add_error(citation, "Apple Archive: Stream truncated before 4-byte magic", Some(0));
        return report;
    }

    if buffer.starts_with(b"AA01") {
        report.add_validated_header("Apple Archive: AA01 Stream Header Magic");
    } else if buffer.starts_with(b"AEA1") {
        report.add_validated_header("Apple Archive: AEA1 Encrypted Archive Header Magic");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::AarSpec, "1.1", "Header Magic");
        report.add_error(citation, "Apple Archive: Invalid AA01/AEA1 magic header", Some(0));
    }

    report
}

/// Checks Brotli stream compliance.
pub fn check_brotli_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Brotli);

    if buffer.is_empty() {
        let citation = StandardCitation::new(ComplianceStandard::BrotliSpec, "1.0", "Stream Size");
        report.add_error(citation, "RFC 7932: Brotli stream is empty", Some(0));
    } else {
        report.add_validated_header("RFC 7932: Brotli Compressed Data Stream");
    }

    report
}

/// Checks Unix AR / Debian Package format compliance.
pub fn check_ar_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Ar);

    if buffer.len() < 8 {
        let citation = StandardCitation::new(ComplianceStandard::UnixArSpec, "1.0", "Global Header");
        report.add_error(citation, "Buffer is smaller than 8-byte AR global magic", Some(0));
        return report;
    }

    if &buffer[0..8] != b"!<arch>\n" {
        let citation = StandardCitation::new(ComplianceStandard::UnixArSpec, "1.1", "Archive Signature");
        report.add_error(citation, "Invalid AR signature (expected '!<arch>\\n')", Some(0));
        return report;
    }

    if buffer.len() >= 68 {
        let member_hdr = &buffer[8..68];
        let fmag = &member_hdr[58..60];
        if fmag != b"`\n" {
            let citation = StandardCitation::new(ComplianceStandard::UnixArSpec, "2.0", "File Header Trailer");
            report.add_error(citation, "Invalid AR member header trailer (expected '`\\n')", Some(66));
        }
    }

    report
}

/// Checks RAR4 / RAR5 format compliance.
pub fn check_rar_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Rar);

    if buffer.len() < 7 {
        let citation = StandardCitation::new(ComplianceStandard::RarSpec, "1.0", "Signature Size");
        report.add_error(citation, "Buffer is smaller than 7-byte RAR signature", Some(0));
        return report;
    }

    if buffer.starts_with(b"Rar!\x1A\x07\x01\x00") {
        report.add_metadata("rar_version", "5.0");
    } else if buffer.starts_with(b"Rar!\x1A\x07\x00") {
        report.add_metadata("rar_version", "4.0");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::RarSpec, "1.1", "Marker Block");
        report.add_error(citation, "Invalid RAR marker block signature", Some(0));
    }

    report
}

/// Checks Microsoft Cabinet (CAB) format compliance.
pub fn check_cab_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Cab);

    if buffer.len() < 36 {
        let citation = StandardCitation::new(ComplianceStandard::CabSpec, "1.0", "CFHEADER Size");
        report.add_error(citation, "Buffer is smaller than 36-byte CAB CFHEADER", Some(0));
        return report;
    }

    if &buffer[0..4] != b"MSCF" {
        let citation = StandardCitation::new(ComplianceStandard::CabSpec, "1.1", "Signature Bytes");
        report.add_error(citation, "Invalid CAB signature bytes (expected 'MSCF')", Some(0));
        return report;
    }

    let cb_cabinet = u32::from_le_bytes(buffer[8..12].try_into().unwrap());
    let c_folders = u16::from_le_bytes([buffer[26], buffer[27]]);
    let c_files = u16::from_le_bytes([buffer[28], buffer[29]]);

    report.add_metadata("cabinet_size", cb_cabinet.to_string());
    report.add_metadata("folder_count", c_folders.to_string());
    report.add_metadata("file_count", c_files.to_string());
    report
}
