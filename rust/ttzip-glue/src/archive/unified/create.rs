// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive creation lifecycle submodule for Unified Orchestrator.

use std::ffi::CString;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use crate::archive::split::{SplitVolumeWriter, VolumeNamingScheme};
use crate::archive::unified::detect::resolve_create_format;
use crate::ffi::archive_ffi::guards::{ArchiveEntryGuard, ArchiveWriteGuard};
use crate::ffi::archive_ffi::sys::*;
use crate::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipStatus,
};
use libc::{c_void, mode_t, time_t};

/// Recursively compresses source paths into the destination archive path.
pub fn create_archive(
    source_paths: &[PathBuf],
    destination_path: &Path,
    options: &TTZipCreateOptions,
    split_volume_size_bytes: u64,
) -> Result<(), TTZipStatus> {
    if source_paths.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    if let Some(parent) = destination_path.parent() {
        if !parent.exists() {
            let _ = fs::create_dir_all(parent);
        }
    }

    let resolved_format = resolve_create_format(options.format, destination_path);

    // If split volume is requested, write to temporary file first
    let temp_archive_path = if split_volume_size_bytes > 0 {
        let temp_dir = std::env::temp_dir();
        let rand_name = format!(
            "ttzip_split_tmp_{}_{}.tmp",
            std::process::id(),
            destination_path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("archive")
        );
        temp_dir.join(rand_name)
    } else {
        destination_path.to_path_buf()
    };

    let dest_c = CString::new(
        temp_archive_path
            .to_str()
            .ok_or(TTZipStatus::ErrInvalidParam)?,
    )
    .map_err(|_| TTZipStatus::ErrInvalidParam)?;

    unsafe {
        let a = archive_write_new();
        if a.is_null() {
            return Err(TTZipStatus::ErrOutOfMemory);
        }
        let _guard = ArchiveWriteGuard(a);

        match resolved_format {
            TTZipArchiveFormat::Zip | TTZipArchiveFormat::Auto => {
                archive_write_set_format_zip(a);
                let lvl = match options.level {
                    TTZipCompressionLevel::Store => 0,
                    TTZipCompressionLevel::Fastest => 1,
                    TTZipCompressionLevel::Fast => 3,
                    TTZipCompressionLevel::Normal => 6,
                    TTZipCompressionLevel::Maximum => 9,
                    TTZipCompressionLevel::Ultra => 9,
                };
                let lvl_opt = CString::new(format!("zip:compression-level={}", lvl)).unwrap();
                archive_write_set_options(a, lvl_opt.as_ptr());
            }
            TTZipArchiveFormat::SevenZip => {
                if !options.password.is_null() {
                    return Err(TTZipStatus::ErrCompressionFailed);
                }
                archive_write_set_format_7zip(a);
            }
            TTZipArchiveFormat::Tar => {
                archive_write_set_format_pax_restricted(a);
            }
            TTZipArchiveFormat::TarGz => {
                archive_write_set_format_pax_restricted(a);
                archive_write_add_filter_gzip(a);
            }
            TTZipArchiveFormat::TarBz2 => {
                archive_write_set_format_pax_restricted(a);
                archive_write_add_filter_bzip2(a);
            }
            TTZipArchiveFormat::TarXz => {
                archive_write_set_format_pax_restricted(a);
                archive_write_add_filter_xz(a);
            }
            TTZipArchiveFormat::TarZstd => {
                archive_write_set_format_pax_restricted(a);
                archive_write_add_filter_zstd(a);
            }
            _ => {
                archive_write_set_format_zip(a);
            }
        }

        if !options.password.is_null() {
            archive_write_set_passphrase(a, options.password);
            if options.encryption == TTZipEncryptionMethod::Aes256 {
                let enc_opt = CString::new("zip:encryption=aes256").unwrap();
                archive_write_set_options(a, enc_opt.as_ptr());
            }
        }

        let open_rc = archive_write_open_filename(a, dest_c.as_ptr());
        if open_rc != 0 {
            return Err(TTZipStatus::ErrOpenFailed);
        }

        // Collect all source entries
        let mut entries_to_write = Vec::new();
        for src_path in source_paths {
            if !src_path.exists() && fs::symlink_metadata(src_path).is_err() {
                return Err(TTZipStatus::ErrFileNotFound);
            }
            let base_parent = src_path.parent().unwrap_or(src_path);
            collect_entries_recursive(base_parent, src_path, &mut entries_to_write)
                .map_err(|_| TTZipStatus::ErrFileNotFound)?;
        }

        let mut processed_bytes: u64 = 0;
        let mut buf = vec![0u8; 64 * 1024];

        for (abs_path, rel_name) in entries_to_write {
            let meta = match fs::symlink_metadata(&abs_path) {
                Ok(m) => m,
                Err(_) => continue,
            };

            let entry = archive_entry_new();
            if entry.is_null() {
                return Err(TTZipStatus::ErrOutOfMemory);
            }
            let _entry_guard = ArchiveEntryGuard(entry);

            let rel_c = match CString::new(rel_name.as_str()) {
                Ok(c) => c,
                Err(_) => continue,
            };

            archive_entry_set_pathname(entry, rel_c.as_ptr());
            archive_entry_set_perm(entry, (meta.permissions().mode() & 0o7777) as mode_t);

            let mtime = meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as time_t)
                .unwrap_or(0);
            archive_entry_set_mtime(entry, mtime, 0);

            if meta.file_type().is_symlink() {
                archive_entry_set_filetype(entry, libc::S_IFLNK as u32);
                archive_entry_set_size(entry, 0);
                if let Ok(link_target) = fs::read_link(&abs_path) {
                    if let Ok(link_c) = CString::new(link_target.to_string_lossy().as_bytes()) {
                        archive_entry_set_symlink(entry, link_c.as_ptr());
                    }
                }
                let r_hdr = archive_write_header(a, entry);
                if r_hdr != 0 {
                    return Err(TTZipStatus::ErrCompressionFailed);
                }
                archive_write_finish_entry(a);
            } else if meta.is_dir() {
                archive_entry_set_filetype(entry, libc::S_IFDIR as u32);
                archive_entry_set_size(entry, 0);
                let r_hdr = archive_write_header(a, entry);
                if r_hdr != 0 {
                    return Err(TTZipStatus::ErrCompressionFailed);
                }
                archive_write_finish_entry(a);
            } else {
                archive_entry_set_filetype(entry, libc::S_IFREG as u32);
                archive_entry_set_size(entry, meta.len() as i64);
                let r_hdr = archive_write_header(a, entry);
                if r_hdr != 0 {
                    return Err(TTZipStatus::ErrCompressionFailed);
                }

                let mut file = File::open(&abs_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
                loop {
                    let n = match file.read(&mut buf) {
                        Ok(0) => break,
                        Ok(n) => n,
                        Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                        Err(_) => return Err(TTZipStatus::ErrCompressionFailed),
                    };

                    let written = archive_write_data(a, buf.as_ptr() as *const c_void, n);
                    if written < 0 {
                        return Err(TTZipStatus::ErrCompressionFailed);
                    }
                    processed_bytes = processed_bytes.saturating_add(n as u64);
                }
                archive_write_finish_entry(a);
            }

            if let Some(cb) = options.progress_callback {
                if !cb(processed_bytes, processed_bytes, rel_c.as_ptr(), options.user_data) {
                    return Err(TTZipStatus::Cancelled);
                }
            }
        }
    }

    // Handle Split Volume Slicing
    if split_volume_size_bytes > 0 {
        let total_file_len = fs::metadata(&temp_archive_path)
            .map_err(|_| TTZipStatus::ErrOpenFailed)?
            .len();

        if total_file_len > split_volume_size_bytes {
            let is_zip = resolved_format == TTZipArchiveFormat::Zip;
            let scheme = if is_zip {
                VolumeNamingScheme::PkzipSpanned
            } else {
                VolumeNamingScheme::NumberedExtension
            };

            let mut split_writer = SplitVolumeWriter::new(
                destination_path,
                split_volume_size_bytes,
                scheme,
            )
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

            let mut temp_file = File::open(&temp_archive_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
            let mut copy_buf = vec![0u8; 64 * 1024];
            loop {
                let n = temp_file
                    .read(&mut copy_buf)
                    .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                if n == 0 {
                    break;
                }
                split_writer
                    .write_all(&copy_buf[..n])
                    .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            }
            split_writer.close().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            let _ = fs::remove_file(&temp_archive_path);
        } else {
            let _ = fs::rename(&temp_archive_path, destination_path);
        }
    }

    Ok(())
}

fn collect_entries_recursive(
    root: &Path,
    current: &Path,
    out: &mut Vec<(PathBuf, String)>,
) -> std::io::Result<()> {
    let rel_prefix = current.strip_prefix(root).unwrap_or(current);
    let rel_str = rel_prefix.to_string_lossy().to_string();

    if !rel_str.is_empty() {
        out.push((current.to_path_buf(), rel_str));
    }

    if let Ok(meta) = fs::symlink_metadata(current) {
        if meta.is_dir() && !meta.file_type().is_symlink() {
            for entry in fs::read_dir(current)? {
                let entry = entry?;
                collect_entries_recursive(root, &entry.path(), out)?;
            }
        }
    }
    Ok(())
}
