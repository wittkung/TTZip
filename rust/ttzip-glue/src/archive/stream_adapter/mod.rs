// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Stream adapter bridging `std::io::{Read, Write, Seek}` to `libarchive` C callbacks.
//!
//! Enforces:
//! 1. Memory bound: $\le 64\text{MB}$ RSS resident memory limit with micro-buffering (64KB - 2MB).
//! 2. Panic safety: FFI exception barriers via `std::panic::catch_unwind` on all trampoline entry points.
//! 3. Pinned callback state (`Pin<Box<StreamReaderState<R>>>`) ensuring stable raw pointers.

pub mod read;
pub mod seek;
pub mod write;

#[cfg(test)]
mod tests;

pub use read::*;
pub use seek::*;
pub use write::*;

/// Libarchive status constants.
pub const ARCHIVE_OK: libc::c_int = 0;
pub const ARCHIVE_EOF: libc::c_int = 1;
pub const ARCHIVE_RETRY: libc::c_int = -10;
pub const ARCHIVE_WARN: libc::c_int = -20;
pub const ARCHIVE_FAILED: libc::c_int = -25;
pub const ARCHIVE_FATAL: libc::c_int = -30;

/// Default micro-buffer size: 64 KB.
pub const DEFAULT_STREAM_BUFFER_SIZE: usize = 64 * 1024;
/// Maximum allowable buffer capacity per stream: 2 MB.
pub const MAX_STREAM_BUFFER_SIZE: usize = 2 * 1024 * 1024;
/// Task hard limit for resident memory allocation: 64 MB.
pub const MAX_RESIDENT_MEMORY_MB: usize = 64;

/// Stream pipeline operating mode conforming to `contracts/ttzip_stream_contract.json`.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TTZipStreamMode {
    ReadSequential,
    ReadSeekable,
    WriteSequential,
    WriteChunkedArena,
}

/// State snapshot for stream progress monitoring and contract compliance.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StreamStateSnapshot {
    pub bytes_consumed: u64,
    pub bytes_written: u64,
    pub is_eof: bool,
    pub has_error: bool,
    pub last_error_msg: Option<String>,
}
