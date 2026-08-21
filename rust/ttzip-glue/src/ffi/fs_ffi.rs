// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for filesystem security and APFS optimizations.

use crate::fs::apfs::{
    apfs_clone_file, apfs_fcopyfile_clone, apfs_preallocate, is_mac_junk_file, ttzip_remove_path_fast,
};
use crate::fs::filter_dsl::{DslParser, FilterExpr};
use crate::fs::safe_extract::sanitize_and_validate_path;
use crate::fs::scanner::{scan_directory_parallel, ScanOptions};
use crate::types::TTZipStatus;
use libc::{c_char, c_void};
use std::ffi::{CStr, CString};
use std::panic::catch_unwind;
use std::path::Path;

/// Validates entry path against destination directory to prevent ZipSlip traversal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_validate_path(
    dest_dir: *const c_char,
    entry_path: *const c_char,
    out_sanitized: *mut c_char,
    out_capacity: usize,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if dest_dir.is_null() || entry_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let dest_str = match CStr::from_ptr(dest_dir).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let entry_str = match CStr::from_ptr(entry_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        match sanitize_and_validate_path(Path::new(dest_str), entry_str) {
            Ok(valid_path) => {
                if !out_sanitized.is_null() && out_capacity > 0 {
                    let path_str = valid_path.to_string_lossy();
                    let bytes = path_str.as_bytes();
                    if bytes.len() + 1 > out_capacity {
                        return TTZipStatus::ErrPathTooLong;
                    }
                    std::ptr::copy_nonoverlapping(
                        bytes.as_ptr() as *const c_char,
                        out_sanitized,
                        bytes.len(),
                    );
                    *out_sanitized.add(bytes.len()) = 0;
                }
                TTZipStatus::Ok
            }
            Err(e) => e,
        }
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Preallocates contiguous physical extent space on APFS filesystems.
#[no_mangle]
pub extern "C" fn ttzip_rust_apfs_preallocate(fd: i32, target_size: i64) -> i32 {
    let result = catch_unwind(|| match apfs_preallocate(fd, target_size) {
        Ok(()) => 0,
        Err(_) => -1,
    });
    result.unwrap_or(-1)
}

/// Clones a file using APFS Copy-on-Write (CoW).
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_apfs_clone_file(
    src: *const c_char,
    dst: *const c_char,
    overwrite: bool,
) -> i32 {
    let result = catch_unwind(|| {
        if src.is_null() || dst.is_null() {
            return -1;
        }

        let src_str = match CStr::from_ptr(src).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let dst_str = match CStr::from_ptr(dst).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };

        match apfs_clone_file(Path::new(src_str), Path::new(dst_str), overwrite) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Clones file descriptor range via APFS `fcopyfile`.
#[no_mangle]
pub extern "C" fn ttzip_rust_apfs_clone_range(in_fd: i32, out_fd: i32) -> i32 {
    let result = catch_unwind(|| match apfs_fcopyfile_clone(in_fd, out_fd) {
        Ok(()) => 0,
        Err(_) => -1,
    });
    result.unwrap_or(-1)
}

/// Returns true if the path points to a macOS junk metadata artifact.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_is_mac_junk(path: *const c_char) -> bool {
    let result = catch_unwind(|| {
        if path.is_null() {
            return false;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        is_mac_junk_file(s)
    });
    result.unwrap_or(false)
}

/// Fast file or directory removal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_remove_path_fast(path: *const c_char) -> i32 {
    let result = catch_unwind(|| {
        if path.is_null() {
            return -1;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };
        match ttzip_remove_path_fast(Path::new(s)) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Raw C-ABI structure for a scanned filesystem item.
#[repr(C)]
pub struct TTZipScannedItemRaw {
    pub src_path: *const c_char,
    pub rel_path: *const c_char,
    pub file_size: u64,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
}

/// Callback function invoked for each scanned filesystem entry.
pub type TTZipScanCallback =
    Option<unsafe extern "C" fn(item: *const TTZipScannedItemRaw, user_data: *mut c_void) -> bool>;

/// Scan configuration passed over C-ABI.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct TTZipScanConfigRaw {
    pub include_hidden: bool,
    pub skip_mac_junk: bool,
    pub max_depth: u32,
    pub thread_budget: u32,
}

/// Recursively scans a filesystem directory in parallel with Rayon and invokes callback for each item.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_scan_directory_parallel(
    root_path: *const c_char,
    config: *const TTZipScanConfigRaw,
    callback: TTZipScanCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if root_path.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let path_str = match CStr::from_ptr(root_path).to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };

        let options = if !config.is_null() {
            let cfg = &*config;
            ScanOptions {
                include_hidden: cfg.include_hidden,
                skip_mac_junk: cfg.skip_mac_junk,
                max_depth: cfg.max_depth,
                thread_budget: cfg.thread_budget,
            }
        } else {
            ScanOptions::default()
        };

        let items = scan_directory_parallel(Path::new(path_str), &options);

        if let Some(cb) = callback {
            for item in &items {
                let c_src = match CString::new(item.src_path.as_bytes()) {
                    Ok(c) => c,
                    Err(_) => continue,
                };
                let c_rel = match CString::new(item.rel_path.as_bytes()) {
                    Ok(c) => c,
                    Err(_) => continue,
                };

                let raw_item = TTZipScannedItemRaw {
                    src_path: c_src.as_ptr(),
                    rel_path: c_rel.as_ptr(),
                    file_size: item.file_size,
                    mtime_epoch_secs: item.mtime_epoch_secs,
                    mode: item.mode,
                    is_directory: item.is_directory,
                };

                let should_continue = cb(&raw_item, user_data);
                if !should_continue {
                    return TTZipStatus::Cancelled;
                }
            }
        }

        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

// MARK: - Filter DSL C-ABI Engine

pub struct TTZipFilterDslEngine {
    pub expr: FilterExpr<'static>,
    pub raw_query: *mut str,
}

impl Drop for TTZipFilterDslEngine {
    fn drop(&mut self) {
        if !self.raw_query.is_null() {
            unsafe {
                let _ = Box::from_raw(self.raw_query);
            }
        }
    }
}

/// Creates a compiled Filter DSL engine from query string.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_create_filter_dsl_engine(
    query: *const c_char,
) -> *mut TTZipFilterDslEngine {
    let result = catch_unwind(|| {
        if query.is_null() {
            return std::ptr::null_mut();
        }
        let query_str = match CStr::from_ptr(query).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };
        let leaked_raw = Box::into_raw(query_str.to_string().into_boxed_str());
        let expr = DslParser::parse_or_fallback(unsafe { &*leaked_raw });
        Box::into_raw(Box::new(TTZipFilterDslEngine {
            expr,
            raw_query: leaked_raw,
        }))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Evaluates archive entry metadata against a compiled Filter DSL engine with zero heap allocation.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_eval_filter_dsl(
    engine: *const TTZipFilterDslEngine,
    path: *const c_char,
    uncompressed_size: u64,
    mtime_epoch_secs: i64,
) -> bool {
    let result = catch_unwind(|| {
        if engine.is_null() || path.is_null() {
            return false;
        }
        let path_str = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        (*engine)
            .expr
            .evaluate_metadata(path_str, uncompressed_size, mtime_epoch_secs)
    });
    result.unwrap_or(false)
}

/// Destroys a Filter DSL engine.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_free_filter_dsl_engine(engine: *mut TTZipFilterDslEngine) {
    let _ = catch_unwind(|| {
        if !engine.is_null() {
            let _ = Box::from_raw(engine);
        }
    });
}

