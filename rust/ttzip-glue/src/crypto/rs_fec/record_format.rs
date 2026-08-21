// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Recovery record format specifications, metadata definitions, and streaming Cauchy accumulator.

use super::cauchy::create_cauchy_matrix;
use super::gf8::gf8_mul_add_slice;
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha256::FastSha256;
use crate::types::TTZipStatus;
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::path::Path;

pub const MAGIC_HEADER: &[u8; 4] = b"TTZR";
pub const MAGIC_FOOTER: &[u8; 4] = b"TTRC";
pub const DEFAULT_SLICE_SIZE: usize = 65536; // 64 KB

#[inline]
pub fn bytes_to_hex(bytes: &[u8]) -> String {
    const HEX_CHARS: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        s.push(HEX_CHARS[(b >> 4) as usize] as char);
        s.push(HEX_CHARS[(b & 0x0F) as usize] as char);
    }
    s
}

/// Parsed metadata for a TTZip archive recovery record.
#[derive(Debug, Clone, PartialEq)]
pub struct RecoveryRecordInfo {
    pub slice_size: usize,
    pub data_slices_count: usize,
    pub parity_slices_count: usize,
    pub protected_payload_length: u64,
    pub root_hash: [u8; 32],
    pub redundancy_percent: f64,
}

impl RecoveryRecordInfo {
    pub fn root_hash_hex(&self) -> String {
        bytes_to_hex(&self.root_hash)
    }
}

/// Streaming Cauchy Accumulator maintaining constant RAM overhead (<4MB).
pub struct StreamingCauchyAccumulator {
    pub slice_size: usize,
    pub total_k: usize,
    pub total_m: usize,
    pub payload_len: u64,
    cauchy_matrix: Vec<u8>,
    parity_slices: Vec<Vec<u8>>,
    data_crcs: Vec<u32>,
    hasher: FastSha256,
}

impl StreamingCauchyAccumulator {
    pub fn new(
        payload_len: u64,
        redundancy_percent: f64,
        mut slice_size: usize,
    ) -> Result<Self, TTZipStatus> {
        if payload_len == 0 {
            return Err(TTZipStatus::ErrInvalidParam);
        }
        if slice_size == 0 {
            slice_size = DEFAULT_SLICE_SIZE;
        }

        let total_k = ((payload_len + slice_size as u64 - 1) / slice_size as u64) as usize;
        if total_k == 0 || total_k > 200 {
            return Err(TTZipStatus::ErrInvalidParam);
        }

        let raw_m = ((total_k as f64) * (redundancy_percent / 100.0)).ceil() as usize;
        let total_m = raw_m.clamp(1, total_k.min(256 - total_k));

        let cauchy_matrix = create_cauchy_matrix(total_m, total_k);
        let parity_slices = vec![vec![0u8; slice_size]; total_m];
        let data_crcs = Vec::with_capacity(total_k);
        let hasher = FastSha256::new();

        Ok(Self {
            slice_size,
            total_k,
            total_m,
            payload_len,
            cauchy_matrix,
            parity_slices,
            data_crcs,
            hasher,
        })
    }

    pub fn feed_slice(&mut self, slice_index: usize, chunk: &[u8]) -> Result<(), TTZipStatus> {
        if slice_index >= self.total_k || chunk.is_empty() || chunk.len() > self.slice_size {
            return Err(TTZipStatus::ErrInvalidParam);
        }
        self.hasher.update(chunk);

        let mut padded = vec![0u8; self.slice_size];
        padded[..chunk.len()].copy_from_slice(chunk);
        let crc = crc32_fast(0, &padded);
        self.data_crcs.push(crc);

        for p in 0..self.total_m {
            let coeff = self.cauchy_matrix[p * self.total_k + slice_index];
            if coeff != 0 {
                gf8_mul_add_slice(coeff, &padded, &mut self.parity_slices[p]);
            }
        }
        Ok(())
    }

