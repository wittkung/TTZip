// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP Archive Parallel Compression and Writing Engine.
//!
//! Supports Store, Deflate (Levels 1..12 via `libdeflate`), WinZip AES-256 hardware encryption,
//! and automatic Zip64 extension promotion for large files (>4GB) and large catalogs (>65535 files).

use crate::codecs::deflate::{deflate_compress, deflate_compress_bound};
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha1::winzip_aes256_encrypt_and_tag;
use crate::types::{TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod, TTZipStatus};
use crate::zip::extra::ZipExtraFields;
use crate::zip::parser::{
    MAGIC_CDFH, MAGIC_EOCD, MAGIC_LFH, MAGIC_ZIP64_EOCD, MAGIC_ZIP64_LOCATOR,
};
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::thread;

/// Input item descriptor for ZIP compression.
#[derive(Debug, Clone)]
pub struct ZipInputItem {
    pub rel_path: String,
    pub data: Vec<u8>,
    pub mtime_epoch_secs: u32,
    pub mode: u32,
    pub is_directory: bool,
}

/// Compressed item result ready for binary layout.
#[derive(Debug, Clone)]
pub struct ZipCompressedItem {
    pub rel_path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub compression_method: u16,
    pub actual_method: u16,
    pub aes_strength: u8,
    pub payload: Vec<u8>,
    pub mtime_epoch_secs: u32,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
}

/// Detailed report from an archive creation operation.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ZipCreateReport {
    pub total_entries: usize,
    pub total_uncompressed_bytes: u64,
    pub total_compressed_bytes: u64,
    pub duration_ms: u64,
}

/// Converts Unix epoch seconds to DOS time (time: u16, date: u16).
pub fn unix_to_dos_time(epoch_secs: u32) -> (u16, u16) {
    // Simple DOS timestamp conversion
    let days_since_1970 = (epoch_secs / 86400) as i64;
    let secs_of_day = epoch_secs % 86400;

    let hour = (secs_of_day / 3600) as u16;
    let min = ((secs_of_day % 3600) / 60) as u16;
    let sec = ((secs_of_day % 60) / 2) as u16;
    let dos_time = (hour << 11) | (min << 5) | sec;

    // Approximate year/month/day
    let mut year = 1970;
    let mut days_left = days_since_1970;
    loop {
        let leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        let days_in_year = if leap { 366 } else { 365 };
        if days_left < days_in_year {
            break;
        }
        days_left -= days_in_year;
        year += 1;
    }

    let month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    let mut month = 1u16;
    for &d in &month_days {
        let dim = if month == 2 && leap { d + 1 } else { d };
        if days_left < dim as i64 {
            break;
        }
        days_left -= dim as i64;
        month += 1;
    }
    let day = (days_left + 1) as u16;
    let dos_year = (year.max(1980) - 1980).clamp(0, 127) as u16;
    let dos_date = (dos_year << 9) | (month << 5) | day;

    (dos_time, dos_date)
}

