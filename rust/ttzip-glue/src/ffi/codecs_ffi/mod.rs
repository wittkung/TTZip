// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for single-format codecs.
//!
//! Every exported entry point contains a `std::panic::catch_unwind` exception barrier
//! to guarantee that internal panics never unwind across foreign language boundaries.

mod brotli;
mod deflate;
mod fast_blocks;
mod lzma2;
mod snappy;
mod zstd;

pub use brotli::*;
pub use deflate::*;
pub use fast_blocks::*;
pub use lzma2::*;
pub use snappy::*;
pub use zstd::*;
