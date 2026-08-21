// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive creation C-ABI FFI entry implementation.

use super::guards::{ArchiveEntryGuard, ArchiveWriteGuard};
use super::sys::*;
use crate::types::{
    TTZipArchiveFormat, TTZipCreateOptions, TTZipEncryptionMethod, TTZipStatus,
};
use libc::{c_char, c_void, mode_t, time_t};
use std::ffi::{CStr, CString};
use std::fs::{self, File};
use std::io::Read;
use std::os::unix::fs::PermissionsExt;
use std::panic::catch_unwind;
use std::path::{Path, PathBuf};

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

/// C-ABI exported unified archive creation.
///
/// Compresses `source_paths` into `destination_path` according to `options`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_create_archive(
    source_paths: *const *const c_char,
    source_count: usize,
    destination_path: *const c_char,
    options: *const TTZipCreateOptions,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if source_paths.is_null()
            || source_count == 0
            || destination_path.is_null()
            || options.is_null()
        {
            return TTZipStatus::ErrInvalidParam;
        }

        let dest_str = match CStr::from_ptr(destination_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dest_p = Path::new(dest_str);
        if let Some(parent) = dest_p.parent() {
            if !parent.exists() {
                let _ = fs::create_dir_all(parent);
            }
        }

        let opt = &*options;
        let a = archive_write_new();
        if a.is_null() {
            return TTZipStatus::ErrOutOfMemory;
        }
        let guard = ArchiveWriteGuard(a);

        match opt.format {
            TTZipArchiveFormat::Zip | TTZipArchiveFormat::Auto => {
                archive_write_set_format_zip(a);
            }
            TTZipArchiveFormat::SevenZip => {
                if !opt.password.is_null() {
                    return TTZipStatus::ErrCompressionFailed;
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

        if !opt.password.is_null() {
            archive_write_set_passphrase(a, opt.password);
            if opt.encryption == TTZipEncryptionMethod::Aes256 {
                let enc_opt = CString::new("zip:encryption=aes256").unwrap();
                archive_write_set_options(a, enc_opt.as_ptr());
            }
        }

        let open_rc = archive_write_open_filename(a, destination_path);
        if open_rc != 0 {
            return TTZipStatus::ErrOpenFailed;
        }

        // Collect all entries to compress
        let mut entries_to_write: Vec<(PathBuf, String)> = Vec::new();
        for i in 0..source_count {
            let src_c = *source_paths.add(i);
            if src_c.is_null() {
                continue;
            }
            let src_str = match CStr::from_ptr(src_c).to_str() {
                Ok(s) => s,
                Err(_) => continue,
            };
            let src_path = Path::new(src_str);
            if !src_path.exists() && fs::symlink_metadata(src_path).is_err() {
                return TTZipStatus::ErrFileNotFound;
            }

            let base_parent = src_path.parent().unwrap_or(src_path);
            let _ = collect_entries_recursive(base_parent, src_path, &mut entries_to_write);
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
                return TTZipStatus::ErrOutOfMemory;
            }
            let entry_guard = ArchiveEntryGuard(entry);

            let rel_c_str = match CString::new(rel_name.as_str()) {
                Ok(c) => c,
                Err(_) => continue,
            };

            archive_entry_set_pathname(entry, rel_c_str.as_ptr());
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
                    return TTZipStatus::ErrCompressionFailed;
                }
                archive_write_finish_entry(a);
            } else if meta.is_dir() {
                archive_entry_set_filetype(entry, libc::S_IFDIR as u32);
                archive_entry_set_size(entry, 0);
                let r_hdr = archive_write_header(a, entry);
                if r_hdr != 0 {
                    return TTZipStatus::ErrCompressionFailed;
                }
                archive_write_finish_entry(a);
            } else {
                archive_entry_set_filetype(entry, libc::S_IFREG as u32);
                archive_entry_set_size(entry, meta.len() as i64);
                let r_hdr = archive_write_header(a, entry);
                if r_hdr != 0 {
                    return TTZipStatus::ErrCompressionFailed;
                }

                let mut file = match File::open(&abs_path) {
                    Ok(f) => f,
                    Err(_) => return TTZipStatus::ErrFileNotFound,
                };

                loop {
                    let n = match file.read(&mut buf) {
                        Ok(0) => break,
                        Ok(n) => n,
                        Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                        Err(_) => return TTZipStatus::ErrCompressionFailed,
                    };

                    let written = archive_write_data(a, buf.as_ptr() as *const c_void, n);
                    if written < 0 {
                        return TTZipStatus::ErrCompressionFailed;
                    }
                    processed_bytes = processed_bytes.saturating_add(n as u64);
                }
                archive_write_finish_entry(a);
            }

            drop(entry_guard);

            if let Some(cb) = opt.progress_callback {
                if !cb(processed_bytes, processed_bytes, rel_c_str.as_ptr(), opt.user_data) {
                    return TTZipStatus::Cancelled;
                }
            }
        }

        drop(guard);
        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
