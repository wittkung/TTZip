// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Solid Stream Decoder and Selective Extraction Engine.

pub mod archive;
pub mod payload;
pub mod stream;

pub use archive::SevenZArchive;
pub use payload::decode_7z_solid_payload;
pub use stream::extract_entry_bytes_stream;
