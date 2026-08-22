// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Lock-free Store-mode multi-core parallel ZIP stream writer.
//!
//! Uses physical APFS disk extent preallocation and multi-threaded `pwrite`
//! for zero-contention parallel packaging directly to disk.

use super::types::{unix_to_dos_time, ZipCreateReport};
use crate::crypto::crc32::crc32_fast;
use crate::fs::apfs::apfs_preallocate;
use crate::types::{TTZipCreateOptions, TTZipStatus};
use crate::zip::extra::ZipExtraFields;
use crate::zip::parser::{
    MAGIC_CDFH, MAGIC_EOCD, MAGIC_LFH, MAGIC_ZIP64_EOCD, MAGIC_ZIP64_LOCATOR,
};
use rayon::prelude::*;
use std::fs::{self, OpenOptions};
use std::os::unix::fs::MetadataExt;
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};

/// Item planned for parallel store writing.
#[derive(Debug, Clone)]
struct StorePlanItem {
    src_path: Option<PathBuf>,
    rel_path: String,
    size: u64,
    mtime_secs: u32,
    mode: u32,
    is_directory: bool,
    lfh_offset: u64,
    lfh_header_size: usize,
    total_lfh_size: u64,
}

/// Recursively scans file tree and prepares store plan items.
fn collect_store_plan_items(
    base_src: &Path,
    rel_prefix: &str,
    out: &mut Vec<StorePlanItem>,
) -> Result<(), TTZipStatus> {
    let meta = fs::symlink_metadata(base_src).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let is_dir = meta.is_dir();
    let size = if is_dir { 0 } else { meta.len() };
    let mtime_secs = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as u32)
        .unwrap_or(0);
    let mode = meta.mode();

    let mut rel = rel_prefix.to_string();
    if is_dir && !rel.is_empty() && !rel.ends_with('/') {
        rel.push('/');
    }

    if !rel.is_empty() {
        out.push(StorePlanItem {
            src_path: if is_dir { None } else { Some(base_src.to_path_buf()) },
            rel_path: rel.clone(),
            size,
            mtime_secs,
            mode,
            is_directory: is_dir,
            lfh_offset: 0,
            lfh_header_size: 0,
            total_lfh_size: 0,
        });
    }

    if is_dir {
        let entries = fs::read_dir(base_src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        for entry in entries.flatten() {
            let path = entry.path();
            let name = path.file_name().unwrap_or_default().to_string_lossy();
            let child_rel = if rel_prefix.is_empty() {
                name.to_string()
            } else {
                format!("{}/{}", rel_prefix.trim_end_matches('/'), name)
            };
            collect_store_plan_items(&path, &child_rel, out)?;
        }
    }
    Ok(())
}

