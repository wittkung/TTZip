// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Inspection and parsing routines for TTZip recovery records.

use super::record_format::{RecoveryRecordInfo, MAGIC_FOOTER, MAGIC_HEADER};
use crate::types::TTZipStatus;
use std::io::{Read, Seek, SeekFrom};

/// Inspects recovery record information from any seekable reader.
pub fn inspect_recovery_record_reader<R: Read + Seek>(
    reader: &mut R,
) -> Result<Option<RecoveryRecordInfo>, TTZipStatus> {
    let file_size = reader
        .seek(SeekFrom::End(0))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    if file_size < 64 {
        return Ok(None);
    }
    let scan_len = std::cmp::min(128, file_size) as usize;
    reader
        .seek(SeekFrom::End(-(scan_len as i64)))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut scan_buf = vec![0u8; scan_len];
    reader
        .read_exact(&mut scan_buf)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;

    let footer_pos = match scan_buf.windows(4).rposition(|w| w == MAGIC_FOOTER) {
        Some(pos) => (file_size - scan_len as u64) + pos as u64,
        None => return Ok(None),
    };

    if footer_pos + 12 > file_size {
        return Ok(None);
    }

    reader
        .seek(SeekFrom::Start(footer_pos + 4))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut size_buf = [0u8; 8];
    reader
        .read_exact(&mut size_buf)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let total_block_size = u64::from_le_bytes(size_buf);

    if total_block_size > file_size || total_block_size < 64 {
        return Ok(None);
    }

    let header_offset = file_size - total_block_size;
    reader
        .seek(SeekFrom::Start(header_offset))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut header = [0u8; 54];
    reader
        .read_exact(&mut header)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;

    if &header[..4] != MAGIC_HEADER {
        return Ok(None);
    }

    let slice_size = u32::from_le_bytes(header[6..10].try_into().unwrap()) as usize;
    let total_k = u16::from_le_bytes(header[10..12].try_into().unwrap()) as usize;
    let total_m = u16::from_le_bytes(header[12..14].try_into().unwrap()) as usize;
    let protected_len = u64::from_le_bytes(header[14..22].try_into().unwrap());
    let mut root_hash = [0u8; 32];
    root_hash.copy_from_slice(&header[22..54]);

    let redundancy_percent = if total_k > 0 {
        (total_m as f64 / total_k as f64) * 100.0
    } else {
        0.0
    };

    Ok(Some(RecoveryRecordInfo {
        slice_size,
        data_slices_count: total_k,
        parity_slices_count: total_m,
        protected_payload_length: protected_len,
        root_hash,
        redundancy_percent,
    }))
}

/// Inspects recovery record information if present at the end of `archive_data`.
pub fn inspect_recovery_record(
    archive_data: &[u8],
) -> Result<Option<RecoveryRecordInfo>, TTZipStatus> {
    let mut cursor = std::io::Cursor::new(archive_data);
    inspect_recovery_record_reader(&mut cursor)
}
