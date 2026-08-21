// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive non-destructive inspection submodule for Unified Orchestrator.

use std::ffi::{CStr, CString};
use std::path::Path;

use crate::ffi::archive_ffi::guards::ArchiveReadGuard;
use crate::ffi::archive_ffi::sys::*;
use crate::types::{TTZipEntryMetadata, TTZipInspectCallback, TTZipStatus};
use libc::{c_void, mode_t};

/// Inspects an archive and invokes the callback for every discovered entry metadata item.
pub fn inspect_archive(
    archive_path: &Path,
    password: Option<&str>,
    detect_encoding: bool,
    callback: TTZipInspectCallback,
    user_data: *mut c_void,
) -> Result<usize, TTZipStatus> {
    let cb = callback.ok_or(TTZipStatus::ErrInvalidParam)?;
    if !archive_path.exists() {
        return Err(TTZipStatus::ErrFileNotFound);
    }

    let arch_c = CString::new(archive_path.to_str().ok_or(TTZipStatus::ErrInvalidParam)?)
        .map_err(|_| TTZipStatus::ErrInvalidParam)?;
    let pwd_c = password.and_then(|p| CString::new(p).ok());

    unsafe {
        let a = archive_read_new();
        if a.is_null() {
            return Err(TTZipStatus::ErrOutOfMemory);
        }
        let _guard = ArchiveReadGuard(a);

        archive_read_support_format_all(a);
        archive_read_support_filter_all(a);

        if let Some(ref p) = pwd_c {
            archive_read_add_passphrase(a, p.as_ptr());
        }

        let open_rc = archive_read_open_filename(a, arch_c.as_ptr(), 65536);
        if open_rc != 0 {
            return Err(TTZipStatus::ErrOpenFailed);
        }

        let mut entry: *mut c_void = std::ptr::null_mut();
        let mut count = 0;

        while archive_read_next_header(a, &mut entry) == 0 {
            if entry.is_null() {
                break;
            }
            let raw_path = archive_entry_pathname(entry);
            if raw_path.is_null() {
                archive_read_data_skip(a);
                continue;
            }

            let path_bytes = CStr::from_ptr(raw_path).to_bytes();
            if path_bytes.is_empty() {
                archive_read_data_skip(a);
                continue;
            }

            if detect_encoding {
                let has_non_ascii = path_bytes.iter().any(|&b| b >= 0x80);
                if has_non_ascii {
                    let _ = crate::codecs::chardet::detect_charset(path_bytes);
                }
            }

            let uncompressed_size = archive_entry_size(entry).max(0) as u64;
            let mode = archive_entry_mode(entry) as u32;
            let filetype = archive_entry_filetype(entry);
            let is_dir = (filetype & (libc::S_IFMT as mode_t)) == (libc::S_IFDIR as mode_t)
                || (mode & (libc::S_IFMT as u32)) == (libc::S_IFDIR as u32)
                || path_bytes.ends_with(b"/");
            let mtime = archive_entry_mtime(entry) as i64;
            let is_data_enc = archive_entry_is_data_encrypted(entry) != 0;
            let is_meta_enc = archive_entry_is_metadata_encrypted(entry) != 0;

            let meta = TTZipEntryMetadata {
                path: raw_path,
                uncompressed_size,
                compressed_size: 0,
                crc32: 0,
                mtime_epoch_secs: mtime,
                mode,
                is_directory: is_dir,
                is_encrypted: is_data_enc || is_meta_enc,
                compression_method: 0,
            };

            count += 1;
            let should_continue = cb(&meta, user_data);
            archive_read_data_skip(a);

            if !should_continue {
                break;
            }
        }

        Ok(count)
    }
}
