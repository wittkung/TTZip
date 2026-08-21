// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 64KB Chunk Self-Healing Recovery Record Generation and Repair Engine.
//!
//! Formats TTZip `TTZR` recovery header and `TTRC` footer anchor.

use super::cauchy::ReedSolomonEngine;
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
fn bytes_to_hex(bytes: &[u8]) -> String {
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
    pub root_hash: String,
    pub redundancy_percent: f64,
}

/// Generates an encoded recovery record block for a given payload.
pub fn create_recovery_record(
    payload: &[u8],
    redundancy_percent: f64,
    mut slice_size: usize,
) -> Result<Vec<u8>, TTZipStatus> {
    if payload.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }
    if slice_size == 0 {
        slice_size = DEFAULT_SLICE_SIZE;
    }

    let payload_len = payload.len() as u64;
    let total_k = (payload.len() + slice_size - 1) / slice_size;
    if total_k == 0 || total_k > 200 {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let raw_m = ((total_k as f64) * (redundancy_percent / 100.0)).ceil() as usize;
    let total_m = raw_m.clamp(1, total_k.min(256 - total_k));

    // 1. Slice original payload into K chunks and compute per-slice CRC32
    let mut data_slices = Vec::with_capacity(total_k);
    let mut data_crcs = Vec::with_capacity(total_k);

    for i in 0..total_k {
        let start = i * slice_size;
        let end = (start + slice_size).min(payload.len());
        let mut slice = vec![0u8; slice_size];
        slice[..(end - start)].copy_from_slice(&payload[start..end]);
        let crc = crc32_fast(0, &slice);
        data_crcs.push(crc);
        data_slices.push(slice);
    }

    // 2. Compute M parity slices
    let rs = ReedSolomonEngine::new(total_k, total_m)?;
    let mut parity_slices = vec![vec![0u8; slice_size]; total_m];
    let data_refs: Vec<&[u8]> = data_slices.iter().map(|s| s.as_slice()).collect();
    let mut parity_mut_refs: Vec<&mut [u8]> =
        parity_slices.iter_mut().map(|s| s.as_mut_slice()).collect();
    rs.encode(&data_refs, &mut parity_mut_refs)?;

    // 3. Compute root SHA-256
    let root_hash_hex = bytes_to_hex(&FastSha256::digest(payload));

    // 4. Construct Header & Body
    let mut block = Vec::with_capacity(54 + (total_k * 4) + total_m * (6 + slice_size) + 12);
    block.extend_from_slice(MAGIC_HEADER);
    block.extend_from_slice(&0x0100u16.to_le_bytes()); // Version
    block.extend_from_slice(&(slice_size as u32).to_le_bytes());
    block.extend_from_slice(&(total_k as u16).to_le_bytes());
    block.extend_from_slice(&(total_m as u16).to_le_bytes());
    block.extend_from_slice(&payload_len.to_le_bytes());

    let mut hash_buf = [0u8; 32];
    let hash_bytes = root_hash_hex.as_bytes();
    let copy_len = hash_bytes.len().min(32);
    hash_buf[..copy_len].copy_from_slice(&hash_bytes[..copy_len]);
    block.extend_from_slice(&hash_buf);

    // 5. Append Data Slices CRC table
    for &crc in &data_crcs {
        block.extend_from_slice(&crc.to_le_bytes());
    }

    // 6. Append Parity Slices
    for (idx, p_slice) in parity_slices.iter().enumerate() {
        block.extend_from_slice(&(idx as u16).to_le_bytes());
        let p_crc = crc32_fast(0, p_slice);
        block.extend_from_slice(&p_crc.to_le_bytes());
        block.extend_from_slice(p_slice);
    }

    // 7. Append Footer Anchor
    block.extend_from_slice(MAGIC_FOOTER);
    let total_block_size = (block.len() + 8) as u64;
    block.extend_from_slice(&total_block_size.to_le_bytes());

    Ok(block)
}

