// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-level C-ABI / FFI archive inspection, extraction, and creation unified entries.
//!
//! Enforces:
//! 1. Panic safety: FFI exception barriers via `std::panic::catch_unwind` on all entry points.
//! 2. Security invariant II: ZipSlip path sanitization & traversal defense.
//! 3. Two-stage deferred bottom-up metadata and permission application.
//! 4. Hardware APFS extent preallocation.

mod create;
mod extract;
mod guards;
mod in_place;
mod inspect;
mod repair;
pub mod split;
mod sys;
mod tar;
mod zip;

pub use create::ttzip_rust_create_archive;
pub use extract::ttzip_rust_extract_archive;
pub use in_place::*;
pub use inspect::ttzip_rust_inspect_archive;
pub use repair::*;
pub use split::*;
pub use tar::{ttzip_rust_tar_extract_entry, ttzip_rust_tar_scan_entries};
pub use zip::ttzip_rust_zip_scan_entries;


