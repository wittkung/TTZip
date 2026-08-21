// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Structured compliance reporting and authoritative standard citations.

use super::signatures::DetectedFormat;

/// Authoritative standards and specifications referenced during validation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ComplianceStandard {
    PkwareAppnote,
    Posix1Tar,
    SevenZipSpec,
    Rfc1952Gzip,
    Rfc8878Zstd,
    Rfc1951Deflate,
    AppleDmgUdif,
    Iso9660,
    Bzip2Spec,
    XzSpec,
    RarSpec,
    XarSpec,
    SnappySpec,
    Lz4Spec,
    LzfseSpec,
    UnixArSpec,
    CabSpec,
    Generic,
}

impl ComplianceStandard {
    pub fn name(self) -> &'static str {
        match self {
            ComplianceStandard::PkwareAppnote => "PKWARE APPNOTE .ZIP (.ZIP File Format Specification 6.3.9)",
            ComplianceStandard::Posix1Tar => "POSIX.1-2001 / IEEE Std 1003.1 ustar/pax tar specification",
            ComplianceStandard::SevenZipSpec => "7-Zip 24.08 7z Container File Format Specification",
            ComplianceStandard::Rfc1952Gzip => "RFC 1952 GZIP File Format Specification version 4.3",
            ComplianceStandard::Rfc8878Zstd => "RFC 8878 Zstandard Compression and The 'application/zstd' Media Type",
            ComplianceStandard::Rfc1951Deflate => "RFC 1951 DEFLATE Compressed Data Format Specification version 1.3",
            ComplianceStandard::AppleDmgUdif => "Apple Universal Disk Image Format (UDIF) Specification",
            ComplianceStandard::Iso9660 => "ISO 9660 / ECMA-119 Volume and File Structure",
            ComplianceStandard::Bzip2Spec => "bzip2 Burrows-Wheeler Transform Container Format",
            ComplianceStandard::XzSpec => "The .xz File Format Specification version 1.1.0",
            ComplianceStandard::RarSpec => "RAR Archive File Format 5.0 / 4.0 Technical Specification",
            ComplianceStandard::XarSpec => "eXtensible ARchive (XAR) Specification v1.0",
            ComplianceStandard::SnappySpec => "Snappy Framing Format Description",
            ComplianceStandard::Lz4Spec => "LZ4 Frame Format Description",
            ComplianceStandard::LzfseSpec => "Apple LZFSE Compression Format Specification",
            ComplianceStandard::UnixArSpec => "Unix Common Archive Format (ar) / Debian Package format",
            ComplianceStandard::CabSpec => "Microsoft Cabinet (CAB) File Format Specification",
            ComplianceStandard::Generic => "General Container Standards",
        }
    }
}

/// Precise citation to a specification clause or section.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StandardCitation {
    pub standard: ComplianceStandard,
    pub section: &'static str,
    pub description: &'static str,
}

impl StandardCitation {
    pub const fn new(standard: ComplianceStandard, section: &'static str, description: &'static str) -> Self {
        Self { standard, section, description }
    }
}

/// Severity classification of a compliance issue.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum ComplianceSeverity {
    Notice = 0,
    Info = 1,
    Warning = 2,
    Error = 3,
}

impl ComplianceSeverity {
    pub fn as_str(self) -> &'static str {
        match self {
            ComplianceSeverity::Notice => "NOTICE",
            ComplianceSeverity::Info => "INFO",
            ComplianceSeverity::Warning => "WARNING",
            ComplianceSeverity::Error => "ERROR",
        }
    }
}

/// Specific finding or issue identified during format compliance verification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ComplianceIssue {
    pub citation: StandardCitation,
    pub severity: ComplianceSeverity,
    pub message: String,
    pub offset: Option<u64>,
    pub context: Option<String>,
}

/// Consolidated compliance report for an archive stream or file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ComplianceReport {
    pub format: DetectedFormat,
    pub is_compliant: bool,
    pub issues: Vec<ComplianceIssue>,
    pub metadata: Vec<(String, String)>,
}

