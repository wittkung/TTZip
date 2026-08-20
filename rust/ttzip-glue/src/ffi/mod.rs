// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! FFI module declarations and C-ABI export symbols.

pub mod archive_ffi;
pub mod codecs_ffi;
pub mod crypto_ffi;
pub mod fs_ffi;
pub mod runtime_ffi;
pub mod stream_ffi;

pub use archive_ffi::*;
pub use codecs_ffi::*;
pub use crypto_ffi::*;
pub use fs_ffi::*;
pub use runtime_ffi::*;
pub use stream_ffi::*;
