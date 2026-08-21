// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format standards compliance and 16-format magic sniffing subsystem.

pub mod anchors;
pub mod checkers;
pub mod extra_fields;
pub mod ffi;
pub mod report;
pub mod signatures;
pub mod sniffer;

pub use anchors::Anchor;
pub use checkers::{check_compliance_buffer, check_compliance_file};
pub use extra_fields::{ParsedExtraFields, RawExtraField, RawExtraFieldsIter};
pub use ffi::*;
pub use report::{ComplianceIssue, ComplianceReport, ComplianceSeverity, ComplianceStandard, StandardCitation};
pub use signatures::{CompoundFormat, DetectedFormat, SignatureEntry, PRIORITIZED_SIGNATURES};
pub use sniffer::{detect_format_buffer, detect_format_file, SniffResult};
