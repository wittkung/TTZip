// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive streaming and libarchive adapter module.

pub mod stream_adapter;
pub mod tar;

pub use stream_adapter::*;
pub use tar::*;
