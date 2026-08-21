// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Security, sandbox isolation, path defense, and threat scanning modules.

pub mod path_sanitizer;

#[cfg(test)]
pub mod tests;

pub use path_sanitizer::*;
