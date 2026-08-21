// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! bzip2 format standards compliance checker.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const BZ_MAGIC: &[u8; 3] = b"BZh";
const PI_BLOCK_MAGIC: &[u8; 6] = &[0x31, 0x41, 0x59, 0x26, 0x53, 0x59]; // 0x314159265359 (Pi)
const EOS_BLOCK_MAGIC: &[u8; 6] = &[0x17, 0x72, 0x45, 0x38, 0x50, 0x90]; // 0x177245385090 (Sqrt(Pi))

pub fn check_bzip2_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Bzip2);

    if buffer.len() < 4 {
        let citation = StandardCitation::new(ComplianceStandard::Bzip2Spec, "1.0", "Header Magic");
        report.add_error(citation, "Buffer is smaller than 4-byte bzip2 header", Some(0));
        return report;
    }

    // 1. Validate magic bytes "BZh"
    if &buffer[0..3] != BZ_MAGIC {
        let citation = StandardCitation::new(ComplianceStandard::Bzip2Spec, "1.0", "BZh Identifier");
        report.add_error(citation, "bzip2: Invalid BZh magic header", Some(0));
        return report;
    }

    // 2. Validate block size digit '1'..='9'
    let level_char = buffer[3];
    if !(b'1'..=b'9').contains(&level_char) {
        let citation = StandardCitation::new(ComplianceStandard::Bzip2Spec, "1.0", "Block Size Identifier");
        report.add_error(
            citation,
            format!("Invalid bzip2 block size byte: '{}' (must be '1'..'9')", level_char as char),
            Some(3),
        );
    } else {
        let block_size_kb = (level_char - b'0') as u32 * 100;
        report.add_metadata("block_size_kb", block_size_kb.to_string());
        report.add_validated_header(format!("bzip2: BZh Header Magic and Block Size ({})", level_char as char));
    }

    // 3. Inspect first block or EOS magic
    if buffer.len() >= 10 {
        let block_magic = &buffer[4..10];
        if block_magic == PI_BLOCK_MAGIC {
            report.add_metadata("first_block_type", "data_block");
            report.add_validated_header("bzip2: Block / Stream-End Magic Sequence");
            if buffer.len() >= 14 {
                let block_crc = u32::from_be_bytes(buffer[10..14].try_into().unwrap());
                report.add_metadata("first_block_crc32", format!("0x{:08X}", block_crc));
            }
        } else if block_magic == EOS_BLOCK_MAGIC {
            report.add_metadata("first_block_type", "empty_stream_eos");
            report.add_validated_header("bzip2: Block / Stream-End Magic Sequence");
        } else {
            let citation = StandardCitation::new(ComplianceStandard::Bzip2Spec, "2.0", "Block Header Magic");
            report.add_warning(
                citation,
                "Non-standard or corrupted block header magic bytes",
                Some(4),
            );
        }
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_bzip2_compliance() {
        let mut buf = vec![0u8; 14];
        buf[0..3].copy_from_slice(b"BZh");
        buf[3] = b'9'; // 900 KB block
        buf[4..10].copy_from_slice(PI_BLOCK_MAGIC);
        buf[10..14].copy_from_slice(&[0x12, 0x34, 0x56, 0x78]);

        let report = check_bzip2_compliance(&buf);
        assert!(report.is_compliant, "Valid bzip2 stream header should pass compliance");
    }
}
