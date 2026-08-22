// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fuzzing Harness & Robustness Test Suite for TTZip.
//!
//! Validates Tasks T006, T007, T008, T009:
//! - T006 [US2]: ZIP Central Directory, Local File Header, and Extra Fields mutation fuzzing.
//! - T007 [US2]: 7z SignatureHeader, Varint codec, and EncodedHeader mutation fuzzing.
//! - T008 [US2]: Safe extraction ZipSlip and path traversal attack injection fuzzing.
//! - T009 [US2]: Stream micro-buffering fault injection and memory bound verification.

#[path = "fuzz_harness/common.rs"]
mod common;

#[path = "fuzz_harness/zip_fuzz.rs"]
mod zip_fuzz;

#[path = "fuzz_harness/sevenz_fuzz.rs"]
mod sevenz_fuzz;

#[path = "fuzz_harness/safe_extract_fuzz.rs"]
mod safe_extract_fuzz;

#[path = "fuzz_harness/stream_fuzz.rs"]
mod stream_fuzz;
