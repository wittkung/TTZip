// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Self-healing in-memory and streaming in-place repair engine for damaged archives.

use super::cauchy::ReedSolomonEngine;
use super::inspect::{inspect_recovery_record, inspect_recovery_record_reader};
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha256::FastSha256;
use crate::types::TTZipStatus;
use std::fs::OpenOptions;
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;

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

    let current_hash = FastSha256::digest(&archive_data[..payload_len]);
    if current_hash == info.root_hash {
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
    if missing_indices.len() > m {
        return Ok(false);
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
        return Ok(false);
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

    let restored_hash = FastSha256::digest(&archive_data[..payload_len]);
    if restored_hash == info.root_hash {
        Ok(true)
    } else {
        Ok(false)
    }
}

/// Repairs an archive file in-place using streaming verification and Cauchy RS repair.
pub fn repair_archive_file_streaming(file_path: &Path) -> Result<bool, TTZipStatus> {
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(file_path)
        .map_err(|_| TTZipStatus::ErrFileNotFound)?;

    let info = match inspect_recovery_record_reader(&mut file)? {
        Some(info) => info,
        None => return Ok(false),
    };

    let payload_len = info.protected_payload_length;
    let file_len = file
        .metadata()
        .map_err(|_| TTZipStatus::ErrOpenFailed)?
        .len();
    if payload_len > file_len {
        return Ok(false);
    }

    let k = info.data_slices_count;
    let m = info.parity_slices_count;
    let slice_size = info.slice_size;

    // 1. Read Expected Data CRCs table
    let rec_offset = payload_len;
    file.seek(SeekFrom::Start(rec_offset + 54))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut expected_crcs = Vec::with_capacity(k);
    for _ in 0..k {
        let mut buf = [0u8; 4];
        file.read_exact(&mut buf)
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        expected_crcs.push(u32::from_le_bytes(buf));
    }

    // 2. Stream through payload to check SHA-256 and identify corrupted slices
    file.seek(SeekFrom::Start(0))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut hasher = FastSha256::new();
    let mut missing_indices = Vec::new();
    let mut intact_data_indices = Vec::new();
    let mut slice_buf = vec![0u8; slice_size];

    for d in 0..k {
        let start = d as u64 * slice_size as u64;
        let end = std::cmp::min(start + slice_size as u64, payload_len);
        let len = (end - start) as usize;
        file.read_exact(&mut slice_buf[..len])
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        slice_buf[len..slice_size].fill(0);
        hasher.update(&slice_buf[..len]);
        let crc = crc32_fast(0, &slice_buf);
        if crc == expected_crcs[d] {
            intact_data_indices.push(d);
        } else {
            missing_indices.push(d);
        }
    }

    if missing_indices.is_empty() {
        if hasher.finalize() == info.root_hash {
            return Ok(true); // 100% Intact
        }
    }

    if missing_indices.len() > m {
        return Ok(false); // Damage exceeds parity capacity
    }

    // 3. Read and verify Parity Slices
    let parity_start_offset = rec_offset + 54 + (k as u64 * 4);
    file.seek(SeekFrom::Start(parity_start_offset))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;

    let mut intact_parity_shards: Vec<(usize, Vec<u8>)> = Vec::new();
    for p in 0..m {
        let mut p_idx_buf = [0u8; 2];
        let mut p_crc_buf = [0u8; 4];
        let mut p_slice = vec![0u8; slice_size];
        file.read_exact(&mut p_idx_buf)
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        file.read_exact(&mut p_crc_buf)
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        file.read_exact(&mut p_slice)
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;

        let p_expected_crc = u32::from_le_bytes(p_crc_buf);
        let p_actual_crc = crc32_fast(0, &p_slice);
        if p_actual_crc == p_expected_crc {
            intact_parity_shards.push((k + p, p_slice));
        }
    }

    if intact_data_indices.len() + intact_parity_shards.len() < k {
        return Ok(false); // Insufficient shards to reconstruct
    }

    // 4. Gather exactly K shards for reconstruction
    let mut available_indices = Vec::with_capacity(k);
    let mut available_buffers = Vec::with_capacity(k);

    let needed_data_count = k.saturating_sub(intact_parity_shards.len());
    let data_shards_to_use = std::cmp::max(needed_data_count, intact_data_indices.len().min(k));

    for &d in &intact_data_indices[..data_shards_to_use] {
        let start = d as u64 * slice_size as u64;
        let end = std::cmp::min(start + slice_size as u64, payload_len);
        let len = (end - start) as usize;
        file.seek(SeekFrom::Start(start))
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        let mut d_slice = vec![0u8; slice_size];
        file.read_exact(&mut d_slice[..len])
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        available_indices.push(d);
        available_buffers.push(d_slice);
    }

    for (p_idx, p_data) in intact_parity_shards {
        if available_buffers.len() == k {
            break;
        }
        available_indices.push(p_idx);
        available_buffers.push(p_data);
    }

    if available_buffers.len() < k {
        return Ok(false);
    }

    // 5. Decode missing slices
    let rs = ReedSolomonEngine::new(k, m)?;
    let available_refs: Vec<&[u8]> = available_buffers.iter().map(|b| b.as_slice()).collect();
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

    // 6. Write reconstructed slices in-place
    for (m_idx, &missing_col) in missing_indices.iter().enumerate() {
        let start = missing_col as u64 * slice_size as u64;
        let end = std::cmp::min(start + slice_size as u64, payload_len);
        let len = (end - start) as usize;
        file.seek(SeekFrom::Start(start))
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        file.write_all(&reconstructed_buffers[m_idx][..len])
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    }
    file.flush()
        .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    // 7. Verify SHA-256 after in-place repair
    file.seek(SeekFrom::Start(0))
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut verify_hasher = FastSha256::new();
    for d in 0..k {
        let start = d as u64 * slice_size as u64;
        let end = std::cmp::min(start + slice_size as u64, payload_len);
        let len = (end - start) as usize;
        file.read_exact(&mut slice_buf[..len])
            .map_err(|_| TTZipStatus::ErrOpenFailed)?;
        verify_hasher.update(&slice_buf[..len]);
    }

    let restored_hash = verify_hasher.finalize();
    if restored_hash == info.root_hash {
        Ok(true)
    } else {
        Ok(false)
    }
}

/// In-place repair wrapper.
pub fn repair_archive_file(file_path: &Path) -> Result<bool, TTZipStatus> {
    repair_archive_file_streaming(file_path)
}
