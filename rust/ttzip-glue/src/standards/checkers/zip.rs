// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! PKWARE APPNOTE .ZIP format standards compliance checker.

use crate::standards::extra_fields::ParsedExtraFields;
use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const SIG_LFH: u32 = 0x04034b50;
const SIG_CDFH: u32 = 0x02014b50;
const _SIG_EOCD: u32 = 0x06054b50;
const SIG_ZIP64_EOCD: u32 = 0x06064b50;
const SIG_ZIP64_LOCATOR: u32 = 0x07064b50;

pub fn check_zip_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Zip);

    if buffer.len() < 22 {
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.1", "End of Central Directory Record");
        report.add_error(citation, "ZIP file smaller than minimum EOCD record size (22 bytes)", Some(0));
        return report;
    }

    // 0. Check signature at offset 0
    let sig0 = u32::from_le_bytes(buffer[0..4].try_into().unwrap());
    if sig0 == 0x04034B50 {
        report.add_validated_header("PKWARE APPNOTE: Local File Header Signature (0x04034B50)");
    } else if sig0 == 0x06054B50 {
        report.add_validated_header("PKWARE APPNOTE: Empty Archive EOCD Signature (0x06054B50)");
    } else if sig0 == 0x08074B50 {
        report.add_validated_header("PKWARE APPNOTE: Spanned Archive Data Descriptor (0x08074B50)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.3.7", "Local File Header Magic");
        report.add_error(citation, "PKWARE APPNOTE: Missing valid ZIP Local File Header (0x04034B50) or EOCD (0x06054B50) at offset 0", Some(0));
    }

    // 1. Locate and parse EOCD
    let eocd_pos = match find_eocd(buffer) {
        Some(pos) => {
            report.add_validated_header("PKWARE APPNOTE: End of Central Directory Record (0x06054B50)");
            pos
        }
        None => {
            let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.1", "End of Central Directory Record");
            report.add_error(citation, "PKWARE APPNOTE: Missing End of Central Directory (EOCD) record (0x06054B50)", None);
            return report;
        }
    };

    let eocd = &buffer[eocd_pos..];
    let cd_entries_disk = u16::from_le_bytes([eocd[8], eocd[9]]);
    let cd_entries_total = u16::from_le_bytes([eocd[10], eocd[11]]);
    let cd_size = u32::from_le_bytes([eocd[12], eocd[13], eocd[14], eocd[15]]) as usize;
    let cd_offset = u32::from_le_bytes([eocd[16], eocd[17], eocd[18], eocd[19]]) as usize;
    let comment_len = u16::from_le_bytes([eocd[20], eocd[21]]) as usize;

    if cd_entries_disk != 0 {
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.1", "Multi-disk Spanned Archive");
        report.add_warning(citation, format!("Multi-disk ZIP archive detected (disk {})", cd_entries_disk), Some(eocd_pos as u64 + 8));
    }

    if eocd_pos + 22 + comment_len > buffer.len() {
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.1.5", "Archive Comment Length");
        report.add_error(citation, "EOCD comment length exceeds archive boundary", Some(eocd_pos as u64 + 20));
    }

    report.add_metadata("cd_entries_total", cd_entries_total.to_string());
    report.add_metadata("cd_size", cd_size.to_string());
    report.add_metadata("cd_offset", cd_offset.to_string());

    // 2. Check for Zip64 EOCD Locator
    let mut resolved_cd_offset = cd_offset as u64;
    let mut resolved_cd_entries = cd_entries_total as u64;

    if eocd_pos >= 20 {
        let locator_candidate = eocd_pos - 20;
        let sig = u32::from_le_bytes(buffer[locator_candidate..locator_candidate + 4].try_into().unwrap());
        if sig == SIG_ZIP64_LOCATOR {
            report.add_validated_header("PKWARE APPNOTE: Zip64 End of Central Directory Locator (0x07064B50)");
            let z64_eocd_offset = u64::from_le_bytes(buffer[locator_candidate + 8..locator_candidate + 16].try_into().unwrap());
            report.add_metadata("has_zip64_locator", "true");
            report.add_metadata("zip64_eocd_offset", z64_eocd_offset.to_string());

            if z64_eocd_offset as usize + 56 <= buffer.len() {
                let z64_sig = u32::from_le_bytes(buffer[z64_eocd_offset as usize..z64_eocd_offset as usize + 4].try_into().unwrap());
                if z64_sig == SIG_ZIP64_EOCD {
                    report.add_validated_header("PKWARE APPNOTE: Zip64 End of Central Directory Record (0x06064B50)");
                    report.add_validated_header("PKWARE APPNOTE: Archive verified as Zip64 format");
                    resolved_cd_entries = u64::from_le_bytes(buffer[z64_eocd_offset as usize + 32..z64_eocd_offset as usize + 40].try_into().unwrap());
                    resolved_cd_offset = u64::from_le_bytes(buffer[z64_eocd_offset as usize + 48..z64_eocd_offset as usize + 56].try_into().unwrap());
                } else {
                    let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.3.14", "Zip64 End of Central Directory Record");
                    report.add_error(citation, "Zip64 EOCD signature mismatch at locator target offset", Some(z64_eocd_offset));
                }
            }
        }
    }

    // 3. Central Directory traversal
    if resolved_cd_offset as usize > buffer.len() {
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.1", "Central Directory Structure");
        report.add_error(citation, "Central Directory offset exceeds buffer boundary", Some(resolved_cd_offset));
        return report;
    }

    let mut cursor = resolved_cd_offset as usize;
    let mut parsed_entries = 0u64;
    let mut parsed_cd_header = false;

    while cursor + 46 <= buffer.len() && parsed_entries < resolved_cd_entries {
        let sig = u32::from_le_bytes(buffer[cursor..cursor + 4].try_into().unwrap());
        if sig != SIG_CDFH {
            break;
        }

        if !parsed_cd_header {
            report.add_validated_header("PKWARE APPNOTE: Central Directory File Header (0x02014B50)");
            parsed_cd_header = true;
        }

        let _version_made = u16::from_le_bytes([buffer[cursor + 4], buffer[cursor + 5]]);
        let _version_needed = u16::from_le_bytes([buffer[cursor + 6], buffer[cursor + 7]]);
        let _flags = u16::from_le_bytes([buffer[cursor + 8], buffer[cursor + 9]]);
        let method = u16::from_le_bytes([buffer[cursor + 10], buffer[cursor + 11]]);
        let comp_size = u32::from_le_bytes(buffer[cursor + 20..cursor + 24].try_into().unwrap());
        let uncomp_size = u32::from_le_bytes(buffer[cursor + 24..cursor + 28].try_into().unwrap());
        let fname_len = u16::from_le_bytes([buffer[cursor + 28], buffer[cursor + 29]]) as usize;
        let extra_len = u16::from_le_bytes([buffer[cursor + 30], buffer[cursor + 31]]) as usize;
        let comment_entry_len = u16::from_le_bytes([buffer[cursor + 32], buffer[cursor + 33]]) as usize;
        let local_hdr_offset = u32::from_le_bytes(buffer[cursor + 42..cursor + 46].try_into().unwrap());

        let total_entry_len = 46 + fname_len + extra_len + comment_entry_len;
        if cursor + total_entry_len > buffer.len() {
            let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.3.12", "Central Directory Header Size");
            report.add_error(citation, "CDFH record extends beyond buffer length", Some(cursor as u64));
            break;
        }

        // Validate compression method
        match method {
            0 | 8 | 12 | 14 | 93 | 99 => {} // Valid Store, Deflate, Bzip2, LZMA, Zstd, WinZip AES
            _ => {
                let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.5", "Compression Methods");
                report.add_warning(citation, format!("Uncommon compression method ID: {}", method), Some(cursor as u64 + 10));
            }
        }

        // Validate Extra fields
        let extra_data = &buffer[cursor + 46 + fname_len..cursor + 46 + fname_len + extra_len];
        let parsed_extra = ParsedExtraFields::parse(
            extra_data,
            true,
            uncomp_size == 0xFFFFFFFF,
            comp_size == 0xFFFFFFFF,
            local_hdr_offset == 0xFFFFFFFF,
        );

        if parsed_extra.zip64.is_some() {
            report.add_validated_header("ZIP Extra Field: Zip64 Extended Information (0x0001)");
        }
        if parsed_extra.timestamp.is_some() {
            report.add_validated_header("ZIP Extra Field: Extended Timestamp (0x5455)");
        }
        if parsed_extra.unicode_path.is_some() {
            report.add_validated_header("ZIP Extra Field: Unicode Path (0x7075)");
        }
        if parsed_extra.infozip_unix.is_some() {
            report.add_validated_header("ZIP Extra Field: Info-ZIP UNIX (0x7875)");
        }
        if parsed_extra.winzip_aes.is_some() {
            report.add_validated_header("ZIP Extra Field: WinZip AES (0x9901)");
        }

        if uncomp_size == 0xFFFFFFFF && parsed_extra.zip64.as_ref().and_then(|z| z.uncompressed_size).is_none() {
            let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.5.3", "Zip64 Extended Information Extra Field");
            report.add_error(citation, "Zip64 uncompressed size placeholder 0xFFFFFFFF without Zip64 extra field", Some(cursor as u64));
        }

        // Cross-check LFH if present
        let mut target_lfh = local_hdr_offset as u64;
        if let Some(z64) = &parsed_extra.zip64 {
            if let Some(off) = z64.local_header_offset {
                target_lfh = off;
            }
        }

        if (target_lfh as usize) + 30 <= buffer.len() {
            let lfh_sig = u32::from_le_bytes(buffer[target_lfh as usize..target_lfh as usize + 4].try_into().unwrap());
            if lfh_sig != SIG_LFH {
                let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.3.7", "Local File Header Magic");
                report.add_warning(citation, format!("Local header signature mismatch at offset {}", target_lfh), Some(target_lfh));
            }
        }

        cursor += total_entry_len;
        parsed_entries += 1;
    }

    report.add_metadata("verified_cdfh_count", parsed_entries.to_string());
    report
}

fn find_eocd(buffer: &[u8]) -> Option<usize> {
    let scan_len = buffer.len().min(65557);
    let start = buffer.len() - scan_len;
    let window = &buffer[start..];

    for i in (0..=window.len() - 22).rev() {
        if &window[i..i + 4] == b"PK\x05\x06" {
            let comment_len = u16::from_le_bytes([window[i + 20], window[i + 21]]) as usize;
            if i + 22 + comment_len <= window.len() {
                return Some(start + i);
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_zip_compliance() {
        // Minimal valid empty zip file: 22 bytes EOCD
        let mut buf = vec![0u8; 22];
        buf[0..4].copy_from_slice(b"PK\x05\x06");
        let report = check_zip_compliance(&buf);
        assert!(report.is_compliant, "Empty valid zip should be compliant");
    }
}
