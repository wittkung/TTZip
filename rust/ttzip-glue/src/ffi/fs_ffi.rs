// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for filesystem security, APFS optimizations, and VFS hierarchical tree & search.

use crate::ffi::helpers::safe_cstr;
use crate::fs::apfs::{
    apfs_clone_file, apfs_fcopyfile_clone, apfs_preallocate, is_mac_junk_file, ttzip_remove_path_fast,
};
use crate::fs::safe_extract::sanitize_and_validate_path;
use crate::fs::scanner::{scan_directory_parallel, ScanOptions};
use crate::fs::vfs::{VfsEntry, VfsTree};
use crate::types::{TTZipEntryMetadata, TTZipStatus};
use libc::{c_char, c_void};
use std::ffi::CString;
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
        let dest_str = match unsafe { safe_cstr(dest_dir) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let entry_str = match unsafe { safe_cstr(entry_path) } {
            Ok(s) => s,
            Err(st) => return st,
        };

        match sanitize_and_validate_path(Path::new(dest_str), entry_str) {
            Ok(valid_path) => {
                if !out_sanitized.is_null() && out_capacity > 0 {
                    let path_str = valid_path.to_string_lossy();
                    let bytes = path_str.as_bytes();
                    if bytes.len() + 1 > out_capacity {
                        return TTZipStatus::ErrPathTooLong;
                    }
                    // SAFETY: out_sanitized is verified non-null and capacity >= bytes.len() + 1
                    unsafe {
                        std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, out_sanitized, bytes.len());
                        *out_sanitized.add(bytes.len()) = 0;
                    }
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
    catch_unwind(|| match apfs_preallocate(fd, target_size) {
        Ok(()) => 0,
        Err(_) => -1,
    }).unwrap_or(-1)
}

/// Clones a file using APFS Copy-on-Write (CoW).
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_apfs_clone_file(src: *const c_char, dst: *const c_char, overwrite: bool) -> i32 {
    catch_unwind(|| {
        let src_s = match unsafe { safe_cstr(src) } { Ok(s) => s, Err(_) => return -1 };
        let dst_s = match unsafe { safe_cstr(dst) } { Ok(s) => s, Err(_) => return -1 };
        match apfs_clone_file(Path::new(src_s), Path::new(dst_s), overwrite) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    }).unwrap_or(-1)
}

/// Clones file descriptor range via APFS `fcopyfile`.
#[no_mangle]
pub extern "C" fn ttzip_rust_apfs_clone_range(in_fd: i32, out_fd: i32) -> i32 {
    catch_unwind(|| match apfs_fcopyfile_clone(in_fd, out_fd) {
        Ok(()) => 0,
        Err(_) => -1,
    }).unwrap_or(-1)
}

/// Returns true if the path points to a macOS junk metadata artifact.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_is_mac_junk(path: *const c_char) -> bool {
    catch_unwind(|| {
        let s = match unsafe { safe_cstr(path) } { Ok(s) => s, Err(_) => return false };
        is_mac_junk_file(s)
    }).unwrap_or(false)
}

/// Fast file or directory removal.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_remove_path_fast(path: *const c_char) -> i32 {
    catch_unwind(|| {
        let s = match unsafe { safe_cstr(path) } { Ok(s) => s, Err(_) => return -1 };
        match ttzip_remove_path_fast(Path::new(s)) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    }).unwrap_or(-1)
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

pub type TTZipScanCallback =
    Option<unsafe extern "C" fn(item: *const TTZipScannedItemRaw, user_data: *mut c_void) -> bool>;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct TTZipScanConfigRaw {
    pub include_hidden: bool,
    pub skip_mac_junk: bool,
    pub max_depth: u32,
    pub thread_budget: u32,
}

/// Recursively scans a filesystem directory in parallel with Rayon.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_scan_directory_parallel(
    root_path: *const c_char,
    config: *const TTZipScanConfigRaw,
    callback: TTZipScanCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        let path_str = match unsafe { safe_cstr(root_path) } {
            Ok(s) => s,
            Err(st) => return st,
        };
        let options = if !config.is_null() {
            // SAFETY: config verified non-null
            let cfg = unsafe { &*config };
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
                let c_src = match CString::new(item.src_path.as_bytes()) { Ok(c) => c, Err(_) => continue };
                let c_rel = match CString::new(item.rel_path.as_bytes()) { Ok(c) => c, Err(_) => continue };
                let raw_item = TTZipScannedItemRaw {
                    src_path: c_src.as_ptr(),
                    rel_path: c_rel.as_ptr(),
                    file_size: item.file_size,
                    mtime_epoch_secs: item.mtime_epoch_secs,
                    mode: item.mode,
                    is_directory: item.is_directory,
                };
                // SAFETY: cb called with valid pointers
                if !unsafe { cb(&raw_item, user_data) } {
                    return TTZipStatus::Cancelled;
                }
            }
        }
        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

// MARK: - VFS Tree and Fuzzy Search C-ABI

pub struct TTZipVfsTreeHandle {
    pub inner: VfsTree,
}