/// Inspects recovery record information if present at the end of `archive_data`.
pub fn inspect_recovery_record(
    archive_data: &[u8],
) -> Result<Option<RecoveryRecordInfo>, TTZipStatus> {
    if archive_data.len() < 64 {
        return Ok(None);
    }

    let scan_len = archive_data.len().min(128);
    let scan_start = archive_data.len() - scan_len;
    let scan_slice = &archive_data[scan_start..];

    let footer_pos = match scan_slice.windows(4).rposition(|w| w == MAGIC_FOOTER) {
        Some(pos) => scan_start + pos,
        None => return Ok(None),
    };

    if footer_pos + 12 > archive_data.len() {
        return Ok(None);
    }

    let total_block_size = u64::from_le_bytes(
        archive_data[footer_pos + 4..footer_pos + 12]
            .try_into()
            .unwrap(),
    );
    if total_block_size as usize > archive_data.len() || total_block_size < 64 {
        return Ok(None);
    }

    let header_offset = archive_data.len() - (total_block_size as usize);
    let header = &archive_data[header_offset..];
    if header.len() < 54 || &header[..4] != MAGIC_HEADER {
        return Ok(None);
    }

    let slice_size = u32::from_le_bytes(header[6..10].try_into().unwrap()) as usize;
    let total_k = u16::from_le_bytes(header[10..12].try_into().unwrap()) as usize;
    let total_m = u16::from_le_bytes(header[12..14].try_into().unwrap()) as usize;
    let protected_len = u64::from_le_bytes(header[14..22].try_into().unwrap());
    let root_hash = String::from_utf8_lossy(&header[22..54])
        .trim_matches(char::from(0))
        .to_string();

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

/// Verifies and performs self-healing restoration on damaged archive data in memory.
pub fn repair_archive_data(archive_data: &mut Vec<u8>) -> Result<bool, TTZipStatus> {
    let info = match inspect_recovery_record(archive_data)? {
        Some(info) => info,
        None => return Ok(false),
    };

    let payload_len = info.protected_payload_length as usize;
    if payload_len > archive_data.len() {
        return Ok(false);
    }

    let current_hash = bytes_to_hex(&FastSha256::digest(&archive_data[..payload_len]));
    if current_hash.starts_with(&info.root_hash) || info.root_hash.starts_with(&current_hash) {
        return Ok(true); // Intact
    }

    let k = info.data_slices_count;
    let m = info.parity_slices_count;
    let slice_size = info.slice_size;
    let total_rec_size = archive_data.len() - payload_len;
    let rec_offset = payload_len;

    if total_rec_size < 54 + (k * 4) {
        return Ok(false);
    }

    // 1. Read Expected Data Slices CRCs
    let mut expected_crcs = Vec::with_capacity(k);
    for i in 0..k {
        let offset = rec_offset + 54 + (i * 4);
        let crc = u32::from_le_bytes(archive_data[offset..offset + 4].try_into().unwrap());
        expected_crcs.push(crc);
    }

    // 2. Classify intact vs corrupted data slices
    let mut intact_shards: Vec<(usize, Vec<u8>)> = Vec::new();
    let mut missing_indices = Vec::new();

    for i in 0..k {
        let start = i * slice_size;
        let end = (start + slice_size).min(payload_len);
        let mut slice = vec![0u8; slice_size];
        if start < payload_len {
            slice[..(end - start)].copy_from_slice(&archive_data[start..end]);
        }
        let actual_crc = crc32_fast(0, &slice);
        if actual_crc == expected_crcs[i] {
            intact_shards.push((i, slice));
        } else {
            missing_indices.push(i);
        }
    }

    if missing_indices.is_empty() {
        return Ok(true);
    }

    // 3. Read and verify Parity Slices
    let mut p_offset = rec_offset + 54 + (k * 4);
    for p_idx in 0..m {
        if p_offset + 6 + slice_size <= archive_data.len() {
            let p_expected_crc =
                u32::from_le_bytes(archive_data[p_offset + 2..p_offset + 6].try_into().unwrap());
            let p_slice = archive_data[p_offset + 6..p_offset + 6 + slice_size].to_vec();
            let p_actual_crc = crc32_fast(0, &p_slice);
            if p_actual_crc == p_expected_crc {
                intact_shards.push((k + p_idx, p_slice));
            }
            p_offset += 6 + slice_size;
        }
    }

    if intact_shards.len() < k {
        return Ok(false); // Insufficient redundancy to repair
    }

    // 4. Reconstruct missing shards
    let rs = ReedSolomonEngine::new(k, m)?;
    let chosen_shards = &intact_shards[..k];
    let available_refs: Vec<&[u8]> = chosen_shards.iter().map(|s| s.1.as_slice()).collect();
    let available_indices: Vec<usize> = chosen_shards.iter().map(|s| s.0).collect();

    let mut reconstructed_buffers = vec![vec![0u8; slice_size]; missing_indices.len()];
    let mut recon_mut_refs: Vec<&mut [u8]> = reconstructed_buffers
        .iter_mut()
        .map(|s| s.as_mut_slice())
        .collect();

    rs.decode(
        &available_refs,
        &available_indices,
        &missing_indices,
        &mut recon_mut_refs,
    )?;

    // 5. Apply reconstructed slices into original payload
    for (m_idx, &missing_i) in missing_indices.iter().enumerate() {
        let start = missing_i * slice_size;
        let end = (start + slice_size).min(payload_len);
        archive_data[start..end].copy_from_slice(&reconstructed_buffers[m_idx][..(end - start)]);
    }

    let restored_hash = bytes_to_hex(&FastSha256::digest(&archive_data[..payload_len]));
    if restored_hash.starts_with(&info.root_hash) || info.root_hash.starts_with(&restored_hash) {
        Ok(true)
    } else {
        Ok(false)
    }
}

/// Appends recovery record trailer to an existing archive file.
pub fn append_recovery_record_to_file(
    file_path: &Path,
    redundancy_percent: f64,
    slice_size: usize,
) -> Result<RecoveryRecordInfo, TTZipStatus> {
    let mut file = File::open(file_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let mut data = Vec::new();
    file.read_to_end(&mut data)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    drop(file);

    let rec_block = create_recovery_record(&data, redundancy_percent, slice_size)?;
    let mut out_file = OpenOptions::new()
        .append(true)
        .open(file_path)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    out_file
        .write_all(&rec_block)
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    data.extend_from_slice(&rec_block);
    let info = inspect_recovery_record(&data)?
        .ok_or(TTZipStatus::ErrCorruptHeader)?;
    Ok(info)
}

/// Repairs an archive file in-place using its recovery record trailer.
pub fn repair_archive_file(file_path: &Path) -> Result<bool, TTZipStatus> {
    let mut file = File::open(file_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let mut data = Vec::new();
    file.read_to_end(&mut data)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    drop(file);

    let repaired = repair_archive_data(&mut data)?;
    if repaired {
        let mut out_file = File::create(file_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        out_file
            .write_all(&data)
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    }
    Ok(repaired)
}
