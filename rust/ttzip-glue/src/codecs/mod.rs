// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe, RAII-governed single-format compression and character encoding codecs.

pub mod chardet;
pub mod deflate;
pub mod fast_blocks;
pub mod lzma2;
pub mod zstd;

pub use chardet::*;
pub use deflate::*;
pub use fast_blocks::*;
pub use lzma2::*;
pub use zstd::*;
