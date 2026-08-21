// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-level C-ABI / FFI archive inspection, extraction, and creation unified entries.
//!
//! Enforces:
//! 1. Panic safety: FFI exception barriers via `std::panic::catch_unwind` on all entry points.
//! 2. Security invariant II: ZipSlip path sanitization & traversal defense.
//! 3. Two-stage deferred bottom-up metadata and permission application.
//! 4. Hardware APFS extent preallocation.

use crate::fs::apfs::apfs_preallocate;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::types::{
    TTZipArchiveFormat, TTZipCreateOptions, TTZipEncryptionMethod, TTZipEntryMetadata,
    TTZipExtractOptions, TTZipInspectCallback, TTZipStatus,
};
use libc::{c_char, c_int, c_long, c_uint, c_void, mode_t, size_t, ssize_t, time_t};
use std::ffi::{CStr, CString};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::io::AsRawFd;
use std::panic::catch_unwind;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Libarchive C-ABI extern declarations
// ---------------------------------------------------------------------------

extern "C" {
    fn archive_read_new() -> *mut c_void;
    fn archive_read_support_format_all(a: *mut c_void) -> c_int;
    fn archive_read_support_filter_all(a: *mut c_void) -> c_int;
    fn archive_read_add_passphrase(a: *mut c_void, passphrase: *const c_char) -> c_int;
    fn archive_read_open_filename(a: *mut c_void, filename: *const c_char, block_size: size_t) -> c_int;
    fn archive_read_next_header(a: *mut c_void, entry: *mut *mut c_void) -> c_int;
    fn archive_read_data(a: *mut c_void, buff: *mut c_void, len: size_t) -> ssize_t;
    fn archive_read_data_skip(a: *mut c_void) -> c_int;
    fn archive_read_close(a: *mut c_void) -> c_int;
    fn archive_read_free(a: *mut c_void) -> c_int;

    fn archive_entry_pathname(e: *mut c_void) -> *const c_char;
    fn archive_entry_size(e: *mut c_void) -> i64;
    fn archive_entry_filetype(e: *mut c_void) -> mode_t;
    fn archive_entry_mode(e: *mut c_void) -> mode_t;
    fn archive_entry_mtime(e: *mut c_void) -> time_t;
    fn archive_entry_symlink(e: *mut c_void) -> *const c_char;
    fn archive_entry_set_symlink(e: *mut c_void, symlink: *const c_char);
    fn archive_entry_is_data_encrypted(e: *mut c_void) -> c_int;
    fn archive_entry_is_metadata_encrypted(e: *mut c_void) -> c_int;

    fn archive_entry_new() -> *mut c_void;
    fn archive_entry_free(e: *mut c_void);
    fn archive_entry_set_pathname(e: *mut c_void, pathname: *const c_char);
    fn archive_entry_set_size(e: *mut c_void, size: i64);
    fn archive_entry_set_filetype(e: *mut c_void, filetype: c_uint);
    fn archive_entry_set_perm(e: *mut c_void, perm: mode_t);
    fn archive_entry_set_mtime(e: *mut c_void, mtime: time_t, nanos: c_long);

    fn archive_write_new() -> *mut c_void;
    fn archive_write_set_format_zip(a: *mut c_void) -> c_int;
    fn archive_write_set_format_pax_restricted(a: *mut c_void) -> c_int;
    fn archive_write_set_format_7zip(a: *mut c_void) -> c_int;
    fn archive_write_add_filter_gzip(a: *mut c_void) -> c_int;
    fn archive_write_add_filter_bzip2(a: *mut c_void) -> c_int;
    fn archive_write_add_filter_xz(a: *mut c_void) -> c_int;
    fn archive_write_add_filter_zstd(a: *mut c_void) -> c_int;
    fn archive_write_set_passphrase(a: *mut c_void, passphrase: *const c_char) -> c_int;
    fn archive_write_set_options(a: *mut c_void, opts: *const c_char) -> c_int;
    fn archive_write_open_filename(a: *mut c_void, filename: *const c_char) -> c_int;
    fn archive_write_header(a: *mut c_void, entry: *mut c_void) -> c_int;
    fn archive_write_data(a: *mut c_void, buff: *const c_void, len: size_t) -> ssize_t;
    fn archive_write_finish_entry(a: *mut c_void) -> c_int;
    fn archive_write_close(a: *mut c_void) -> c_int;
    fn archive_write_free(a: *mut c_void) -> c_int;
}