/// Constructs a unified VFS tree from C-ABI entry metadata array.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_tree_build(
    entries: *const TTZipEntryMetadata,
    count: usize,
    root_name: *const c_char,
) -> *mut TTZipVfsTreeHandle {
    catch_unwind(|| {
        let r_name = unsafe { safe_cstr(root_name) }.unwrap_or("");

        let mut vfs_entries = Vec::with_capacity(count);
        if !entries.is_null() && count > 0 {
            for i in 0..count {
                // SAFETY: i < count and entries is verified non-null
                let meta = unsafe { &*entries.add(i) };
                let path_str = match unsafe { safe_cstr(meta.path) } {
                    Ok(s) => s,
                    Err(_) => continue,
                };
                vfs_entries.push(VfsEntry {
                    path: path_str.to_string(),
                    uncompressed_size: meta.uncompressed_size,
                    compressed_size: meta.compressed_size,
                    crc32: meta.crc32,
                    mtime_epoch_secs: meta.mtime_epoch_secs,
                    mode: meta.mode,
                    is_directory: meta.is_directory,
                    is_encrypted: meta.is_encrypted,
                });
            }
        }
        let tree = VfsTree::build_from_entries(&vfs_entries, r_name);
        Box::into_raw(Box::new(TTZipVfsTreeHandle { inner: tree }))
    }).unwrap_or(std::ptr::null_mut())
}

/// Renders ASCII/Unicode hierarchical tree into an allocated C-string buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_tree_render(
    handle: *const TTZipVfsTreeHandle,
    out_rendered: *mut *mut c_char,
) -> TTZipStatus {
    catch_unwind(|| {
        if handle.is_null() || out_rendered.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        // SAFETY: handle is verified non-null
        let tree = unsafe { &(*handle).inner };
        let rendered = tree.render_tree();
        let c_str = match CString::new(rendered) {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam,
        };
        // SAFETY: out_rendered is verified non-null
        unsafe { *out_rendered = c_str.into_raw() };
        TTZipStatus::Ok
    }).unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[repr(C)]
pub struct TTZipVfsSearchResultRaw {
    pub name: *const c_char,
    pub path: *const c_char,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
    pub score: i64,
}

pub type TTZipVfsSearchCallback =
    Option<unsafe extern "C" fn(result: *const TTZipVfsSearchResultRaw, user_data: *mut c_void) -> bool>;

/// Performs fast fuzzy search against VFS tree and invokes callback for each match.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_fuzzy_search(
    handle: *const TTZipVfsTreeHandle,
    query: *const c_char,
    callback: TTZipVfsSearchCallback,
    user_data: *mut c_void,
) -> TTZipStatus {
    catch_unwind(|| {
        if handle.is_null() { return TTZipStatus::ErrInvalidParam; }
        let cb = match callback { Some(f) => f, None => return TTZipStatus::ErrInvalidParam };
        let q_str = match unsafe { safe_cstr(query) } { Ok(s) => s, Err(st) => return st };

        // SAFETY: handle is verified non-null
        let tree = unsafe { &(*handle).inner };
        let search_results = tree.fuzzy_search(q_str);

        for res in &search_results {
            let c_name = match CString::new(res.name.as_bytes()) { Ok(c) => c, Err(_) => continue };
            let c_path = match CString::new(res.path.as_bytes()) { Ok(c) => c, Err(_) => continue };
            let raw_res = TTZipVfsSearchResultRaw {
                name: c_name.as_ptr(),
                path: c_path.as_ptr(),
                uncompressed_size: res.uncompressed_size,
                compressed_size: res.compressed_size,
                crc32: res.crc32,
                is_directory: res.is_directory,
                is_encrypted: res.is_encrypted,
                score: res.score,
            };
            // SAFETY: cb called with valid raw_res reference
            if !unsafe { cb(&raw_res, user_data) } {
                break;
            }
        }
        TTZipStatus::Ok
    }).unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Frees a VFS tree handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_tree_free(handle: *mut TTZipVfsTreeHandle) {
    let _ = catch_unwind(|| { if !handle.is_null() { drop(Box::from_raw(handle)); } });
}

/// Frees an allocated C-string buffer returned by VFS functions.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_free_string(ptr: *mut c_char) {
    let _ = catch_unwind(|| { if !ptr.is_null() { drop(CString::from_raw(ptr)); } });
}

/// Retrieves aggregated VFS tree statistics.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_vfs_tree_get_stats(
    handle: *const TTZipVfsTreeHandle,
    out_total_files: *mut u64,
    out_total_dirs: *mut u64,
    out_total_size: *mut u64,
) {
    let _ = catch_unwind(|| {
        if handle.is_null() { return; }
        let tree = &(*handle).inner;
        if !out_total_files.is_null() { *out_total_files = tree.root.total_files() as u64; }
        if !out_total_dirs.is_null() { *out_total_dirs = tree.root.total_directories() as u64; }
        if !out_total_size.is_null() { *out_total_size = tree.root.uncompressed_size; }
    });
}
