// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Universal Character Set Detection and Zero-Allocation Transcoding Engine.
//!
//! Provides SIMD-accelerated ASCII fast paths, strict UTF-8 validation,
//! multi-byte Coding State Machine (CSM) pruning, and 2-byte Bigram frequency
//! probability scoring for CJK and legacy Windows encodings (GB18030, Shift-JIS, Big5, EUC-KR, Windows-1252).

pub mod csm;
pub mod detector;
pub mod ffi;
pub mod tables;
pub mod transcode;

#[cfg(test)]
pub mod tests;

pub use csm::{CharsetKind, CodingStateMachine, CsmState};
pub use detector::{detect_charset, detect_charset_with_confidence};
pub use ffi::{ttzip_rust_detect_charset, ttzip_rust_sanitize_filename};
pub use transcode::{
    lookup_encoding, sanitize_filename, sanitize_filename_to_slice, transcode_to_utf8,
};
