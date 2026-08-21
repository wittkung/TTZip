// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip 24.08 format standards compliance checker.

use crate::crypto::crc32::crc32_fast;
use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const SIGNATURE: &[u8; 6] = &[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C];

pub fn check_sevenz_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::SevenZip);

    if buffer.len() < 32 {
        let citation = StandardCitation::new(ComplianceStandard::SevenZipSpec, "1.1", "Signature Header Size");
        report.add_error(citation, "Buffer is smaller than 32-byte 7z SignatureHeader", Some(0));
        return report;
    }

    // 1. Validate 6-byte magic signature
    if &buffer[0..6] != SIGNATURE {
        let citation = StandardCitation::new(ComplianceStandard::SevenZipSpec, "1.1", "7z Signature Bytes");
        report.add_error(citation, "Invalid 7z magic signature bytes", Some(0));
        return report;
    }

    let major_version = buffer[6];
    let minor_version = buffer[7];
    let start_header_crc = u32::from_le_bytes(buffer[8..12].try_into().unwrap());
    let next_header_offset = u64::from_le_bytes(buffer[12..20].try_into().unwrap());
    let next_header_size = u64::from_le_bytes(buffer[20..28].try_into().unwrap());
    let next_header_crc = u32::from_le_bytes(buffer[28..32].try_into().unwrap());

    report.add_metadata("version", format!("{}.{}", major_version, minor_version));
    report.add_metadata("next_header_offset", next_header_offset.to_string());
    report.add_metadata("next_header_size", next_header_size.to_string());

    // 2. Validate StartHeaderCRC over bytes 12..32 using hardware accelerated CRC32
    let computed_start_crc = crc32_fast(0, &buffer[12..32]);
    if start_header_crc != computed_start_crc {
        let citation = StandardCitation::new(ComplianceStandard::SevenZipSpec, "1.1.1", "StartHeaderCRC");
        report.add_error(
            citation,
            format!("StartHeaderCRC mismatch (header: 0x{:08X}, computed: 0x{:08X})", start_header_crc, computed_start_crc),
            Some(8),
        );
    }

    // 3. Validate NextHeader boundaries and integrity if present in buffer
    let target_start = 32usize.saturating_add(next_header_offset as usize);
    let target_end = target_start.saturating_add(next_header_size as usize);

    if target_end <= buffer.len() && next_header_size > 0 {
        let header_slice = &buffer[target_start..target_end];
        let computed_next_crc = crc32_fast(0, header_slice);
        if computed_next_crc != next_header_crc {
            let citation = StandardCitation::new(ComplianceStandard::SevenZipSpec, "1.1.2", "NextHeaderCRC");
            report.add_error(
                citation,
                format!("NextHeaderCRC mismatch (header: 0x{:08X}, computed: 0x{:08X})", next_header_crc, computed_next_crc),
                Some(28),
            );
        } else {
            report.add_metadata("next_header_verified", "true");
        }
    } else if next_header_size > 0 && target_end > buffer.len() {
        let citation = StandardCitation::new(ComplianceStandard::SevenZipSpec, "1.1.3", "NextHeader Size Boundary");
        report.add_warning(
            citation,
            "NextHeader boundary extends beyond currently provided buffer",
            Some(target_start as u64),
        );
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_7z_header_compliance() {
        let mut buf = vec![0u8; 32];
        buf[0..6].copy_from_slice(SIGNATURE);
        buf[6] = 0;
        buf[7] = 4; // Version 0.4
        buf[12..20].copy_from_slice(&0u64.to_le_bytes());
        buf[20..28].copy_from_slice(&0u64.to_le_bytes());
        buf[28..32].copy_from_slice(&0u32.to_le_bytes());

        let crc = crc32_fast(0, &buf[12..32]);
        buf[8..12].copy_from_slice(&crc.to_le_bytes());

        let report = check_sevenz_compliance(&buf);
        assert!(report.is_compliant, "Valid 7z signature header should pass compliance");
    }
}