/// Creates a ZIP archive using multi-threaded lock-free Store mode.
pub fn create_zip_store_parallel(
    dest_path: &Path,
    source_paths: &[PathBuf],
    options: &TTZipCreateOptions,
) -> Result<ZipCreateReport, TTZipStatus> {
    let start_time = std::time::Instant::now();

    let mut plan_items = Vec::new();
    for src in source_paths {
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        let fname = src.file_name().unwrap_or_default().to_string_lossy();
        collect_store_plan_items(src, &fname, &mut plan_items)?;
    }

    // 1. Calculate pre-allocated offsets and sizes for each entry
    let mut current_offset: u64 = 0;
    for item in &mut plan_items {
        item.lfh_offset = current_offset;
        let name_bytes = item.rel_path.as_bytes();
        let use_zip64 = item.size >= 0xFFFFFFFF || current_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            extra_bytes.extend_from_slice(&ZipExtraFields::build_zip64_extra(
                Some(item.size),
                Some(item.size),
                None,
            ));
        }
        extra_bytes.extend_from_slice(&ZipExtraFields::build_extended_timestamp(item.mtime_secs));

        item.lfh_header_size = 30 + name_bytes.len() + extra_bytes.len();
        item.total_lfh_size = (item.lfh_header_size as u64) + item.size;
        current_offset += item.total_lfh_size;
    }

    let cd_offset = current_offset;

    // Calculate Central Directory Size
    let mut cd_size: u64 = 0;
    for item in &plan_items {
        let name_len = item.rel_path.len();
        let use_zip64 = item.size >= 0xFFFFFFFF || item.lfh_offset >= 0xFFFFFFFF;
        let mut extra_len = 9; // timestamp
        if use_zip64 {
            extra_len += 28; // Zip64
        }
        cd_size += (46 + name_len + extra_len) as u64;
    }

    let is_zip64_required = plan_items.len() >= 0xFFFF
        || cd_size >= 0xFFFFFFFF
        || cd_offset >= 0xFFFFFFFF;

    let total_file_size = cd_offset + cd_size + if is_zip64_required { 56 + 20 } else { 0 } + 22;

    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    }

    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open(dest_path)
        .map_err(|_| TTZipStatus::ErrOpenFailed)?;

    let fd = file.as_raw_fd();
    let _ = apfs_preallocate(fd, total_file_size as i64);
    unsafe {
        libc::ftruncate(fd, total_file_size as libc::off_t);
    }

    // 2. Multithreaded lock-free `pwrite` of Local File Headers & Data
    let thread_budget = (options.thread_budget as usize).clamp(1, 64);
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(thread_budget)
        .build()
        .map_err(|_| TTZipStatus::ErrArchiveInitFailed)?;

    struct EntryResult {
        crc32: u32,
    }

    let results: Vec<EntryResult> = pool.install(|| {
        plan_items
            .par_iter()
            .map(|item| -> Result<EntryResult, TTZipStatus> {
                let (dos_time, dos_date) = unix_to_dos_time(item.mtime_secs);
                let name_bytes = item.rel_path.as_bytes();
                let use_zip64 = item.size >= 0xFFFFFFFF || item.lfh_offset >= 0xFFFFFFFF;

                let mut extra_bytes = Vec::new();
                if use_zip64 {
                    extra_bytes.extend_from_slice(&ZipExtraFields::build_zip64_extra(
                        Some(item.size),
                        Some(item.size),
                        None,
                    ));
                }
                extra_bytes.extend_from_slice(&ZipExtraFields::build_extended_timestamp(item.mtime_secs));

                let (crc32, file_data) = if let Some(ref src) = item.src_path {
                    let data = fs::read(src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
                    let crc = crc32_fast(0, &data);
                    (crc, data)
                } else {
                    (0, Vec::new())
                };

                let uncomp_size_field = if item.size >= 0xFFFFFFFF { 0xFFFFFFFFu32 } else { item.size as u32 };
                let version_needed = if use_zip64 { 45u16 } else { 10u16 };

                let mut header = Vec::with_capacity(item.lfh_header_size);
                header.extend_from_slice(&MAGIC_LFH.to_le_bytes());
                header.extend_from_slice(&version_needed.to_le_bytes());
                header.extend_from_slice(&0x0800u16.to_le_bytes()); // bit 11 UTF-8
                header.extend_from_slice(&0u16.to_le_bytes()); // Store method
                header.extend_from_slice(&dos_time.to_le_bytes());
                header.extend_from_slice(&dos_date.to_le_bytes());
                header.extend_from_slice(&crc32.to_le_bytes());
                header.extend_from_slice(&uncomp_size_field.to_le_bytes());
                header.extend_from_slice(&uncomp_size_field.to_le_bytes());
                header.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
                header.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
                header.extend_from_slice(name_bytes);
                header.extend_from_slice(&extra_bytes);

                // Lock-free pwrite header
                let written = unsafe {
                    libc::pwrite(
                        fd,
                        header.as_ptr() as *const libc::c_void,
                        header.len(),
                        item.lfh_offset as libc::off_t,
                    )
                };
                if written != header.len() as isize {
                    return Err(TTZipStatus::ErrCompressionFailed);
                }

                // Lock-free pwrite data
                if !file_data.is_empty() {
                    let data_offset = item.lfh_offset + (header.len() as u64);
                    let written_data = unsafe {
                        libc::pwrite(
                            fd,
                            file_data.as_ptr() as *const libc::c_void,
                            file_data.len(),
                            data_offset as libc::off_t,
                        )
                    };
                    if written_data != file_data.len() as isize {
                        return Err(TTZipStatus::ErrCompressionFailed);
                    }
                }

                Ok(EntryResult { crc32 })
            })
            .collect::<Result<Vec<EntryResult>, TTZipStatus>>()
    })?;

    // 3. Write Central Directory and EOCD
    let mut cd_bytes = Vec::with_capacity(cd_size as usize + 128);
    for (i, item) in plan_items.iter().enumerate() {
        let (dos_time, dos_date) = unix_to_dos_time(item.mtime_secs);
        let name_bytes = item.rel_path.as_bytes();
        let use_zip64 = item.size >= 0xFFFFFFFF || item.lfh_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            let u_sz = if item.size >= 0xFFFFFFFF { Some(item.size) } else { None };
            let off = if item.lfh_offset >= 0xFFFFFFFF { Some(item.lfh_offset) } else { None };
            extra_bytes.extend_from_slice(&ZipExtraFields::build_zip64_extra(u_sz, u_sz, off));
        }
        extra_bytes.extend_from_slice(&ZipExtraFields::build_extended_timestamp(item.mtime_secs));

        let version_made_by = 0x031Eu16;
        let version_needed = if use_zip64 { 45u16 } else { 10u16 };
        let uncomp_size_field = if item.size >= 0xFFFFFFFF { 0xFFFFFFFFu32 } else { item.size as u32 };
        let lfh_offset_field = if item.lfh_offset >= 0xFFFFFFFF { 0xFFFFFFFFu32 } else { item.lfh_offset as u32 };
        let ext_attr = (item.mode << 16) | if item.is_directory { 0x10 } else { 0 };

        cd_bytes.extend_from_slice(&MAGIC_CDFH.to_le_bytes());
        cd_bytes.extend_from_slice(&version_made_by.to_le_bytes());
        cd_bytes.extend_from_slice(&version_needed.to_le_bytes());
        cd_bytes.extend_from_slice(&0x0800u16.to_le_bytes());
        cd_bytes.extend_from_slice(&0u16.to_le_bytes());
        cd_bytes.extend_from_slice(&dos_time.to_le_bytes());
        cd_bytes.extend_from_slice(&dos_date.to_le_bytes());
        cd_bytes.extend_from_slice(&results[i].crc32.to_le_bytes());
        cd_bytes.extend_from_slice(&uncomp_size_field.to_le_bytes());
        cd_bytes.extend_from_slice(&uncomp_size_field.to_le_bytes());
        cd_bytes.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
        cd_bytes.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
        cd_bytes.extend_from_slice(&0u16.to_le_bytes()); // comment len
        cd_bytes.extend_from_slice(&0u16.to_le_bytes()); // disk num
        cd_bytes.extend_from_slice(&0u16.to_le_bytes()); // internal attr
        cd_bytes.extend_from_slice(&ext_attr.to_le_bytes());
        cd_bytes.extend_from_slice(&lfh_offset_field.to_le_bytes());
        cd_bytes.extend_from_slice(name_bytes);
        cd_bytes.extend_from_slice(&extra_bytes);
    }

    let num_entries = plan_items.len() as u64;
    if is_zip64_required {
        let z64_eocd_pos = cd_offset + (cd_bytes.len() as u64);
        cd_bytes.extend_from_slice(&MAGIC_ZIP64_EOCD.to_le_bytes());
        cd_bytes.extend_from_slice(&44u64.to_le_bytes());
        cd_bytes.extend_from_slice(&45u16.to_le_bytes());
        cd_bytes.extend_from_slice(&45u16.to_le_bytes());
        cd_bytes.extend_from_slice(&0u32.to_le_bytes());
        cd_bytes.extend_from_slice(&0u32.to_le_bytes());
        cd_bytes.extend_from_slice(&num_entries.to_le_bytes());
        cd_bytes.extend_from_slice(&num_entries.to_le_bytes());
        cd_bytes.extend_from_slice(&cd_size.to_le_bytes());
        cd_bytes.extend_from_slice(&cd_offset.to_le_bytes());

        cd_bytes.extend_from_slice(&MAGIC_ZIP64_LOCATOR.to_le_bytes());
        cd_bytes.extend_from_slice(&0u32.to_le_bytes());
        cd_bytes.extend_from_slice(&z64_eocd_pos.to_le_bytes());
        cd_bytes.extend_from_slice(&1u32.to_le_bytes());
    }

    let entries_field = if num_entries >= 0xFFFF { 0xFFFFu16 } else { num_entries as u16 };
    let cd_size_field = if cd_size >= 0xFFFFFFFF { 0xFFFFFFFFu32 } else { cd_size as u32 };
    let cd_offset_field = if cd_offset >= 0xFFFFFFFF { 0xFFFFFFFFu32 } else { cd_offset as u32 };

    cd_bytes.extend_from_slice(&MAGIC_EOCD.to_le_bytes());
    cd_bytes.extend_from_slice(&0u16.to_le_bytes());
    cd_bytes.extend_from_slice(&0u16.to_le_bytes());
    cd_bytes.extend_from_slice(&entries_field.to_le_bytes());
    cd_bytes.extend_from_slice(&entries_field.to_le_bytes());
    cd_bytes.extend_from_slice(&cd_size_field.to_le_bytes());
    cd_bytes.extend_from_slice(&cd_offset_field.to_le_bytes());
    cd_bytes.extend_from_slice(&0u16.to_le_bytes());

    let cd_written = unsafe {
        libc::pwrite(
            fd,
            cd_bytes.as_ptr() as *const libc::c_void,
            cd_bytes.len(),
            cd_offset as libc::off_t,
        )
    };
    if cd_written != cd_bytes.len() as isize {
        return Err(TTZipStatus::ErrCompressionFailed);
    }

    let total_bytes: u64 = plan_items.iter().map(|it| it.size).sum();

    Ok(ZipCreateReport {
        total_entries: plan_items.len(),
        total_uncompressed_bytes: total_bytes,
        total_compressed_bytes: total_bytes,
        duration_ms: start_time.elapsed().as_millis() as u64,
    })
}
