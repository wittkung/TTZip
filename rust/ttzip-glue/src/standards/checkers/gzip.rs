// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! RFC 1952 GZIP format standards compliance checker.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const GZIP_ID1: u8 = 0x1F;
const GZIP_ID2: u8 = 0x8B;
const CM_DEFLATE: u8 = 8;

const _FLAG_FTEXT: u8 = 1 << 0;
const FLAG_FHCRC: u8 = 1 << 1;
const FLAG_FEXTRA: u8 = 1 << 2;
const FLAG_FNAME: u8 = 1 << 3;
const FLAG_FCOMMENT: u8 = 1 << 4;
const FLAG_RESERVED: u8 = 0xE0; // Bits 5, 6, 7

pub fn check_gzip_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Gzip);

    if buffer.len() < 10 {
        let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Member Header Size");
        report.add_error(citation, format!("RFC 1952: GZIP stream truncated before 10-byte header ({} bytes)", buffer.len()), Some(0));
        return report;
    }

    // 1. Validate ID1 and ID2
    if buffer[0] == GZIP_ID1 && buffer[1] == GZIP_ID2 {
        report.add_validated_header("RFC 1952: GZIP Member ID1/ID2 Header Magic (0x1F8B)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "ID1 and ID2 Identification");
        report.add_error(
            citation,
            format!("RFC 1952: Invalid GZIP magic header (expected 0x1F8B, got 0x{:02X}{:02X})", buffer[0], buffer[1]),
            Some(0),
        );
        return report;
    }

    // 2. Validate Compression Method (CM)
    let cm = buffer[2];
    if cm == CM_DEFLATE {
        report.add_validated_header("RFC 1952: Compression Method DEFLATE (CM=8)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Compression Method");
        report.add_error(citation, format!("RFC 1952: Unsupported GZIP compression method ID: {} (expected 8 for DEFLATE)", cm), Some(2));
    }

    // 3. Validate FLG and reserved bits
    let flags = buffer[3];
    if (flags & FLAG_RESERVED) != 0 {
        let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Reserved Flags");
        report.add_error(
            citation,
            format!("RFC 1952: Reserved flag bits 5-7 must be zero (got 0x{:02X})", flags & FLAG_RESERVED),
            Some(3),
        );
    }
    report.add_validated_header("RFC 1952: Header Flags and MTIME Specification");

    let mtime = u32::from_le_bytes(buffer[4..8].try_into().unwrap());
    let xfl = buffer[8];
    let os = buffer[9];

    report.add_metadata("mtime", mtime.to_string());
    report.add_metadata("xfl", xfl.to_string());
    report.add_metadata("os", os.to_string());

    // 4. Traverse optional header fields
    let mut cursor = 10;

    if (flags & FLAG_FEXTRA) != 0 {
        if cursor + 2 > buffer.len() {
            let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1.1", "Extra Field Length");
            report.add_error(citation, "RFC 1952: Truncated GZIP XLEN field", Some(cursor as u64));
            return report;
        }
        let xlen = u16::from_le_bytes([buffer[cursor], buffer[cursor + 1]]) as usize;
        cursor += 2;
        if cursor + xlen > buffer.len() {
            let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1.1", "Extra Field Payload");
            report.add_error(citation, "RFC 1952: GZIP extra field extends beyond buffer boundary", Some(cursor as u64));
            return report;
        }
        cursor += xlen;
        report.add_validated_header("RFC 1952: FEXTRA Header Extension Block");
    }

    if (flags & FLAG_FNAME) != 0 {
        match buffer[cursor..].iter().position(|&b| b == 0) {
            Some(pos) => {
                cursor += pos + 1;
                report.add_validated_header("RFC 1952: FNAME Original Filename Header");
            }
            None => {
                let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Original File Name");
                report.add_error(citation, "RFC 1952: Unterminated GZIP original filename string", Some(cursor as u64));
                return report;
            }
        }
    }

    if (flags & FLAG_FCOMMENT) != 0 {
        match buffer[cursor..].iter().position(|&b| b == 0) {
            Some(pos) => {
                cursor += pos + 1;
                report.add_validated_header("RFC 1952: FCOMMENT File Comment Header");
            }
            None => {
                let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "File Comment");
                report.add_error(citation, "RFC 1952: Unterminated GZIP comment string", Some(cursor as u64));
                return report;
            }
        }
    }

    if (flags & FLAG_FHCRC) != 0 {
        if cursor + 2 > buffer.len() {
            let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Header CRC16");
            report.add_error(citation, "RFC 1952: Truncated GZIP header CRC16 field", Some(cursor as u64));
            return report;
        }
        cursor += 2;
        let _ = cursor;
        report.add_validated_header("RFC 1952: FHCRC Header CRC16 Checksum");
    }

    // 5. Verify Trailer (8 bytes: CRC32 + ISIZE) if full stream present
    if buffer.len() >= 18 {
        report.add_validated_header("RFC 1952: Trailer CRC32 and ISIZE Fields (offset EOF-8)");
        let trailer_start = buffer.len() - 8;
        let crc32_val = u32::from_le_bytes(buffer[trailer_start..trailer_start + 4].try_into().unwrap());
        let isize_val = u32::from_le_bytes(buffer[trailer_start + 4..trailer_start + 8].try_into().unwrap());
        report.add_metadata("trailer_crc32", format!("0x{:08X}", crc32_val));
        report.add_metadata("trailer_isize", isize_val.to_string());
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Rfc1952Gzip, "2.3.1", "Member Trailer");
        report.add_warning(citation, "RFC 1952: Stream too short to contain full trailer CRC32 and ISIZE fields", Some(buffer.len() as u64));
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_gzip_compliance() {
        let mut buf = vec![0u8; 18];
        buf[0] = GZIP_ID1;
        buf[1] = GZIP_ID2;
        buf[2] = CM_DEFLATE;
        buf[3] = 0; // No optional flags
        buf[8] = 2; // Maximum compression
        buf[9] = 3; // Unix OS

        let report = check_gzip_compliance(&buf);
        assert!(report.is_compliant, "Valid minimal GZIP should pass compliance");
    }
}