// ---------------------------------------------------------------------------
// RAII Safe Cleanup Guards
// ---------------------------------------------------------------------------

struct ArchiveReadGuard(*mut c_void);

impl Drop for ArchiveReadGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_read_close(self.0);
                archive_read_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}

struct ArchiveWriteGuard(*mut c_void);

impl Drop for ArchiveWriteGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_write_close(self.0);
                archive_write_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}

struct ArchiveEntryGuard(*mut c_void);

impl Drop for ArchiveEntryGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_entry_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}

// ---------------------------------------------------------------------------
// FFI Implementation: Inspect Archive
// ---------------------------------------------------------------------------

/// C-ABI exported unified archive inspection.
///
/// Iterates over all headers in `archive_path` and delivers `TTZipEntryMetadata`
/// to the caller callback. Returning `false` from `callback` halts traversal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_inspect_archive(
    archive_path: *const c_char,
    password: *const c_char,
    detect_encoding: bool,
    callback: TTZipInspectCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let cb = match callback {
            Some(f) => f,
            None => return TTZipStatus::ErrInvalidParam,
        };

        let path_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        if !Path::new(path_str).exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let a = archive_read_new();
        if a.is_null() {
            return TTZipStatus::ErrOutOfMemory;
        }
        let guard = ArchiveReadGuard(a);

        archive_read_support_format_all(a);
        archive_read_support_filter_all(a);

        if !password.is_null() {
            if let Ok(p_str) = CStr::from_ptr(password).to_str() {
                if !p_str.is_empty() {
                    archive_read_add_passphrase(a, password);
                }
            }
        }

        let open_rc = archive_read_open_filename(a, archive_path, 65536);
        if open_rc != 0 {
            return TTZipStatus::ErrOpenFailed;
        }

        let mut entry: *mut c_void = std::ptr::null_mut();

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

            let should_continue = cb(&meta, user_data);
            archive_read_data_skip(a);

            if !should_continue {
                break;
            }
        }

        drop(guard);
        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

// ---------------------------------------------------------------------------
// FFI Implementation: Extract Archive
// ---------------------------------------------------------------------------

