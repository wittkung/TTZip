// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! POSIX.1 ustar and GNU tar format compliance checker.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

pub fn check_tar_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Tar);

    if buffer.len() < 512 {
        let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1", "Record and Block Size");
        report.add_error(citation, "TAR buffer is smaller than single 512-byte header block", Some(0));
        return report;
    }

    if buffer.len() % 512 != 0 {
        let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1", "512-byte Block Alignment");
        report.add_error(
            citation,
            format!("TAR archive size ({}) is not a multiple of 512-byte logical records", buffer.len()),
            Some(buffer.len() as u64),
        );
    }

    let mut cursor = 0;
    let mut entry_count = 0;
    let mut consecutive_zero_blocks = 0;

    while cursor + 512 <= buffer.len() {
        let block = &buffer[cursor..cursor + 512];

        // Check if block is entirely zero
        if is_all_zeros(block) {
            consecutive_zero_blocks += 1;
            cursor += 512;
            if consecutive_zero_blocks == 2 {
                // Verified standard End-of-Archive (1024 zero bytes)
                break;
            }
            continue;
        } else {
            consecutive_zero_blocks = 0;
        }

        entry_count += 1;

        // Verify Checksum at bytes 148..156
        let (unsigned_sum, signed_sum) = compute_header_checksum(block);
        let chksum_field = &block[148..156];
        let parsed_chksum = parse_octal_field(chksum_field);

        match parsed_chksum {
            Some(val) => {
                if val != unsigned_sum as u64 && val != signed_sum as u64 {
                    let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1.1", "Header Checksum Field");
                    report.add_error(
                        citation,
                        format!("Checksum mismatch (header: {}, computed unsigned: {}, signed: {})", val, unsigned_sum, signed_sum),
                        Some(cursor as u64 + 148),
                    );
                }
            }
            None => {
                let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1.1", "Header Checksum Field Format");
                report.add_error(citation, "Malformed octal checksum field", Some(cursor as u64 + 148));
            }
        }

        // Verify Magic at offset 257..265
        let magic = &block[257..263];
        if magic != b"ustar\0" && magic != b"ustar " {
            let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1.2", "ustar Magic Identifier");
            report.add_warning(citation, "Non-standard or legacy pre-POSIX tar header magic", Some(cursor as u64 + 257));
        }

        // Parse file size at 124..136
        let size_field = &block[124..136];
        let file_size = parse_octal_field(size_field).unwrap_or(0) as usize;

        // Skip payload blocks (rounded up to 512 bytes)
        let payload_blocks = (file_size + 511) / 512;
        cursor += 512 + (payload_blocks * 512);
    }

    if consecutive_zero_blocks < 2 {
        let citation = StandardCitation::new(ComplianceStandard::Posix1Tar, "8.1.3", "End-of-Archive Indicator");
        report.add_warning(citation, "Archive lacks standard 1024-byte (2 zero blocks) End-of-Archive marker", Some(buffer.len() as u64));
    }

    report.add_metadata("entry_count", entry_count.to_string());
    report
}

fn compute_header_checksum(block: &[u8]) -> (u32, i32) {
    let mut unsigned_sum: u32 = 0;
    let mut signed_sum: i32 = 0;

    for (i, &b) in block.iter().enumerate() {
        let val = if (148..156).contains(&i) {
            0x20u8 // Spaces during checksum computation
        } else {
            b
        };
        unsigned_sum += val as u32;
        signed_sum += (val as i8) as i32;
    }

    (unsigned_sum, signed_sum)
}

fn parse_octal_field(field: &[u8]) -> Option<u64> {
    let mut trimmed = field;
    while !trimmed.is_empty() && (trimmed[0] == b' ' || trimmed[0] == 0) {
        trimmed = &trimmed[1..];
    }
    while !trimmed.is_empty() && (trimmed[trimmed.len() - 1] == b' ' || trimmed[trimmed.len() - 1] == 0) {
        trimmed = &trimmed[..trimmed.len() - 1];
    }
    if trimmed.is_empty() {
        return Some(0);
    }

    let mut result: u64 = 0;
    for &b in trimmed {
        if !(b'0'..=b'7').contains(&b) {
            return None;
        }
        result = result.checked_mul(8)?.checked_add((b - b'0') as u64)?;
    }
    Some(result)
}

fn is_all_zeros(slice: &[u8]) -> bool {
    slice.iter().all(|&b| b == 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_tar_block_checksum() {
        let mut header = vec![0u8; 1536]; // 1 header + 2 zero blocks
        header[0..10].copy_from_slice(b"test.txt\0\0");
        header[100..108].copy_from_slice(b"0000644\0");
        header[124..136].copy_from_slice(b"00000000000\0"); // size 0
        header[257..263].copy_from_slice(b"ustar\0");
        header[263..265].copy_from_slice(b"00");

        let (u_sum, _) = compute_header_checksum(&header[0..512]);
        let chk_str = format!("{:06o}\0 ", u_sum);
        header[148..156].copy_from_slice(chk_str.as_bytes());

        let report = check_tar_compliance(&header);
        assert!(report.is_compliant, "Valid ustar header should pass compliance");
    }
}
