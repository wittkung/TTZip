// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive streaming and libarchive adapter module.

pub mod repair;
pub mod split;
pub mod stream_adapter;
pub mod tar;

pub use repair::*;
pub use split::{
    compute_volume_path, detect_volume_chain, SplitVolumeWriter, VirtualMultiVolumeReader,
    VolumeNamingScheme, VolumeSegment,
};
pub use stream_adapter::*;
pub use tar::*;