/// C-ABI exported unified archive extraction.
///
/// Implements two-stage safe extraction with `O_NOFOLLOW`, ZipSlip validation,
/// micro-buffering, and bottom-up permission/mtime application.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_extract_archive(
    archive_path: *const c_char,
    destination_path: *const c_char,
    options: *const TTZipExtractOptions,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let dest_c = if !destination_path.is_null() {
            destination_path
        } else if !options.is_null() && !(*options).destination_path.is_null() {
            (*options).destination_path
        } else {
            return TTZipStatus::ErrInvalidParam;
        };

        let archive_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let dest_str = match CStr::from_ptr(dest_c).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let archive_p = Path::new(archive_str);
        if !archive_p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }
        let dest_p = Path::new(dest_str);

        let (password, overwrite, preserve_perm, dry_run, progress_cb, user_data) =
            if !options.is_null() {
                let opt = &*options;
                (
                    opt.password,
                    opt.overwrite_existing,
                    opt.preserve_permissions,
                    opt.dry_run,
                    opt.progress_callback,
                    opt.user_data,
                )
            } else {
                (std::ptr::null(), true, true, false, None, std::ptr::null_mut())
            };

        if !dry_run {
            if fs::create_dir_all(dest_p).is_err() {
                return TTZipStatus::ErrExtractionFailed;
            }
        }

        let a = archive_read_new();
        if a.is_null() {
            return TTZipStatus::ErrOutOfMemory;
        }
        let guard = ArchiveReadGuard(a);

        archive_read_support_format_all(a);
        archive_read_support_filter_all(a);

        if !password.is_null() {
            if let Ok(p_str) = CStr::from_ptr(password).to_str() {
                if !p_str.is_empty() {
                    archive_read_add_passphrase(a, password);
                }
            }
        }

        let open_rc = archive_read_open_filename(a, archive_path, 65536);
        if open_rc != 0 {
            return TTZipStatus::ErrOpenFailed;
        }

        let mut engine = SafeExtractEngine::new();
        let mut entry: *mut c_void = std::ptr::null_mut();
        let mut total_processed: u64 = 0;
        let mut buf = vec![0u8; 64 * 1024];

        while archive_read_next_header(a, &mut entry) == 0 {
            if entry.is_null() {
                break;
            }
            let raw_path = archive_entry_pathname(entry);
            if raw_path.is_null() {
                archive_read_data_skip(a);
                continue;
            }

            let entry_rel_str = match CStr::from_ptr(raw_path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    archive_read_data_skip(a);
                    continue;
                }
            };

            // Invariant II: ZipSlip & Security Path Validation
            let target_path = match sanitize_and_validate_path(dest_p, entry_rel_str) {
                Ok(p) => p,
                Err(status) => {
                    return status;
                }
            };

            let size = archive_entry_size(entry).max(0) as u64;
            let mode = archive_entry_mode(entry) as u32;
            let mtime = archive_entry_mtime(entry) as i64;
            let filetype = archive_entry_filetype(entry);
            let is_symlink = (filetype & (libc::S_IFMT as mode_t)) == (libc::S_IFLNK as mode_t);
            let is_dir = (filetype & (libc::S_IFMT as mode_t)) == (libc::S_IFDIR as mode_t)
                || (mode & (libc::S_IFMT as u32)) == (libc::S_IFDIR as u32)
                || entry_rel_str.ends_with('/');

            if dry_run {
                if !is_dir && !is_symlink && size > 0 {
                    let r = archive_read_data(a, buf.as_mut_ptr() as *mut c_void, buf.len().min(size as usize));
                    if r < 0 {
                        return TTZipStatus::ErrInvalidPassword;
                    }
                } else {
                    archive_read_data_skip(a);
                }
                total_processed = total_processed.saturating_add(size);
                if let Some(cb) = progress_cb {
                    if !cb(total_processed, total_processed, raw_path, user_data) {
                        return TTZipStatus::Cancelled;
                    }
                }
                continue;
            }

            if is_symlink {
                let symlink_raw = archive_entry_symlink(entry);
                if !symlink_raw.is_null() {
                    if let Ok(symlink_target) = CStr::from_ptr(symlink_raw).to_str() {
                        if target_path.exists() || fs::symlink_metadata(&target_path).is_ok() {
                            let _ = fs::remove_file(&target_path);
                        }
                        if let Some(parent) = target_path.parent() {
                            if !parent.exists() {
                                let _ = fs::create_dir_all(parent);
                            }
                        }
                        let _ = std::os::unix::fs::symlink(symlink_target, &target_path);
                    }
                }
                archive_read_data_skip(a);
            } else if is_dir {
                if engine.create_dir_all_secure(&target_path, mode, mtime).is_err() {
                    return TTZipStatus::ErrExtractionFailed;
                }
                archive_read_data_skip(a);
            } else {
                if let Some(parent) = target_path.parent() {
                    if !parent.exists() {
                        let _ = engine.create_dir_all_secure(parent, 0o755, mtime);
                    }
                }

                let mut file = match engine.create_file_secure(&target_path, mode, mtime, overwrite) {
                    Ok(f) => f,
                    Err(_) => {
                        return TTZipStatus::ErrExtractionFailed;
                    }
                };

                if size > 0 {
                    let _ = apfs_preallocate(file.as_raw_fd(), size as i64);
                }

                loop {
                    let r = archive_read_data(a, buf.as_mut_ptr() as *mut c_void, buf.len());
                    if r < 0 {
                        drop(file);
                        let _ = fs::remove_file(&target_path);
                        return TTZipStatus::ErrInvalidPassword;
                    }
                    if r == 0 {
                        break;
                    }
                    let n = r as usize;
                    if file.write_all(&buf[..n]).is_err() {
                        drop(file);
                        let _ = fs::remove_file(&target_path);
                        return TTZipStatus::ErrExtractionFailed;
                    }
                    total_processed = total_processed.saturating_add(n as u64);
                }

                drop(file);
            }

            if let Some(cb) = progress_cb {
                if !cb(total_processed, total_processed, raw_path, user_data) {
                    return TTZipStatus::Cancelled;
                }
            }
        }

        drop(guard);

        if !dry_run {
            if let Err(e) = engine.apply_deferred_metadata(preserve_perm) {
                return e;
            }
        }

        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

// ---------------------------------------------------------------------------
// FFI Implementation: Create Archive
// ---------------------------------------------------------------------------

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
        if source_paths.is_null() || source_count == 0 || destination_path.is_null() || options.is_null() {
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
