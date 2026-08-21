// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware NEON-accelerated ZIP/TAR damaged stream TOC reconstruction and corrupt archive self-healing engine.

use crate::types::TTZipStatus;
use crate::zip::writer::{assemble_zip_archive, ZipCompressedItem};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;

/// Finds next ZIP Local File Header signature (`PK\x03\x04`).
pub fn find_next_pk_signature(data: &[u8], start: usize) -> Option<usize> {
    #[cfg(target_arch = "aarch64")]
    unsafe {
        find_next_pk_neon(data, start)
    }
    #[cfg(not(target_arch = "aarch64"))]
    {
        find_next_pk_scalar(data, start)
    }
}

#[cfg(target_arch = "aarch64")]
unsafe fn find_next_pk_neon(data: &[u8], start: usize) -> Option<usize> {
    use core::arch::aarch64::*;
    let target = vdupq_n_u8(b'P');
    let mut i = start;
    let len = data.len();

    while i + 16 <= len {
        let chunk = vld1q_u8(data.as_ptr().add(i));
        let cmp = vceqq_u8(chunk, target);
        let max_val = vmaxvq_u8(cmp);
        if max_val != 0 {
            for j in 0..16 {
                let idx = i + j;
                if idx + 4 <= len
                    && data[idx] == b'P'
                    && data[idx + 1] == b'K'
                    && data[idx + 2] == 0x03
                    && data[idx + 3] == 0x04
                {
                    return Some(idx);
                }
            }
        }
        i += 16;
    }

    find_next_pk_scalar(data, i)
}

#[inline]
fn find_next_pk_scalar(data: &[u8], mut i: usize) -> Option<usize> {
    let len = data.len();
    while i + 4 <= len {
        if data[i] == b'P' && data[i + 1] == b'K' && data[i + 2] == 0x03 && data[i + 3] == 0x04 {
            return Some(i);
        }
        i += 1;
    }
    None
}

