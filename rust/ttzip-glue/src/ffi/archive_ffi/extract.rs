// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive extraction C-ABI FFI entry implementation.

use super::guards::ArchiveReadGuard;
use super::sys::*;
use crate::fs::apfs::apfs_preallocate;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::types::{TTZipExtractOptions, TTZipStatus};
use libc::{c_char, c_void, mode_t};
use std::ffi::CStr;
use std::fs;
use std::io::Write;
use std::os::unix::io::AsRawFd;
use std::panic::catch_unwind;
use std::path::Path;

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
                    let r = archive_read_data(
                        a,
                        buf.as_mut_ptr() as *mut c_void,
                        buf.len().min(size as usize),
                    );
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

                let mut file =
                    match engine.create_file_secure(&target_path, mode, mtime, overwrite) {
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

/// C-ABI exported 7z single entry extraction into an in-memory buffer with Early Termination.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_7z_extract_entry_memory(
    archive_path: *const c_char,
    entry_path: *const c_char,
    entry_index: i64,
    password: *const c_char,
    out_buffer: *mut u8,
    buffer_capacity: usize,
    out_extracted_len: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let arch_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let p = Path::new(arch_str);
        if !p.exists() {
            return TTZipStatus::ErrFileNotFound;
        }

        let data = match fs::read(p) {
            Ok(d) => d,
            Err(_) => return TTZipStatus::ErrOpenFailed,
        };

        let archive = match crate::sevenz::SevenZArchive::open_slice(&data) {
            Ok(a) => a,
            Err(e) => return e,
        };

        let target_idx = if entry_index >= 0 {
            entry_index as usize
        } else if !entry_path.is_null() {
            let ep_str = match CStr::from_ptr(entry_path).to_str() {
                Ok(s) => s,
                Err(_) => return TTZipStatus::ErrInvalidParam,
            };
            match archive.seek_index().get_by_path(ep_str) {
                Some(loc) => loc.file_index,
                None => return TTZipStatus::ErrFileNotFound,
            }
        } else {
            return TTZipStatus::ErrInvalidParam;
        };

        let pass_str = if !password.is_null() {
            CStr::from_ptr(password).to_str().ok()
        } else {
            None
        };

        let payload = match archive.extract_entry_bytes_stream(target_idx, pass_str) {
            Ok(bytes) => bytes,
            Err(e) => return e,
        };

        if !out_extracted_len.is_null() {
            *out_extracted_len = payload.len();
        }

        if !out_buffer.is_null() {
            if buffer_capacity < payload.len() {
                return TTZipStatus::ErrOutOfMemory;
            }
            if !payload.is_empty() {
                std::ptr::copy_nonoverlapping(payload.as_ptr(), out_buffer, payload.len());
            }
        }

        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

