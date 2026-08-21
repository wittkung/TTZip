// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 64KB Chunk Self-Healing Recovery Record Streaming Generation and Repair Engine.

pub use super::inspect::{inspect_recovery_record, inspect_recovery_record_reader};
pub use super::record_format::{
    append_recovery_record_to_file, bytes_to_hex, create_recovery_record,
    create_recovery_record_streaming, RecoveryRecordInfo, StreamingCauchyAccumulator,
    DEFAULT_SLICE_SIZE, MAGIC_FOOTER, MAGIC_HEADER,
};
pub use super::repair::{repair_archive_data, repair_archive_file, repair_archive_file_streaming};