impl ComplianceReport {
    pub fn new(format: DetectedFormat) -> Self {
        Self {
            format,
            is_compliant: true,
            issues: Vec::new(),
            metadata: Vec::new(),
        }
    }

    pub fn add_error(&mut self, citation: StandardCitation, message: impl Into<String>, offset: Option<u64>) {
        self.is_compliant = false;
        self.issues.push(ComplianceIssue {
            citation,
            severity: ComplianceSeverity::Error,
            message: message.into(),
            offset,
            context: None,
        });
    }

    pub fn add_warning(&mut self, citation: StandardCitation, message: impl Into<String>, offset: Option<u64>) {
        self.issues.push(ComplianceIssue {
            citation,
            severity: ComplianceSeverity::Warning,
            message: message.into(),
            offset,
            context: None,
        });
    }

    pub fn add_info(&mut self, citation: StandardCitation, message: impl Into<String>, offset: Option<u64>) {
        self.issues.push(ComplianceIssue {
            citation,
            severity: ComplianceSeverity::Info,
            message: message.into(),
            offset,
            context: None,
        });
    }

    pub fn add_metadata(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.metadata.push((key.into(), value.into()));
    }

    pub fn summary(&self) -> String {
        let err_count = self.issues.iter().filter(|i| i.severity == ComplianceSeverity::Error).count();
        let warn_count = self.issues.iter().filter(|i| i.severity == ComplianceSeverity::Warning).count();
        format!(
            "Format: {:?}, Compliant: {}, Errors: {}, Warnings: {}, Issues Total: {}",
            self.format, self.is_compliant, err_count, warn_count, self.issues.len()
        )
    }

    /// Serializes the compliance report into a structured JSON string.
    pub fn to_json(&self) -> String {
        let mut json = String::with_capacity(1024);
        json.push_str("{\n");
        json.push_str(&format!("  \"format\": \"{:?}\",\n", self.format));
        json.push_str(&format!("  \"is_compliant\": {},\n", self.is_compliant));
        json.push_str("  \"metadata\": {\n");
        for (idx, (k, v)) in self.metadata.iter().enumerate() {
            let comma = if idx + 1 < self.metadata.len() { "," } else { "" };
            json.push_str(&format!("    \"{}\": \"{}\"{}\n", escape_json(k), escape_json(v), comma));
        }
        json.push_str("  },\n");
        json.push_str("  \"issues\": [\n");
        for (idx, issue) in self.issues.iter().enumerate() {
            let comma = if idx + 1 < self.issues.len() { "," } else { "" };
            let offset_str = issue.offset.map(|o| o.to_string()).unwrap_or_else(|| "null".to_string());
            json.push_str("    {\n");
            json.push_str(&format!("      \"severity\": \"{}\",\n", issue.severity.as_str()));
            json.push_str(&format!("      \"standard\": \"{}\",\n", escape_json(issue.citation.standard.name())));
            json.push_str(&format!("      \"section\": \"{}\",\n", escape_json(issue.citation.section)));
            json.push_str(&format!("      \"message\": \"{}\",\n", escape_json(&issue.message)));
            json.push_str(&format!("      \"offset\": {}\n", offset_str));
            json.push_str(&format!("    }}{}\n", comma));
        }
        json.push_str("  ]\n");
        json.push_str("}");
        json
    }
}

fn escape_json(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(c),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compliance_report_json() {
        let mut report = ComplianceReport::new(DetectedFormat::Zip);
        report.add_metadata("entries_count", "42");
        let citation = StandardCitation::new(ComplianceStandard::PkwareAppnote, "4.4.3.2", "Local File Header Magic");
        report.add_error(citation, "Invalid LFH signature", Some(1024));

        assert!(!report.is_compliant);
        let json = report.to_json();
        assert!(json.contains("\"format\": \"Zip\""));
        assert!(json.contains("\"is_compliant\": false"));
        assert!(json.contains("Invalid LFH signature"));
        assert!(json.contains("\"offset\": 1024"));
    }
}