/// Recursively collects files and directories into `ZipInputItem` list.
pub fn collect_zip_input_items(
    base_src: &Path,
    rel_prefix: &str,
    out_items: &mut Vec<ZipInputItem>,
) -> Result<(), TTZipStatus> {
    let metadata = fs::symlink_metadata(base_src).map_err(|_| TTZipStatus::ErrFileNotFound)?;

    let is_dir = metadata.is_dir();
    let mtime_secs = metadata
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as u32)
        .unwrap_or(0);

    #[cfg(unix)]
    let mode = {
        use std::os::unix::fs::MetadataExt;
        metadata.mode()
    };
    #[cfg(not(unix))]
    let mode = if is_dir { 0o755 } else { 0o644 };

    let mut item_rel = rel_prefix.to_string();
    if is_dir && !item_rel.is_empty() && !item_rel.ends_with('/') {
        item_rel.push('/');
    }

    if !item_rel.is_empty() {
        if is_dir {
            out_items.push(ZipInputItem {
                rel_path: item_rel.clone(),
                data: Vec::new(),
                mtime_epoch_secs: mtime_secs,
                mode,
                is_directory: true,
            });
        } else {
            let data = fs::read(base_src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
            out_items.push(ZipInputItem {
                rel_path: item_rel,
                data,
                mtime_epoch_secs: mtime_secs,
                mode,
                is_directory: false,
            });
        }
    }

    if is_dir {
        let entries = fs::read_dir(base_src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        for entry in entries.flatten() {
            let path = entry.path();
            let file_name = path.file_name().unwrap_or_default().to_string_lossy();
            let child_rel = if rel_prefix.is_empty() {
                file_name.to_string()
            } else {
                format!("{}/{}", rel_prefix.trim_end_matches('/'), file_name)
            };
            collect_zip_input_items(&path, &child_rel, out_items)?;
        }
    }

    Ok(())
}

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
    let chunk_size = (items.len() + thread_count - 1) / thread_count;
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

/// Assembles compressed items into final ZIP archive binary bytes.
pub fn assemble_zip_archive(items: &[ZipCompressedItem]) -> Result<Vec<u8>, TTZipStatus> {
    let mut out = Vec::new();
    let mut lfh_offsets = Vec::with_capacity(items.len());

    // 1. Write Local File Headers + Payloads
    for item in items {
        let lfh_offset = out.len() as u64;
        lfh_offsets.push(lfh_offset);

        let (dos_time, dos_date) = unix_to_dos_time(item.mtime_epoch_secs);
        let name_bytes = item.rel_path.as_bytes();

        let use_zip64 = item.uncompressed_size >= 0xFFFFFFFF
            || item.compressed_size >= 0xFFFFFFFF
            || lfh_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            let z64 = ZipExtraFields::build_zip64_extra(
                Some(item.uncompressed_size),
                Some(item.compressed_size),
                None,
            );
            extra_bytes.extend_from_slice(&z64);
        }
        if item.is_encrypted && item.compression_method == 99 {
            let aes_extra = ZipExtraFields::build_winzip_aes_extra(item.actual_method);
            extra_bytes.extend_from_slice(&aes_extra);
        }
        let ts_extra = ZipExtraFields::build_extended_timestamp(item.mtime_epoch_secs);
        extra_bytes.extend_from_slice(&ts_extra);

        let version_needed = if use_zip64 {
            45u16
        } else if item.is_encrypted {
            51u16
        } else if item.compression_method == 8 {
            20u16
        } else {
            10u16
        };

        let flag = if item.is_encrypted {
            0x0801u16 // bit 0 = encrypted, bit 11 = UTF-8
        } else {
            0x0800u16 // bit 11 = UTF-8
        };

        let uncomp_size_field = if item.uncompressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.uncompressed_size as u32
        };
        let comp_size_field = if item.compressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.compressed_size as u32
        };

        // LFH Record
        out.extend_from_slice(&MAGIC_LFH.to_le_bytes());
        out.extend_from_slice(&version_needed.to_le_bytes());
        out.extend_from_slice(&flag.to_le_bytes());
        out.extend_from_slice(&item.compression_method.to_le_bytes());
        out.extend_from_slice(&dos_time.to_le_bytes());
        out.extend_from_slice(&dos_date.to_le_bytes());
        out.extend_from_slice(&item.crc32.to_le_bytes());
        out.extend_from_slice(&comp_size_field.to_le_bytes());
        out.extend_from_slice(&uncomp_size_field.to_le_bytes());
        out.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(name_bytes);
        out.extend_from_slice(&extra_bytes);

        // Payload
        out.extend_from_slice(&item.payload);
    }

    // 2. Write Central Directory
    let cd_offset = out.len() as u64;

    for (i, item) in items.iter().enumerate() {
        let lfh_offset = lfh_offsets[i];
        let (dos_time, dos_date) = unix_to_dos_time(item.mtime_epoch_secs);
        let name_bytes = item.rel_path.as_bytes();

        let use_zip64 = item.uncompressed_size >= 0xFFFFFFFF
            || item.compressed_size >= 0xFFFFFFFF
            || lfh_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            let u_sz = if item.uncompressed_size >= 0xFFFFFFFF {
                Some(item.uncompressed_size)
            } else {
                None
            };
            let c_sz = if item.compressed_size >= 0xFFFFFFFF {
                Some(item.compressed_size)
            } else {
                None
            };
            let off = if lfh_offset >= 0xFFFFFFFF {
                Some(lfh_offset)
            } else {
                None
            };
            let z64 = ZipExtraFields::build_zip64_extra(u_sz, c_sz, off);
            extra_bytes.extend_from_slice(&z64);
        }
        if item.is_encrypted && item.compression_method == 99 {
            let aes_extra = ZipExtraFields::build_winzip_aes_extra(item.actual_method);
            extra_bytes.extend_from_slice(&aes_extra);
        }
        let ts_extra = ZipExtraFields::build_extended_timestamp(item.mtime_epoch_secs);
        extra_bytes.extend_from_slice(&ts_extra);

        let version_made_by = 0x031Eu16; // Unix / macOS
        let version_needed = if use_zip64 {
            45u16
        } else if item.is_encrypted {
            51u16
        } else if item.compression_method == 8 {
            20u16
        } else {
            10u16
        };

        let flag = if item.is_encrypted {
            0x0801u16
        } else {
            0x0800u16
        };

        let uncomp_size_field = if item.uncompressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.uncompressed_size as u32
        };
        let comp_size_field = if item.compressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.compressed_size as u32
        };
        let lfh_offset_field = if lfh_offset >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            lfh_offset as u32
        };

        let ext_attr = (item.mode << 16) | if item.is_directory { 0x10 } else { 0 };

        // CDFH Record
        out.extend_from_slice(&MAGIC_CDFH.to_le_bytes());
        out.extend_from_slice(&version_made_by.to_le_bytes());
        out.extend_from_slice(&version_needed.to_le_bytes());
        out.extend_from_slice(&flag.to_le_bytes());
        out.extend_from_slice(&item.compression_method.to_le_bytes());
        out.extend_from_slice(&dos_time.to_le_bytes());
        out.extend_from_slice(&dos_date.to_le_bytes());
        out.extend_from_slice(&item.crc32.to_le_bytes());
        out.extend_from_slice(&comp_size_field.to_le_bytes());
        out.extend_from_slice(&uncomp_size_field.to_le_bytes());
        out.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // comment length = 0
        out.extend_from_slice(&0u16.to_le_bytes()); // disk number = 0
        out.extend_from_slice(&0u16.to_le_bytes()); // internal attr = 0
        out.extend_from_slice(&ext_attr.to_le_bytes());
        out.extend_from_slice(&lfh_offset_field.to_le_bytes());
        out.extend_from_slice(name_bytes);
        out.extend_from_slice(&extra_bytes);
    }

    let cd_size = (out.len() as u64) - cd_offset;
    let num_entries = items.len() as u64;

    let is_zip64_required = num_entries >= 0xFFFF
        || cd_size >= 0xFFFFFFFF
        || cd_offset >= 0xFFFFFFFF;

    if is_zip64_required {
        // Zip64 EOCD Record
        let z64_eocd_pos = out.len() as u64;
        let z64_record_size = 44u64; // Size after this field

        out.extend_from_slice(&MAGIC_ZIP64_EOCD.to_le_bytes());
        out.extend_from_slice(&z64_record_size.to_le_bytes());
        out.extend_from_slice(&45u16.to_le_bytes()); // version made by
        out.extend_from_slice(&45u16.to_le_bytes()); // version needed
        out.extend_from_slice(&0u32.to_le_bytes()); // disk number
        out.extend_from_slice(&0u32.to_le_bytes()); // disk with CD
        out.extend_from_slice(&num_entries.to_le_bytes()); // total entries on disk
        out.extend_from_slice(&num_entries.to_le_bytes()); // total entries in CD
        out.extend_from_slice(&cd_size.to_le_bytes());
        out.extend_from_slice(&cd_offset.to_le_bytes());

        // Zip64 EOCD Locator
        out.extend_from_slice(&MAGIC_ZIP64_LOCATOR.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes()); // disk with zip64 EOCD
        out.extend_from_slice(&z64_eocd_pos.to_le_bytes()); // offset of zip64 EOCD
        out.extend_from_slice(&1u32.to_le_bytes()); // total disks
    }

    // Standard EOCD Record
    let entries_field = if num_entries >= 0xFFFF {
        0xFFFFu16
    } else {
        num_entries as u16
    };
    let cd_size_field = if cd_size >= 0xFFFFFFFF {
        0xFFFFFFFFu32
    } else {
        cd_size as u32
    };
    let cd_offset_field = if cd_offset >= 0xFFFFFFFF {
        0xFFFFFFFFu32
    } else {
        cd_offset as u32
    };

    out.extend_from_slice(&MAGIC_EOCD.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // disk number
    out.extend_from_slice(&0u16.to_le_bytes()); // disk with CD
    out.extend_from_slice(&entries_field.to_le_bytes()); // entries on this disk
    out.extend_from_slice(&entries_field.to_le_bytes()); // total entries in CD
    out.extend_from_slice(&cd_size_field.to_le_bytes());
    out.extend_from_slice(&cd_offset_field.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // comment length = 0

    Ok(out)
}

/// Creates a ZIP archive file directly from input source paths.
pub fn create_zip_archive(
    dest_path: &Path,
    source_paths: &[PathBuf],
    options: &TTZipCreateOptions,
) -> Result<ZipCreateReport, TTZipStatus> {
    let start_time = std::time::Instant::now();

    let mut input_items = Vec::new();
    for src in source_paths {
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        let file_name = src.file_name().unwrap_or_default().to_string_lossy();
        collect_zip_input_items(src, &file_name, &mut input_items)?;
    }

    let level_int = match options.level {
        TTZipCompressionLevel::Store => 0,
        TTZipCompressionLevel::Fastest => 1,
        TTZipCompressionLevel::Fast => 3,
        TTZipCompressionLevel::Normal => 6,
        TTZipCompressionLevel::Maximum => 9,
        TTZipCompressionLevel::Ultra => 12,
    };

    let password_str = if !options.password.is_null() {
        unsafe { std::ffi::CStr::from_ptr(options.password) }
            .to_str()
            .ok()
    } else {
        None
    };

    let compressed_items = compress_items_parallel(
        input_items,
        level_int,
        options.encryption,
        password_str,
        options.thread_budget,
    )?;

    let mut total_uncomp_bytes = 0u64;
    let mut total_comp_bytes = 0u64;
    for item in &compressed_items {
        total_uncomp_bytes += item.uncompressed_size;
        total_comp_bytes += item.compressed_size;
    }

    let binary_bytes = assemble_zip_archive(&compressed_items)?;

    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    }

    let mut file = File::create(dest_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    file.write_all(&binary_bytes).map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    Ok(ZipCreateReport {
        total_entries: compressed_items.len(),
        total_uncompressed_bytes: total_uncomp_bytes,
        total_compressed_bytes: total_comp_bytes,
        duration_ms: start_time.elapsed().as_millis() as u64,
    })
}
