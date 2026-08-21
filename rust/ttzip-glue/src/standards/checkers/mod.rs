// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format compliance checker registry and dispatch engine.

pub mod bzip2;
pub mod disk_images;
pub mod gzip;
pub mod modern;
pub mod sevenz;
pub mod tar;
pub mod xz;
pub mod zip;
pub mod zstd;

use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

use super::report::{ComplianceReport, ComplianceStandard, StandardCitation};
use super::signatures::DetectedFormat;
use super::sniffer::{detect_format_buffer, detect_format_file};

/// Dispatches buffer-level compliance inspection according to detected or specified format.
pub fn check_compliance_buffer(format: DetectedFormat, buffer: &[u8]) -> ComplianceReport {
    let resolved_format = if format == DetectedFormat::Unknown {
        detect_format_buffer(buffer, None).format
    } else {
        format
    };

    match resolved_format {
        DetectedFormat::Zip => zip::check_zip_compliance(buffer),
        DetectedFormat::Tar => tar::check_tar_compliance(buffer),
        DetectedFormat::SevenZip => sevenz::check_sevenz_compliance(buffer),
        DetectedFormat::Gzip => gzip::check_gzip_compliance(buffer),
        DetectedFormat::Zstd => zstd::check_zstd_compliance(buffer),
        DetectedFormat::Bzip2 => bzip2::check_bzip2_compliance(buffer),
        DetectedFormat::Xz => xz::check_xz_compliance(buffer),
        DetectedFormat::Dmg => disk_images::check_dmg_compliance(buffer),
        DetectedFormat::Iso => disk_images::check_iso_compliance(buffer),
        DetectedFormat::Xar => modern::check_xar_compliance(buffer),
        DetectedFormat::Lzfse => modern::check_lzfse_compliance(buffer),
        DetectedFormat::Snappy => modern::check_snappy_compliance(buffer),
        DetectedFormat::Lz4 => modern::check_lz4_compliance(buffer),
        DetectedFormat::Ar => modern::check_ar_compliance(buffer),
        DetectedFormat::Rar => modern::check_rar_compliance(buffer),
        DetectedFormat::Cab => modern::check_cab_compliance(buffer),
        _ => {
            let mut report = ComplianceReport::new(DetectedFormat::Unknown);
            let citation = StandardCitation::new(ComplianceStandard::Generic, "1.0", "Format Identification");
            report.add_error(citation, "Unknown or unsupported format for compliance checking", Some(0));
            report
        }
    }
}

/// Inspects and verifies compliance of an on-disk archive file.
pub fn check_compliance_file<P: AsRef<Path>>(path: P) -> io::Result<ComplianceReport> {
    let sniff_result = detect_format_file(&path)?;
    let mut file = File::open(&path)?;
    let file_len = file.metadata()?.len() as usize;

    // Read full file if small, or up to 4MB inspection window
    let read_len = file_len.min(4 * 1024 * 1024);
    let mut buffer = vec![0u8; read_len];
    file.read_exact(&mut buffer)?;

    Ok(check_compliance_buffer(sniff_result.format, &buffer))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dispatch_gzip_compliance() {
        let mut gz_buf = vec![0u8; 18];
        gz_buf[0] = 0x1F;
        gz_buf[1] = 0x8B;
        gz_buf[2] = 8;
        let report = check_compliance_buffer(DetectedFormat::Unknown, &gz_buf);
        assert_eq!(report.format, DetectedFormat::Gzip);
        assert!(report.is_compliant);
    }
}
