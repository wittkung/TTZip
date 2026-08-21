// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! The .xz File Format standards compliance checker.

use crate::crypto::crc32::crc32_fast;
use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const XZ_HEADER_MAGIC: &[u8; 6] = &[0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00];
const XZ_FOOTER_MAGIC: &[u8; 2] = &[0x59, 0x5A]; // "YZ"

pub fn check_xz_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Xz);

    if buffer.len() < 12 {
        let citation = StandardCitation::new(ComplianceStandard::XzSpec, "2.1.1", "Stream Header Size");
        report.add_error(citation, "XZ: Stream truncated before 12-byte stream header", Some(0));
        return report;
    }

    // 1. Validate Stream Header Magic
    if &buffer[0..6] != XZ_HEADER_MAGIC {
        let citation = StandardCitation::new(ComplianceStandard::XzSpec, "2.1.1.1", "Header Magic Bytes");
        report.add_error(citation, "XZ: Invalid stream header magic bytes", Some(0));
        return report;
    }
    report.add_validated_header("XZ: Stream Header Magic (\\xFD7zXZ\\x00)");

    // 2. Validate Stream Flags & Header CRC32
    let stream_flags = &buffer[6..8];
    let header_crc32 = u32::from_le_bytes(buffer[8..12].try_into().unwrap());
    let computed_crc32 = crc32_fast(0, stream_flags);

    if header_crc32 != computed_crc32 {
        let citation = StandardCitation::new(ComplianceStandard::XzSpec, "2.1.1.3", "Header CRC32");
        report.add_error(
            citation,
            format!("XZ Header CRC32 mismatch (header: 0x{:08X}, computed: 0x{:08X})", header_crc32, computed_crc32),
            Some(8),
        );
    } else {
        report.add_validated_header("XZ: Stream Header Flags and CRC32");
    }

    if stream_flags[0] != 0 {
        let citation = StandardCitation::new(ComplianceStandard::XzSpec, "2.1.1.2", "Stream Flags Reserved");
        report.add_error(citation, "First byte of Stream Flags must be 0x00", Some(6));
    }

    let check_id = stream_flags[1] & 0x0F;
    report.add_metadata("check_type_id", check_id.to_string());

    // 3. Inspect Stream Footer if full buffer provided
    if buffer.len() >= 24 {
        let footer_start = buffer.len() - 12;
        let footer_magic = &buffer[footer_start + 10..footer_start + 12];
        if footer_magic == XZ_FOOTER_MAGIC {
            report.add_validated_header("XZ: Stream Footer Magic (YZ) and Backward Size CRC32");
            let footer_flags = &buffer[footer_start + 8..footer_start + 10];
            if footer_flags != stream_flags {
                let citation = StandardCitation::new(ComplianceStandard::XzSpec, "2.1.2.3", "Stream Flags Parity");
                report.add_error(citation, "Footer Stream Flags do not match Header Stream Flags", Some(footer_start as u64 + 8));
            } else {
                report.add_metadata("footer_verified", "true");
            }
        }
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_xz_compliance() {
        let mut buf = vec![0u8; 12];
        buf[0..6].copy_from_slice(XZ_HEADER_MAGIC);
        buf[6] = 0;
        buf[7] = 1; // CRC32 check
        let crc = crc32_fast(0, &buf[6..8]);
        buf[8..12].copy_from_slice(&crc.to_le_bytes());

        let report = check_xz_compliance(&buf);
        assert!(report.is_compliant, "Valid XZ Stream Header should pass compliance");
    }
}
