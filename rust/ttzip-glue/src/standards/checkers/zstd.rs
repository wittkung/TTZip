// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! RFC 8878 Zstandard (zstd) format standards compliance checker.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const ZSTD_MAGIC: u32 = 0xFD2FB528;
const ZSTD_SKIPPABLE_START: u32 = 0x184D2A50;
const ZSTD_SKIPPABLE_END: u32 = 0x184D2A5F;

pub fn check_zstd_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Zstd);

    if buffer.len() < 4 {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1", "Magic Number");
        report.add_error(citation, "Buffer is smaller than 4-byte Zstandard magic number", Some(0));
        return report;
    }

    let magic = u32::from_le_bytes(buffer[0..4].try_into().unwrap());

    // Check for skippable frames
    if (ZSTD_SKIPPABLE_START..=ZSTD_SKIPPABLE_END).contains(&magic) {
        report.add_metadata("frame_type", "skippable");
        if buffer.len() < 8 {
            let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.2", "Skippable Frame");
            report.add_error(citation, "Truncated skippable frame size header", Some(4));
            return report;
        }
        let frame_size = u32::from_le_bytes(buffer[4..8].try_into().unwrap());
        report.add_metadata("skippable_frame_size", frame_size.to_string());
        return report;
    }

    if magic != ZSTD_MAGIC {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1", "Zstandard Magic Number");
        report.add_error(citation, format!("Invalid Zstandard magic number: 0x{:08X}", magic), Some(0));
        return report;
    }

    if buffer.len() < 5 {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.1", "Frame Header Descriptor");
        report.add_error(citation, "Buffer truncated before Frame_Header_Descriptor byte", Some(4));
        return report;
    }

    // Parse Frame Header Descriptor (FHD)
    let fhd = buffer[4];
    let dict_id_flag = fhd & 0x03;
    let checksum_flag = (fhd >> 2) & 0x01 != 0;
    let reserved_bit = (fhd >> 3) & 0x01 != 0;
    let single_segment_flag = (fhd >> 5) & 0x01 != 0;
    let fcs_flag = (fhd >> 6) & 0x03;

    if reserved_bit {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.1.1", "FHD Reserved Bit");
        report.add_error(citation, "FHD reserved bit 3 must be zero", Some(4));
    }

    report.add_metadata("has_checksum", checksum_flag.to_string());
    report.add_metadata("single_segment", single_segment_flag.to_string());

    let mut cursor = 5;

    // Window Descriptor if single_segment is false
    if !single_segment_flag {
        if cursor >= buffer.len() {
            let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.1.2", "Window Descriptor");
            report.add_error(citation, "Truncated Window_Descriptor byte", Some(cursor as u64));
            return report;
        }
        let _window_byte = buffer[cursor];
        cursor += 1;
    }

    // Dictionary ID bytes (0, 1, 2, or 4)
    let dict_bytes = match dict_id_flag {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        _ => unreachable!(),
    };
    if cursor + dict_bytes > buffer.len() {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.1.3", "Dictionary ID");
        report.add_error(citation, "Truncated Dictionary_ID field", Some(cursor as u64));
        return report;
    }
    cursor += dict_bytes;

    // Frame Content Size bytes
    let fcs_bytes = match fcs_flag {
        0 => if single_segment_flag { 1 } else { 0 },
        1 => 2,
        2 => 4,
        3 => 8,
        _ => unreachable!(),
    };
    if cursor + fcs_bytes > buffer.len() {
        let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.1.4", "Frame Content Size");
        report.add_error(citation, "Truncated Frame_Content_Size field", Some(cursor as u64));
        return report;
    }
    cursor += fcs_bytes;

    // First Block Header validation (3 bytes)
    if cursor + 3 <= buffer.len() {
        let block_hdr_bytes = [buffer[cursor], buffer[cursor + 1], buffer[cursor + 2], 0];
        let block_hdr = u32::from_le_bytes(block_hdr_bytes);
        let block_type = (block_hdr >> 1) & 0x03;
        let block_size = block_hdr >> 3;

        if block_type == 3 {
            let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.2", "Block Type Reserved");
            report.add_error(citation, "Block Header specifies reserved block type 3", Some(cursor as u64));
        }

        if block_size > 131072 {
            let citation = StandardCitation::new(ComplianceStandard::Rfc8878Zstd, "3.1.1.2", "Block Size Upper Bound");
            report.add_warning(
                citation,
                format!("Block size {} exceeds standard 128KB threshold", block_size),
                Some(cursor as u64),
            );
        }
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_zstd_compliance() {
        let mut buf = vec![0u8; 16];
        buf[0..4].copy_from_slice(&ZSTD_MAGIC.to_le_bytes());
        buf[4] = 0x20; // Single_Segment_Flag = 1, FCS_Flag = 0 (1 byte size)
        buf[5] = 0x00; // FCS = 0

        let report = check_zstd_compliance(&buf);
        assert!(report.is_compliant, "Valid minimal Zstandard frame should pass compliance");
    }
}
