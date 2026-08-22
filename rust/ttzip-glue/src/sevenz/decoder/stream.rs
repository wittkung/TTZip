// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Solid Stream selective entry decoding with Early Termination.

use super::payload::decode_7z_solid_payload;

use crate::crypto::aes256::aes256_cbc_decrypt;
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha256::sha256_7z_kdf;
use crate::sevenz::format::*;
use crate::sevenz::header::{SevenZHeaderInfo, SevenZSeekIndex};
use crate::types::TTZipStatus;

/// Decompresses and extracts a single entry from 7z solid stream with Early Termination.
pub fn extract_entry_bytes_stream(
    mapped: &[u8],
    info: &SevenZHeaderInfo,
    seek_index: &SevenZSeekIndex,
    entry_idx: usize,
    password: Option<&str>,
) -> Result<Vec<u8>, TTZipStatus> {
    let loc = seek_index
        .get_by_index(entry_idx)
        .ok_or(TTZipStatus::ErrInvalidOffset)?;

    if loc.is_directory || loc.is_empty_stream || loc.uncompressed_size == 0 {
        return Ok(Vec::new());
    }

    if info.payload_len == 0 {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let payload_end = info.payload_offset + info.payload_len;
    if payload_end > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let mut raw_payload = &mapped[info.payload_offset..payload_end];
    let mut decrypted_storage = Vec::new();

    // Decrypt if archive payload is AES encrypted
    if info.is_encrypted {
        let pass = password.ok_or(TTZipStatus::ErrInvalidPassword)?;
        if pass.is_empty() {
            return Err(TTZipStatus::ErrInvalidPassword);
        }

        let key = sha256_7z_kdf(pass, &info.aes_salt[..info.aes_salt_len], info.aes_num_cycles_power);
        if !raw_payload.len().is_multiple_of(16) {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        decrypted_storage.resize(raw_payload.len(), 0);
        aes256_cbc_decrypt(&key, &info.aes_iv, raw_payload, &mut decrypted_storage)
            .map_err(|_| TTZipStatus::ErrInvalidPassword)?;

        raw_payload = &decrypted_storage;
    }

    let target_end = (loc.offset_in_folder + loc.uncompressed_size) as usize;
    let offset = loc.offset_in_folder as usize;

    let result_vec = match info.primary_method_id {
        METHOD_COPY => {
            let clamped_end = target_end.min(raw_payload.len());
            let clamped_offset = offset.min(clamped_end);
            raw_payload[clamped_offset..clamped_end].to_vec()
        }
        _ => {
            let solid_buf = decode_7z_solid_payload(mapped, info, password, 1)?;
            let clamped_end = target_end.min(solid_buf.len());
            let clamped_offset = offset.min(clamped_end);
            solid_buf[clamped_offset..clamped_end].to_vec()
        }
    };

    // Verify CRC32
    if let Some(expected_crc) = loc.crc {
        if expected_crc != 0 && !result_vec.is_empty() {
            let computed = crc32_fast(0, &result_vec);
            if computed != expected_crc && info.is_encrypted {
                return Err(TTZipStatus::ErrInvalidPassword);
            }
        }
    }

    Ok(result_vec)
}
