// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Core types, error codes, and shared data structures for TTZip Rust Glue.

use libc::{c_char, c_void};
use zeroize::Zeroize;

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipStatus {
    Ok = 0,
    Eof = 1,
    Cancelled = 2,
    ErrInvalidParam = -1,
    ErrFileNotFound = -2,
    ErrMmapFailed = -3,
    ErrCorruptHeader = -4,
    ErrInvalidOffset = -5,
    ErrArchiveInitFailed = -6,
    ErrOpenFailed = -7,
    ErrPathTooLong = -8,
    ErrOutOfMemory = -9,
    ErrInvalidPassword = -10,
    ErrExtractionFailed = -11,
    ErrCompressionFailed = -12,
    ErrSecurityViolation = -30,
    ErrPanicCaught = -99,
}

impl TTZipStatus {
    #[inline]
    pub fn to_i32(self) -> i32 {
        self as i32
    }

    pub fn as_str(self) -> &'static str {
        match self {
            TTZipStatus::Ok => "Operation completed successfully",
            TTZipStatus::Eof => "End of archive / stream reached",
            TTZipStatus::Cancelled => "Operation cancelled by user",
            TTZipStatus::ErrInvalidParam => "Invalid parameter or configuration",
            TTZipStatus::ErrFileNotFound => "Archive or source file not found",
            TTZipStatus::ErrMmapFailed => "Memory mapping failed",
            TTZipStatus::ErrCorruptHeader => "Corrupt archive header or signature mismatch",
            TTZipStatus::ErrInvalidOffset => "Invalid entry offset or seek error",
            TTZipStatus::ErrArchiveInitFailed => "Failed to initialize archive context",
            TTZipStatus::ErrOpenFailed => "Failed to open archive stream",
            TTZipStatus::ErrPathTooLong => "File path exceeds system MAXPATHLEN",
            TTZipStatus::ErrOutOfMemory => "Out of memory",
            TTZipStatus::ErrInvalidPassword => "Invalid or missing archive password",
            TTZipStatus::ErrExtractionFailed => "Extraction error",
            TTZipStatus::ErrCompressionFailed => "Compression error",
            TTZipStatus::ErrSecurityViolation => "Security boundary violation (e.g. path traversal)",
            TTZipStatus::ErrPanicCaught => "Internal panic caught at FFI boundary",
        }
    }
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipArchiveFormat {
    Auto = 0,
    Zip = 1,
    SevenZip = 2,
    Tar = 3,
    TarGz = 4,
    TarBz2 = 5,
    TarXz = 6,
    TarZstd = 7,
    Dmg = 8,
    Lzfse = 9,
    Snappy = 10,
    Unknown = 99,
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipCompressionLevel {
    Store = 0,
    Fastest = 1,
    Fast = 3,
    Normal = 6,
    Maximum = 9,
    Ultra = 12,
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipEncryptionMethod {
    None = 0,
    ZipCrypto = 1,
    Aes128 = 2,
    Aes192 = 3,
    Aes256 = 4,
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipLogLevel {
    Debug = 0,
    Info = 1,
    Warning = 2,
    Error = 3,
}

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct TTZipEntryMetadata {
    pub path: *const c_char,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
    pub compression_method: u16,
}

pub type TTZipProgressCallback = Option<
    unsafe extern "C" fn(
        processed_bytes: u64,
        total_bytes: u64,
        current_entry: *const c_char,
        user_data: *mut c_void,
    ) -> bool,
>;

pub type TTZipInspectCallback = Option<
    unsafe extern "C" fn(
        entry: *const TTZipEntryMetadata,
        user_data: *mut c_void,
    ) -> bool,
>;

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct TTZipExtractOptions {
    pub destination_path: *const c_char,
    pub password: *const c_char,
    pub thread_budget: u32,
    pub overwrite_existing: bool,
    pub preserve_permissions: bool,
    pub dry_run: bool,
    pub progress_callback: TTZipProgressCallback,
    pub user_data: *mut c_void,
}

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct TTZipCreateOptions {
    pub format: TTZipArchiveFormat,
    pub level: TTZipCompressionLevel,
    pub encryption: TTZipEncryptionMethod,
    pub password: *const c_char,
    pub thread_budget: u32,
    pub solid_block_size_mb: u32,
    pub progress_callback: TTZipProgressCallback,
    pub user_data: *mut c_void,
}

#[repr(C)]
#[derive(Debug, Clone, Zeroize)]
#[zeroize(drop)]
pub struct TTZipAes256Context {
    pub key: [u8; 32],
    pub iv_or_counter: [u8; 16],
    pub round_keys_enc: [u8; 240], // 15 rounds * 16 bytes
    pub round_keys_dec: [u8; 240],
}
