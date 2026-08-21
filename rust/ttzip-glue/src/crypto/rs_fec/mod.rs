// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Reed-Solomon Forward Error Correction (FEC) & Archive Recovery Record Engine.

pub mod cauchy;
pub mod gf8;
pub mod inspect;
pub mod record_format;
pub mod recovery_record;
pub mod repair;
#[cfg(test)]
pub mod tests;

pub use cauchy::{create_cauchy_matrix, invert_matrix, ReedSolomonEngine};
pub use gf8::{
    compute_nibble_tables, gf_add, gf_div, gf_inv, gf_mul, gf_pow, gf_sub, gf8_mul_add_slice,
    scalar_gf8_mul_add_raw, EXP_TABLE, LOG_TABLE,
};
pub use recovery_record::{
    append_recovery_record_to_file, create_recovery_record, create_recovery_record_streaming,
    inspect_recovery_record, inspect_recovery_record_reader, repair_archive_data,
    repair_archive_file, repair_archive_file_streaming, RecoveryRecordInfo,
    StreamingCauchyAccumulator, DEFAULT_SLICE_SIZE, MAGIC_FOOTER, MAGIC_HEADER,
};
