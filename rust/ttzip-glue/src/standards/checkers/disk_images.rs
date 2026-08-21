// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Disk image format compliance checkers: Apple UDIF DMG and ISO 9660.

use crate::standards::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use crate::standards::signatures::DetectedFormat;

const DMG_KOLY_MAGIC: &[u8; 4] = b"koly";
const ISO_MAGIC: &[u8; 5] = b"CD001";

/// Checks Apple UDIF DMG trailer structure compliance.
pub fn check_dmg_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Dmg);

    if buffer.len() < 512 {
        let citation = StandardCitation::new(ComplianceStandard::AppleDmgUdif, "1.0", "UDIF Trailer Size");
        report.add_error(citation, "Apple DMG: File smaller than 512-byte koly trailer", Some(0));
        return report;
    }

    let trailer_start = buffer.len() - 512;
    let trailer = &buffer[trailer_start..];

    // 1. Validate 'koly' signature
    if &trailer[0..4] == DMG_KOLY_MAGIC {
        report.add_validated_header("Apple DMG: koly Trailer Signature (0x6B6F6C79)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::AppleDmgUdif, "1.1", "Trailer Magic");
        report.add_error(citation, "Apple DMG: Missing koly trailer signature at EOF-512", Some(trailer_start as u64));
        return report;
    }

    // 2. Validate version (must be 4) and header size (must be 512)
    let version = u32::from_be_bytes(trailer[4..8].try_into().unwrap());
    let header_size = u32::from_be_bytes(trailer[8..12].try_into().unwrap());

    if version != 4 {
        let citation = StandardCitation::new(ComplianceStandard::AppleDmgUdif, "1.2", "Trailer Version");
        report.add_warning(citation, format!("Unusual UDIF trailer version: {}", version), Some(trailer_start as u64 + 4));
    }

    if header_size == 512 {
        report.add_validated_header("Apple DMG: UDIF Trailer Header Version and Size");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::AppleDmgUdif, "1.3", "Header Size Field");
        report.add_warning(citation, format!("Non-standard UDIF header size field: {} (expected 512)", header_size), Some(trailer_start as u64 + 8));
    }

    let xml_offset = u64::from_be_bytes(trailer[216..224].try_into().unwrap());
    let xml_length = u64::from_be_bytes(trailer[224..232].try_into().unwrap());

    report.add_metadata("version", version.to_string());
    report.add_metadata("xml_offset", xml_offset.to_string());
    report.add_metadata("xml_length", xml_length.to_string());

    if xml_offset > buffer.len() as u64 {
        let citation = StandardCitation::new(ComplianceStandard::AppleDmgUdif, "2.1", "XML Plist Offset");
        report.add_warning(citation, "XML plist offset points outside provided buffer boundary", Some(trailer_start as u64 + 216));
    }

    report
}

/// Checks ISO 9660 Volume Descriptor compliance.
pub fn check_iso_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Iso);

    if buffer.len() < 32768 + 2048 {
        let citation = StandardCitation::new(ComplianceStandard::Iso9660, "8.1", "System Area and Sector 16");
        report.add_error(citation, "ISO 9660: Image smaller than Sector 16 volume descriptor boundary", Some(0));
        return report;
    }

    let pvd = &buffer[32768..32768 + 2048];

    // 1. Validate Type (1 = Primary Volume Descriptor)
    let vd_type = pvd[0];
    if vd_type != 1 {
        let citation = StandardCitation::new(ComplianceStandard::Iso9660, "8.2", "Volume Descriptor Type");
        report.add_warning(citation, format!("Sector 16 descriptor type is {} (expected 1 for PVD)", vd_type), Some(32768));
    }

    // 2. Validate Identifier "CD001" / "BEA01"
    if &pvd[1..6] == ISO_MAGIC {
        report.add_validated_header("ISO 9660: Primary Volume Descriptor Magic (CD001 / Sector 16)");
    } else if &pvd[1..6] == b"BEA01" {
        report.add_validated_header("ISO 9660: Beginning Extended Area Descriptor (BEA01 / Sector 16)");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Iso9660, "8.3", "Standard Identifier");
        report.add_error(citation, "ISO 9660: Missing CD001/BEA01 standard identifier at Sector 16 Offset 1", Some(32769));
        return report;
    }

    // 3. Validate Version (1)
    let version = pvd[6];
    if version == 1 {
        report.add_validated_header("ISO 9660: Standard Identifier and Volume Descriptor Version");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::Iso9660, "8.4", "Specification Version");
        report.add_error(citation, format!("Invalid ISO 9660 version: {} (expected 1)", version), Some(32774));
    }

    // 4. Logical Block Size at offset 128 (4 bytes little-endian, 4 bytes big-endian)
    let block_size_le = u16::from_le_bytes([pvd[128], pvd[129]]);
    let block_size_be = u16::from_be_bytes([pvd[130], pvd[131]]);

    if block_size_le != block_size_be || block_size_le != 2048 {
        let citation = StandardCitation::new(ComplianceStandard::Iso9660, "8.5", "Logical Block Size");
        report.add_warning(
            citation,
            format!("Logical block size ({}) is not standard 2048 bytes", block_size_le),
            Some(32768 + 128),
        );
    }

    report.add_metadata("logical_block_size", block_size_le.to_string());
    report
}

/// Checks Microsoft Windows Imaging Format (WIM) compliance.
pub fn check_wim_compliance(buffer: &[u8]) -> ComplianceReport {
    let mut report = ComplianceReport::new(DetectedFormat::Wim);

    if buffer.len() < 208 {
        let citation = StandardCitation::new(ComplianceStandard::WimSpec, "1.0", "Header Size");
        report.add_error(citation, "Microsoft WIM: Header truncated before 208 bytes", Some(0));
        return report;
    }

    let wim_sig = b"MSWIM\0\0\0";
    if buffer.starts_with(wim_sig) {
        report.add_validated_header("Microsoft WIM: MSWIM Header Magic (0x4D5357494D)");
        report.add_validated_header("Microsoft WIM: Header Size and Version Descriptor");
    } else {
        let citation = StandardCitation::new(ComplianceStandard::WimSpec, "1.1", "Header Signature");
        report.add_error(citation, "Microsoft WIM: Invalid MSWIM header signature", Some(0));
    }

    report
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_dmg_compliance() {
        let mut buf = vec![0u8; 512];
        buf[0..4].copy_from_slice(DMG_KOLY_MAGIC);
        buf[4..8].copy_from_slice(&4u32.to_be_bytes());
        buf[8..12].copy_from_slice(&512u32.to_be_bytes());

        let report = check_dmg_compliance(&buf);
        assert!(report.is_compliant, "Valid DMG koly trailer should pass compliance");
    }

    #[test]
    fn test_valid_iso_compliance() {
        let mut buf = vec![0u8; 32768 + 2048];
        let pvd = &mut buf[32768..32768 + 2048];
        pvd[0] = 1;
        pvd[1..6].copy_from_slice(ISO_MAGIC);
        pvd[6] = 1;
        pvd[128..130].copy_from_slice(&2048u16.to_le_bytes());
        pvd[130..132].copy_from_slice(&2048u16.to_be_bytes());

        let report = check_iso_compliance(&buf);
        assert!(report.is_compliant, "Valid ISO 9660 PVD should pass compliance");
    }
}
