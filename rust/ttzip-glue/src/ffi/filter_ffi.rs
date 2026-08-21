// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for zero-allocation Archive Filter DSL and GlobSet path filtering.

use crate::fs::filter::{
    glob_matches, is_mac_junk_metadata, is_vcs_metadata, strip_leading_components, DslParser,
    FilterExpr, PathPatternFilter,
};
use libc::c_char;
use std::ffi::CStr;
use std::panic::catch_unwind;

// MARK: - Archive Filter DSL FFI

pub struct TTZipDslFilterHandle {
    expr: FilterExpr<'static>,
    raw_query: *mut str,
}

impl Drop for TTZipDslFilterHandle {
    fn drop(&mut self) {
        if !self.raw_query.is_null() {
            unsafe {
                let _ = Box::from_raw(self.raw_query);
            }
        }
    }
}

/// Compiles a DSL query string into an opaque filter handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_dsl_filter_new(
    query: *const c_char,
) -> *mut TTZipDslFilterHandle {
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
        Box::into_raw(Box::new(TTZipDslFilterHandle {
            expr,
            raw_query: leaked_raw,
        }))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Evaluates entry metadata against a compiled DSL filter handle with zero heap allocation.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_dsl_filter_evaluate(
    handle: *const TTZipDslFilterHandle,
    path: *const c_char,
    uncompressed_size: u64,
    mtime_epoch_secs: i64,
) -> bool {
    let result = catch_unwind(|| {
        if handle.is_null() || path.is_null() {
            return false;
        }
        let path_str = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        (*handle)
            .expr
            .evaluate_metadata(path_str, uncompressed_size, mtime_epoch_secs)
    });
    result.unwrap_or(false)
}

/// Destroys a DSL filter handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_dsl_filter_free(handle: *mut TTZipDslFilterHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            let _ = Box::from_raw(handle);
        }
    });
}

/// One-shot evaluation of DSL query against entry metadata.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_dsl_evaluate_oneshot(
    query: *const c_char,
    path: *const c_char,
    uncompressed_size: u64,
    mtime_epoch_secs: i64,
) -> bool {
    let result = catch_unwind(|| {
        if query.is_null() || path.is_null() {
            return false;
        }
        let query_str = match CStr::from_ptr(query).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let path_str = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let expr = DslParser::parse_or_fallback(query_str);
        expr.evaluate_metadata(path_str, uncompressed_size, mtime_epoch_secs)
    });
    result.unwrap_or(false)
}

pub type TTZipFilterDslEngine = TTZipDslFilterHandle;

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_create_filter_dsl_engine(query: *const c_char) -> *mut TTZipFilterDslEngine {
    ttzip_rust_dsl_filter_new(query)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_eval_filter_dsl(
    engine: *const TTZipFilterDslEngine,
    path: *const c_char,
    uncompressed_size: u64,
    mtime_epoch_secs: i64,
) -> bool {
    ttzip_rust_dsl_filter_evaluate(engine, path, uncompressed_size, mtime_epoch_secs)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_free_filter_dsl_engine(engine: *mut TTZipFilterDslEngine) {
    ttzip_rust_dsl_filter_free(engine);
}

// MARK: - Path Pattern Filter Engine FFI

pub struct TTZipPathFilterHandle(pub PathPatternFilter);

/// Compiles include and exclude pattern sets into a fast DFA filter handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_path_filter_new(
    include_patterns: *const *const c_char,
    include_count: usize,
    exclude_patterns: *const *const c_char,
    exclude_count: usize,
    exclude_vcs: bool,
    no_mac_metadata: bool,
) -> *mut TTZipPathFilterHandle {
    let result = catch_unwind(|| {
        let mut inc_vec: Vec<&str> = Vec::with_capacity(include_count);
        if !include_patterns.is_null() && include_count > 0 {
            for i in 0..include_count {
                let ptr = *include_patterns.add(i);
                if !ptr.is_null() {
                    if let Ok(s) = CStr::from_ptr(ptr).to_str() {
                        inc_vec.push(s);
                    }
                }
            }
        }

        let mut exc_vec: Vec<&str> = Vec::with_capacity(exclude_count);
        if !exclude_patterns.is_null() && exclude_count > 0 {
            for i in 0..exclude_count {
                let ptr = *exclude_patterns.add(i);
                if !ptr.is_null() {
                    if let Ok(s) = CStr::from_ptr(ptr).to_str() {
                        exc_vec.push(s);
                    }
                }
            }
        }

        match PathPatternFilter::new(&inc_vec, &exc_vec, exclude_vcs, no_mac_metadata) {
            Ok(filter) => Box::into_raw(Box::new(TTZipPathFilterHandle(filter))),
            Err(_) => std::ptr::null_mut(),
        }
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Evaluates if path should be included.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_path_filter_should_include(
    handle: *const TTZipPathFilterHandle,
    path: *const c_char,
) -> bool {
    let result = catch_unwind(|| {
        if handle.is_null() || path.is_null() {
            return true;
        }
        let path_str = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return true,
        };
        (*handle).0.should_include(path_str)
    });
    result.unwrap_or(true)
}

/// Evaluates if path should be excluded.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_path_filter_should_exclude(
    handle: *const TTZipPathFilterHandle,
    path: *const c_char,
) -> bool {
    !ttzip_rust_path_filter_should_include(handle, path)
}

/// Destroys a PathPatternFilter handle.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_path_filter_free(handle: *mut TTZipPathFilterHandle) {
    let _ = catch_unwind(|| {
        if !handle.is_null() {
            let _ = Box::from_raw(handle);
        }
    });
}

/// Fast leading component stripping writing into out_buf.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_strip_leading_components(
    path: *const c_char,
    count: usize,
    out_buf: *mut c_char,
    out_capacity: usize,
) -> i32 {
    let result = catch_unwind(|| {
        if path.is_null() {
            return -1;
        }
        let path_str = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };
        match strip_leading_components(path_str, count) {
            Some(stripped) => {
                if !out_buf.is_null() && out_capacity > 0 {
                    let bytes = stripped.as_bytes();
                    if bytes.len() + 1 > out_capacity {
                        return -1;
                    }
                    std::ptr::copy_nonoverlapping(
                        bytes.as_ptr() as *const c_char,
                        out_buf,
                        bytes.len(),
                    );
                    *out_buf.add(bytes.len()) = 0;
                }
                0
            }
            None => -1,
        }
    });
    result.unwrap_or(-1)
}

/// Returns true if path is VCS metadata.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_is_vcs_metadata(path: *const c_char) -> bool {
    let result = catch_unwind(|| {
        if path.is_null() {
            return false;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        is_vcs_metadata(s)
    });
    result.unwrap_or(false)
}

/// Returns true if path is macOS junk metadata.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_is_mac_junk_metadata(path: *const c_char) -> bool {
    let result = catch_unwind(|| {
        if path.is_null() {
            return false;
        }
        let s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        is_mac_junk_metadata(s)
    });
    result.unwrap_or(false)
}

/// Glob wildcard pattern matching helper.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_glob_matches(
    pattern: *const c_char,
    path: *const c_char,
    case_sensitive: bool,
) -> bool {
    let result = catch_unwind(|| {
        if pattern.is_null() || path.is_null() {
            return false;
        }
        let pat = match CStr::from_ptr(pattern).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let p = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        glob_matches(pat, p, case_sensitive)
    });
    result.unwrap_or(false)
}
