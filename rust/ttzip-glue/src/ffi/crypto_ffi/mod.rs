// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for TTZip hardware-accelerated crypto & checksum algorithms.

pub mod checksum;
pub mod ciphers;
pub mod fec;
mod recovery;
pub mod recovery_record_ffi;
pub mod vault;

pub use checksum::*;
pub use ciphers::*;
pub use fec::*;
pub use recovery::*;
pub use recovery_record_ffi::*;
pub use vault::*;

