// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! TTZip Native Core Glue Layer in Safe Rust.
//!
//! Provides hardware-accelerated crypto/checksum routines, safe codec wrappers,
//! unified archive streaming, ZIP/7z archive engines, and C-ABI export interfaces for Swift 6 (`TTZipCore`).

#![allow(non_camel_case_types)]
#![allow(clippy::missing_safety_doc)]
#![allow(ambiguous_glob_reexports)]

pub mod analytics;
pub mod archive;
pub mod bench;
pub mod benchmark;
pub mod charset;
pub mod codecs;
pub mod crypto;
pub mod ffi;
pub mod fs;
pub mod platform;
pub mod runtime;
pub mod security;
pub mod sevenz;
pub mod standards;
pub mod testing;
pub mod types;
pub mod vfs;
pub mod zip;

pub use analytics::*;
pub use archive::{
    compute_volume_path, detect_volume_chain, find_next_pk_signature, repair_damaged_tar,
    repair_damaged_zip, SplitVolumeWriter, VirtualMultiVolumeReader, VolumeNamingScheme,
    VolumeSegment,
};
pub use benchmark::*;
pub use charset::*;
pub use codecs::*;
pub use crypto::*;
pub use ffi::*;
pub use fs::*;
pub use platform::*;
pub use runtime::*;
pub use security::*;
pub use sevenz::{create_7z_archive, decode_7z_solid_payload, parse_7z_metadata, SevenZArchive, SevenZFileMeta, SevenZHeaderInfo};
pub use standards::*;
pub use testing::*;
pub use types::*;
pub use vfs::*;
pub use zip::{create_zip_archive, ZipArchive, ZipEntry, ZipInputItem};

use libc::c_char;
use std::panic::catch_unwind;

/// Returns static version string for TTZip Rust Glue layer.
#[no_mangle]
pub extern "C" fn ttzip_rust_version() -> *const c_char {
    c"1.0.0-rust-glue".as_ptr()
}

/// Initializes TTZip Rust runtime and subsystem states.
#[no_mangle]
pub extern "C" fn ttzip_rust_init() -> TTZipStatus {
    let result = catch_unwind(|| {
        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Converts a TTZipStatus code to a human-readable English string description.
#[no_mangle]
pub extern "C" fn ttzip_rust_status_string(status: TTZipStatus) -> *const c_char {
    match status {
        TTZipStatus::Ok => c"OK".as_ptr(),
        TTZipStatus::Eof => c"EOF".as_ptr(),
        TTZipStatus::Cancelled => c"Cancelled".as_ptr(),
        TTZipStatus::ErrInvalidParam => c"Invalid Parameter".as_ptr(),
        TTZipStatus::ErrFileNotFound => c"File Not Found".as_ptr(),
        TTZipStatus::ErrMmapFailed => c"Mmap Failed".as_ptr(),
        TTZipStatus::ErrCorruptHeader => c"Corrupt Header".as_ptr(),
        TTZipStatus::ErrInvalidOffset => c"Invalid Offset".as_ptr(),
        TTZipStatus::ErrArchiveInitFailed => c"Archive Init Failed".as_ptr(),
        TTZipStatus::ErrOpenFailed => c"Open Failed".as_ptr(),
        TTZipStatus::ErrPathTooLong => c"Path Too Long".as_ptr(),
        TTZipStatus::ErrOutOfMemory => c"Out Of Memory".as_ptr(),
        TTZipStatus::ErrInvalidPassword => c"Invalid Password".as_ptr(),
        TTZipStatus::ErrExtractionFailed => c"Extraction Failed".as_ptr(),
        TTZipStatus::ErrCompressionFailed => c"Compression Failed".as_ptr(),
        TTZipStatus::ErrSecurityViolation => c"Security Violation".as_ptr(),
        TTZipStatus::ErrPanicCaught => c"Panic Caught".as_ptr(),
    }
}

/// Returns true if hardware acceleration (ARM64 NEON / Crypto extensions) is active.
#[no_mangle]
pub extern "C" fn ttzip_rust_is_hardware_accelerated() -> bool {
    #[cfg(target_arch = "aarch64")]
    {
        true
    }
    #[cfg(not(target_arch = "aarch64"))]
    {
        false
    }
}