    pub fn finalize(self) -> (RecoveryRecordInfo, Vec<u8>) {
        let root_hash = self.hasher.finalize();
        let total_k = self.total_k;
        let total_m = self.total_m;
        let slice_size = self.slice_size;
        let payload_len = self.payload_len;

        let block_capacity = 54 + (total_k * 4) + total_m * (6 + slice_size) + 12;
        let mut block = Vec::with_capacity(block_capacity);

        // 1. Header (54B)
        block.extend_from_slice(MAGIC_HEADER);
        block.extend_from_slice(&0x0100u16.to_le_bytes());
        block.extend_from_slice(&(slice_size as u32).to_le_bytes());
        block.extend_from_slice(&(total_k as u16).to_le_bytes());
        block.extend_from_slice(&(total_m as u16).to_le_bytes());
        block.extend_from_slice(&payload_len.to_le_bytes());
        block.extend_from_slice(&root_hash);

        // 2. Data Slices CRC table
        for &crc in &self.data_crcs {
            block.extend_from_slice(&crc.to_le_bytes());
        }

        // 3. Parity Slices
        for (idx, p_slice) in self.parity_slices.iter().enumerate() {
            block.extend_from_slice(&(idx as u16).to_le_bytes());
            let p_crc = crc32_fast(0, p_slice);
            block.extend_from_slice(&p_crc.to_le_bytes());
            block.extend_from_slice(p_slice);
        }

        // 4. Footer Anchor
        block.extend_from_slice(MAGIC_FOOTER);
        let total_block_size = (block.len() + 8) as u64;
        block.extend_from_slice(&total_block_size.to_le_bytes());

        let redundancy_percent = (total_m as f64 / total_k as f64) * 100.0;
        let info = RecoveryRecordInfo {
            slice_size,
            data_slices_count: total_k,
            parity_slices_count: total_m,
            protected_payload_length: payload_len,
            root_hash,
            redundancy_percent,
        };

        (info, block)
    }
}

/// Generates an encoded recovery record block via streaming reader (<4MB RAM).
pub fn create_recovery_record_streaming<R: Read>(
    reader: &mut R,
    payload_len: u64,
    redundancy_percent: f64,
    slice_size: usize,
) -> Result<(RecoveryRecordInfo, Vec<u8>), TTZipStatus> {
    let mut acc = StreamingCauchyAccumulator::new(payload_len, redundancy_percent, slice_size)?;
    let actual_slice_size = acc.slice_size;
    let mut chunk_buf = vec![0u8; actual_slice_size];

    for d in 0..acc.total_k {
        let expected = std::cmp::min(
            actual_slice_size as u64,
            payload_len - (d as u64 * actual_slice_size as u64),
        ) as usize;
        reader
            .read_exact(&mut chunk_buf[..expected])
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        acc.feed_slice(d, &chunk_buf[..expected])?;
    }

    Ok(acc.finalize())
}

/// In-memory recovery record generation wrapper.
pub fn create_recovery_record(
    payload: &[u8],
    redundancy_percent: f64,
    slice_size: usize,
) -> Result<Vec<u8>, TTZipStatus> {
    let mut cursor = std::io::Cursor::new(payload);
    let (_, block) = create_recovery_record_streaming(
        &mut cursor,
        payload.len() as u64,
        redundancy_percent,
        slice_size,
    )?;
    Ok(block)
}

/// Appends recovery record trailer to an existing archive file streamingly.
pub fn append_recovery_record_to_file(
    file_path: &Path,
    redundancy_percent: f64,
    slice_size: usize,
) -> Result<RecoveryRecordInfo, TTZipStatus> {
    let mut file = File::open(file_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let payload_len = file
        .metadata()
        .map_err(|_| TTZipStatus::ErrOpenFailed)?
        .len();
    if payload_len == 0 {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let (info, rec_block) = create_recovery_record_streaming(
        &mut file,
        payload_len,
        redundancy_percent,
        slice_size,
    )?;
    drop(file);

    let mut out_file = OpenOptions::new()
        .append(true)
        .open(file_path)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    out_file
        .write_all(&rec_block)
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    out_file
        .flush()
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    Ok(info)
}
