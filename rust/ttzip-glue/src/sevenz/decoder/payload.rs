// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Full solid payload decoding with hardware AES decryption.

use crate::codecs::deflate::deflate_decompress;
use crate::codecs::lzma2::fl2_decompress;
use crate::crypto::aes256::aes256_cbc_decrypt;
use crate::crypto::sha256::sha256_7z_kdf;
use crate::sevenz::format::*;
use crate::sevenz::header::SevenZHeaderInfo;
use crate::types::TTZipStatus;

/// Decompresses and decrypts the entire 7z solid payload block.
pub fn decode_7z_solid_payload(
    mapped: &[u8],
    info: &SevenZHeaderInfo,
    password: Option<&str>,
    threads: u32,
) -> Result<Vec<u8>, TTZipStatus> {
    if info.payload_len == 0 {
        return Ok(Vec::new());
    }

    let payload_end = info.payload_offset + info.payload_len;
    if payload_end > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let mut raw_payload = &mapped[info.payload_offset..payload_end];
    let mut decrypted_storage = Vec::new();

    // 1. Hardware AES-256-CBC decryption via ARM64 NEON if encrypted
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

    // 2. Compute total expected uncompressed size
    let expected_unpack_size: u64 = if !info.stream_sizes.is_empty() {
        info.stream_sizes.iter().sum()
    } else if !info.folders.is_empty() {
        info.folders.iter().map(|f| f.unpack_sizes.iter().sum::<u64>()).sum()
    } else {
        raw_payload.len() as u64
    };

    let mut unpack_buf = vec![0u8; expected_unpack_size as usize];

    // 3. Decompress via selected coder
    match info.primary_method_id {
        METHOD_COPY => {
            let u_len = unpack_buf.len();
            let copy_len = raw_payload.len().min(u_len);
            unpack_buf[..copy_len].copy_from_slice(&raw_payload[..copy_len]);
        }
        METHOD_DEFLATE => {
            if let Ok(decomp_len) = deflate_decompress(raw_payload, &mut unpack_buf) {
                unpack_buf.truncate(decomp_len);
            }
        }
        METHOD_LZMA | METHOD_LZMA2 => {
            if let Ok(decomp_len) = fl2_decompress(raw_payload, &mut unpack_buf, threads) {
                unpack_buf.truncate(decomp_len);
            }
        }
        _ => {
            if let Ok(decomp_len) = fl2_decompress(raw_payload, &mut unpack_buf, threads) {
                unpack_buf.truncate(decomp_len);
            }
        }
    }

    Ok(unpack_buf)
}
