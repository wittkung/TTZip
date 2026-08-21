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
pub use bench::*;
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

static VERSION_C_STR: &[u8] = b"1.0.0-rust-glue\0";

/// Returns static version string for TTZip Rust Glue layer.
#[no_mangle]
pub extern "C" fn ttzip_rust_version() -> *const c_char {
    VERSION_C_STR.as_ptr() as *const c_char
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
        TTZipStatus::Ok => b"OK\0".as_ptr() as *const c_char,
        TTZipStatus::Eof => b"EOF\0".as_ptr() as *const c_char,
        TTZipStatus::Cancelled => b"Cancelled\0".as_ptr() as *const c_char,
        TTZipStatus::ErrInvalidParam => b"Invalid Parameter\0".as_ptr() as *const c_char,
        TTZipStatus::ErrFileNotFound => b"File Not Found\0".as_ptr() as *const c_char,
        TTZipStatus::ErrMmapFailed => b"Mmap Failed\0".as_ptr() as *const c_char,
        TTZipStatus::ErrCorruptHeader => b"Corrupt Header\0".as_ptr() as *const c_char,
        TTZipStatus::ErrInvalidOffset => b"Invalid Offset\0".as_ptr() as *const c_char,
        TTZipStatus::ErrArchiveInitFailed => b"Archive Init Failed\0".as_ptr() as *const c_char,
        TTZipStatus::ErrOpenFailed => b"Open Failed\0".as_ptr() as *const c_char,
        TTZipStatus::ErrPathTooLong => b"Path Too Long\0".as_ptr() as *const c_char,
        TTZipStatus::ErrOutOfMemory => b"Out Of Memory\0".as_ptr() as *const c_char,
        TTZipStatus::ErrInvalidPassword => b"Invalid Password\0".as_ptr() as *const c_char,
        TTZipStatus::ErrExtractionFailed => b"Extraction Failed\0".as_ptr() as *const c_char,
        TTZipStatus::ErrCompressionFailed => b"Compression Failed\0".as_ptr() as *const c_char,
        TTZipStatus::ErrSecurityViolation => b"Security Violation\0".as_ptr() as *const c_char,
        TTZipStatus::ErrPanicCaught => b"Panic Caught\0".as_ptr() as *const c_char,
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
