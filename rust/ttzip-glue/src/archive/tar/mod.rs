// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pure Safe Rust TAR Engine (POSIX ustar, GNU TAR, POSIX.1-2001 PAX).
//!
//! Provides zero-copy parsing, Rayon multi-core parallel extraction,
//! streaming PAX generation, and hardware APFS extent preallocation.

pub mod header;
pub mod pax;
pub mod reader;
pub mod scanner;
pub mod writer;

#[cfg(test)]
mod tests;

pub use header::{
    build_tar_header_block, compute_tar_checksum, format_numeric, format_octal, is_tar_zero_block,
    parse_numeric, parse_octal, parse_tar_header_block, verify_tar_checksum, TarHeader,
    MAGIC_GNU, MAGIC_USTAR, TAR_BLOCK_SIZE, TYPE_BLOCK_SPECIAL, TYPE_CHAR_SPECIAL, TYPE_CONTIGUOUS,
    TYPE_DIRECTORY, TYPE_FIFO, TYPE_GNU_LONGLINK, TYPE_GNU_LONGNAME, TYPE_HARDLINK,
    TYPE_PAX_EXT_HEADER, TYPE_PAX_GLOBAL_HEADER, TYPE_REGULAR, TYPE_REGULAR_ALT, TYPE_SOLARIS_EXT,
    TYPE_SYMLINK, VERSION_USTAR,
};
pub use pax::{build_pax_payload, format_pax_record, parse_pax_data, parse_pax_timestamp, PaxAttributes};
pub use reader::{TarArchive, TarExtractReport};
pub use scanner::{TarEntry, TarSeekScanner};
pub use writer::TarWriter;