/// Scans damaged ZIP stream and reconstructs a healthy ZIP archive at `repaired_path`.
pub fn repair_damaged_zip(damaged_path: &Path, repaired_path: &Path) -> Result<usize, TTZipStatus> {
    let file_data = fs::read(damaged_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let total_len = file_data.len();
    let mut offset = 0;
    let mut salvaged_items = Vec::new();

    while let Some(pk_pos) = find_next_pk_signature(&file_data, offset) {
        if pk_pos + 30 > total_len {
            break;
        }

        let method = u16::from_le_bytes([file_data[pk_pos + 8], file_data[pk_pos + 9]]);
        let _mtime_dos = u16::from_le_bytes([file_data[pk_pos + 10], file_data[pk_pos + 11]]);
        let mdate_dos = u16::from_le_bytes([file_data[pk_pos + 12], file_data[pk_pos + 13]]);
        let crc32 = u32::from_le_bytes([
            file_data[pk_pos + 14],
            file_data[pk_pos + 15],
            file_data[pk_pos + 16],
            file_data[pk_pos + 17],
        ]);
        let comp_size = u32::from_le_bytes([
            file_data[pk_pos + 18],
            file_data[pk_pos + 19],
            file_data[pk_pos + 20],
            file_data[pk_pos + 21],
        ]) as usize;
        let uncomp_size = u32::from_le_bytes([
            file_data[pk_pos + 22],
            file_data[pk_pos + 23],
            file_data[pk_pos + 24],
            file_data[pk_pos + 25],
        ]) as u64;
        let fn_len = u16::from_le_bytes([file_data[pk_pos + 26], file_data[pk_pos + 27]]) as usize;
        let extra_len = u16::from_le_bytes([file_data[pk_pos + 28], file_data[pk_pos + 29]]) as usize;

        let header_len = 30 + fn_len + extra_len;
        if fn_len > 0 && pk_pos + header_len <= total_len {
            let fn_bytes = &file_data[pk_pos + 30..pk_pos + 30 + fn_len];
            let name_str = String::from_utf8_lossy(fn_bytes).to_string();
            let clean_name = name_str.trim_matches('\0').to_string();

            if !clean_name.is_empty() {
                let payload_start = pk_pos + header_len;
                let max_payload_len = total_len.saturating_sub(payload_start);
                let actual_comp_len = comp_size.min(max_payload_len);
                let payload = file_data[payload_start..payload_start + actual_comp_len].to_vec();

                let is_dir = clean_name.ends_with('/');
                let mut epoch_secs = 1700000000u32;
                let yr = ((mdate_dos >> 9) & 0x7F) as u32 + 1980;
                let mo = ((mdate_dos >> 5) & 0x0F) as u32;
                let dy = (mdate_dos & 0x1F) as u32;
                if yr >= 1980 && mo >= 1 && mo <= 12 && dy >= 1 && dy <= 31 {
                    epoch_secs = (yr - 1970) * 31536000 + mo * 2592000 + dy * 86400;
                }

                salvaged_items.push(ZipCompressedItem {
                    rel_path: clean_name,
                    uncompressed_size: if uncomp_size > 0 { uncomp_size } else { payload.len() as u64 },
                    compressed_size: payload.len() as u64,
                    crc32,
                    compression_method: method,
                    actual_method: method,
                    aes_strength: 0,
                    payload,
                    mtime_epoch_secs: epoch_secs,
                    mode: if is_dir { 0o755 } else { 0o644 },
                    is_directory: is_dir,
                    is_encrypted: false,
                });
            }
        }

        let jump = 30 + fn_len + extra_len + comp_size;
        offset = pk_pos + jump.max(4);
    }

    if salvaged_items.is_empty() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let count = salvaged_items.len();
    let rebuilt_bytes = assemble_zip_archive(&salvaged_items)?;
    fs::write(repaired_path, &rebuilt_bytes).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    Ok(count)
}

/// Scans damaged TAR stream and reconstructs a healthy TAR archive at `repaired_path`.
pub fn repair_damaged_tar(damaged_path: &Path, repaired_path: &Path) -> Result<usize, TTZipStatus> {
    let mut file = File::open(damaged_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let mut buffer = Vec::new();
    file.read_to_end(&mut buffer).map_err(|_| TTZipStatus::ErrOpenFailed)?;

    let mut out_file = File::create(repaired_path).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    let mut offset = 0;
    let total_len = buffer.len();
    let mut salvaged_count = 0;

    while offset + 512 <= total_len {
        let block = &buffer[offset..offset + 512];
        if block.iter().all(|&b| b == 0) {
            offset += 512;
            continue;
        }

        // Verify TAR checksum (offset 148..156)
        let chk_bytes = &block[148..156];
        let chk_str = std::str::from_utf8(chk_bytes).unwrap_or("").trim_matches(&['\0', ' '][..]);
        let expected_chk = u32::from_str_radix(chk_str, 8).unwrap_or(0);

        let mut calc_chk = 0u32;
        for (i, &b) in block.iter().enumerate() {
            if (148..156).contains(&i) {
                calc_chk += b' ' as u32;
            } else {
                calc_chk += b as u32;
            }
        }

        if expected_chk != 0 && (expected_chk == calc_chk || expected_chk == calc_chk.wrapping_sub(0x100)) {
            // Valid header block found
            let size_bytes = &block[124..136];
            let size_str = std::str::from_utf8(size_bytes).unwrap_or("").trim_matches(&['\0', ' '][..]);
            let file_size = usize::from_str_radix(size_str, 8).unwrap_or(0);

            let payload_blocks = (file_size + 511) / 512;
            let available_payload = total_len.saturating_sub(offset + 512);
            let write_payload_len = file_size.min(available_payload);

            out_file.write_all(block).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            if write_payload_len > 0 {
                let payload = &buffer[offset + 512..offset + 512 + write_payload_len];
                out_file.write_all(payload).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                let pad = (512 - (write_payload_len % 512)) % 512;
                if pad > 0 {
                    out_file.write_all(&vec![0u8; pad]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                }
            }

            salvaged_count += 1;
            offset += 512 + (payload_blocks * 512);
        } else {
            offset += 512;
        }
    }

    // Write double-512-byte zero End-of-Archive trailer
    out_file.write_all(&[0u8; 1024]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    out_file.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    if salvaged_count == 0 {
        Err(TTZipStatus::ErrCorruptHeader)
    } else {
        Ok(salvaged_count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_repair_damaged_zip_corrupt_tail() {
        let temp_dir = std::env::temp_dir().join("ttzip_test_repair_zip");
        let _ = fs::create_dir_all(&temp_dir);

        let good_item = ZipCompressedItem {
            rel_path: "document.txt".to_string(),
            uncompressed_size: 13,
            compressed_size: 13,
            crc32: 0x12345678,
            compression_method: 0,
            actual_method: 0,
            aes_strength: 0,
            payload: b"Hello World!!".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
            is_encrypted: false,
        };

        let zip_bytes = assemble_zip_archive(&[good_item]).expect("assemble");
        // Truncate archive right after the payload to destroy the Central Directory & EOCD
        let truncated = zip_bytes[..30 + 12 + 13].to_vec();

        let damaged_file = temp_dir.join("damaged.zip");
        let repaired_file = temp_dir.join("repaired.zip");
        fs::write(&damaged_file, &truncated).expect("write damaged");

        let count = repair_damaged_zip(&damaged_file, &repaired_file).expect("repair");
        assert_eq!(count, 1);
        assert!(repaired_file.exists());

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
