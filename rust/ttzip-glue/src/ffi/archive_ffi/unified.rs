// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unified C-ABI FFI Archive Interface.
//!
//! Exposes unified archive lifecycle endpoints with complete panic safety,
//! multi-volume support, ZipSlip protection, and 17-format auto-dispatch.

use crate::archive::unified::UnifiedArchiveOrchestrator;
use crate::types::{
    TTZipCreateOptions, TTZipExtractOptions, TTZipInspectCallback, TTZipStatus,
};
use libc::{c_char, c_void};
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::path::{Path, PathBuf};

/// C-ABI unified archive creation endpoint.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_create_unified(
    source_paths: *const *const c_char,
    source_count: usize,
    destination_path: *const c_char,
    options: *const TTZipCreateOptions,
    split_volume_size_bytes: u64,
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
        let dest_path = Path::new(dest_str);

        let mut paths = Vec::with_capacity(source_count);
        for i in 0..source_count {
            let src_c = *source_paths.add(i);
            if src_c.is_null() {
                continue;
            }
            if let Ok(src_str) = CStr::from_ptr(src_c).to_str() {
                paths.push(PathBuf::from(src_str));
            }
        }

        if paths.is_empty() {
            return TTZipStatus::ErrInvalidParam;
        }

        match UnifiedArchiveOrchestrator::create_archive(
            &paths,
            dest_path,
            &*options,
            split_volume_size_bytes,
        ) {
            Ok(()) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI unified archive extraction endpoint.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_extract_unified(
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
        let dest_p = Path::new(dest_str);

        let default_opt = TTZipExtractOptions {
            destination_path: dest_c,
            password: std::ptr::null(),
            thread_budget: 0,
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: None,
            user_data: std::ptr::null_mut(),
        };

        let opt_ref = if !options.is_null() {
            &*options
        } else {
            &default_opt
        };

        match UnifiedArchiveOrchestrator::extract_archive(archive_p, dest_p, opt_ref) {
            Ok(()) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI unified archive inspection endpoint.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_inspect_unified(
    archive_path: *const c_char,
    password: *const c_char,
    detect_encoding: bool,
    callback: TTZipInspectCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if archive_path.is_null() || callback.is_none() {
            return TTZipStatus::ErrInvalidParam;
        }

        let arch_str = match CStr::from_ptr(archive_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let arch_p = Path::new(arch_str);

        let pwd_opt = if !password.is_null() {
            CStr::from_ptr(password).to_str().ok()
        } else {
            None
        };

        match UnifiedArchiveOrchestrator::inspect_archive(
            arch_p,
            pwd_opt,
            detect_encoding,
            callback,
            user_data,
        ) {
            Ok(_) => TTZipStatus::Ok,
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI unified archive repair endpoint.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_archive_repair_unified(
    damaged_path: *const c_char,
    repaired_path: *const c_char,
    out_salvaged_count: *mut usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if damaged_path.is_null() || repaired_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let damaged_str = match CStr::from_ptr(damaged_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        let repaired_str = match CStr::from_ptr(repaired_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match UnifiedArchiveOrchestrator::repair_archive(
            Path::new(damaged_str),
            Path::new(repaired_str),
        ) {
            Ok(count) => {
                if !out_salvaged_count.is_null() {
                    *out_salvaged_count = count;
                }
                TTZipStatus::Ok
            }
            Err(status) => status,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
