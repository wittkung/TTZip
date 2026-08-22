// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multithreaded parallel compression engine for ZIP archives.

use super::types::{ZipCompressedItem, ZipInputItem};
use crate::codecs::deflate::{deflate_compress, deflate_compress_bound};
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha1::winzip_aes256_encrypt_and_tag;
use crate::types::{TTZipEncryptionMethod, TTZipStatus};
use std::thread;

/// Compresses a batch of `ZipInputItem`s in parallel across threads.
pub fn compress_items_parallel(
    items: Vec<ZipInputItem>,
    level: i32,
    encryption: TTZipEncryptionMethod,
    password: Option<&str>,
    thread_budget: u32,
) -> Result<Vec<ZipCompressedItem>, TTZipStatus> {
    if items.is_empty() {
        return Ok(Vec::new());
    }

    let thread_count = (thread_budget as usize).clamp(1, 64).min(items.len().max(1));
    let chunk_size = items.len().div_ceil(thread_count);
    let pwd_owned = password.map(|s| s.to_string());

    let mut handles = Vec::new();

    for chunk in items.chunks(chunk_size) {
        let chunk_items = chunk.to_vec();
        let pwd_cloned = pwd_owned.clone();

        let handle = thread::spawn(move || -> Result<Vec<ZipCompressedItem>, TTZipStatus> {
            let mut results = Vec::with_capacity(chunk_items.len());

            for item in chunk_items {
                if item.is_directory || item.data.is_empty() {
                    results.push(ZipCompressedItem {
                        rel_path: item.rel_path,
                        uncompressed_size: 0,
                        compressed_size: 0,
                        crc32: 0,
                        compression_method: 0,
                        actual_method: 0,
                        aes_strength: 0,
                        payload: Vec::new(),
                        mtime_epoch_secs: item.mtime_epoch_secs,
                        mode: item.mode,
                        is_directory: item.is_directory,
                        is_encrypted: false,
                    });
                    continue;
                }

                let uncompressed_size = item.data.len() as u64;
                let crc32 = crc32_fast(0, &item.data);

                let (actual_method, raw_payload) = if level == 0 {
                    (0u16, item.data)
                } else {
                    let mut comp_buf = vec![0u8; deflate_compress_bound(item.data.len(), level)];
                    let comp_len = deflate_compress(&item.data, &mut comp_buf, level)?;
                    comp_buf.truncate(comp_len);
                    (8u16, comp_buf)
                };

                let (compression_method, aes_strength, is_encrypted, final_payload) =
                    if encryption == TTZipEncryptionMethod::Aes256 {
                        let pass = pwd_cloned.as_deref().ok_or(TTZipStatus::ErrInvalidPassword)?;
                        let salt = [0x5au8; 16]; // Deterministic fixed or pseudo-random salt
                        let mut enc_payload = Vec::new();
                        winzip_aes256_encrypt_and_tag(pass, &salt, &raw_payload, &mut enc_payload)?;
                        (99u16, 3u8, true, enc_payload)
                    } else if encryption == TTZipEncryptionMethod::ZipCrypto {
                        let pass = pwd_cloned.as_deref().ok_or(TTZipStatus::ErrInvalidPassword)?;
                        let mut enc_payload = Vec::with_capacity(12 + raw_payload.len());
                        let mut header = [0x42u8; 12];
                        header[11] = (crc32 >> 24) as u8;
                        let mut keys = crate::crypto::zipcrypto::ZipCryptoKeys::from_password(pass.as_bytes());
                        keys.encrypt_slice(&mut header);
                        enc_payload.extend_from_slice(&header);
                        let mut body = raw_payload.clone();
                        keys.encrypt_slice(&mut body);
                        enc_payload.extend_from_slice(&body);
                        (actual_method, 0u8, true, enc_payload)
                    } else {
                        (actual_method, 0u8, false, raw_payload)
                    };

                let compressed_size = final_payload.len() as u64;

                results.push(ZipCompressedItem {
                    rel_path: item.rel_path,
                    uncompressed_size,
                    compressed_size,
                    crc32,
                    compression_method,
                    actual_method,
                    aes_strength,
                    payload: final_payload,
                    mtime_epoch_secs: item.mtime_epoch_secs,
                    mode: item.mode,
                    is_directory: false,
                    is_encrypted,
                });
            }

            Ok(results)
        });

        handles.push(handle);
    }

    let mut all_compressed = Vec::with_capacity(items.len());
    for handle in handles {
        match handle.join() {
            Ok(res) => all_compressed.extend(res?),
            Err(_) => return Err(TTZipStatus::ErrPanicCaught),
        }
    }

    Ok(all_compressed)
}
