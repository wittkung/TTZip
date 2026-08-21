// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use std::ffi::CString;
use ttzip_glue::ffi::filter_ffi::*;

#[test]
fn test_dsl_filter_ffi_lifecycle_and_evaluation() {
    let query = CString::new("ext:swift,rs AND size:>1000").unwrap();
    let handle = unsafe { ttzip_rust_dsl_filter_new(query.as_ptr()) };
    assert!(!handle.is_null());

    let path_valid = CString::new("Sources/Main.swift").unwrap();
    let res1 = unsafe { ttzip_rust_dsl_filter_evaluate(handle, path_valid.as_ptr(), 2048, 1000) };
    assert!(res1);

    let res2 = unsafe { ttzip_rust_dsl_filter_evaluate(handle, path_valid.as_ptr(), 500, 1000) };
    assert!(!res2);

    let path_invalid_ext = CString::new("Images/photo.png").unwrap();
    let res3 = unsafe { ttzip_rust_dsl_filter_evaluate(handle, path_invalid_ext.as_ptr(), 2048, 1000) };
    assert!(!res3);

    unsafe { ttzip_rust_dsl_filter_free(handle) };
}

#[test]
fn test_dsl_filter_oneshot_ffi() {
    let query = CString::new("name:*.txt OR size:<500").unwrap();
    let path1 = CString::new("readme.txt").unwrap();
    let path2 = CString::new("video.mp4").unwrap();

    let res1 = unsafe { ttzip_rust_dsl_evaluate_oneshot(query.as_ptr(), path1.as_ptr(), 10000, 0) };
    assert!(res1);

    let res2 = unsafe { ttzip_rust_dsl_evaluate_oneshot(query.as_ptr(), path2.as_ptr(), 100, 0) };
    assert!(res2);

    let res3 = unsafe { ttzip_rust_dsl_evaluate_oneshot(query.as_ptr(), path2.as_ptr(), 10000, 0) };
    assert!(!res3);
}

#[test]
fn test_path_pattern_filter_ffi() {
    let inc1 = CString::new("*.swift").unwrap();
    let inc2 = CString::new("src/**").unwrap();
    let inc_ptrs = [inc1.as_ptr(), inc2.as_ptr()];

    let exc1 = CString::new("*.tmp").unwrap();
    let exc_ptrs = [exc1.as_ptr()];

    let handle = unsafe {
        ttzip_rust_path_filter_new(
            inc_ptrs.as_ptr(),
            inc_ptrs.len(),
            exc_ptrs.as_ptr(),
            exc_ptrs.len(),
            true,
            true,
        )
    };
    assert!(!handle.is_null());

    let p1 = CString::new("src/main.swift").unwrap();
    let p2 = CString::new("build/out.tmp").unwrap();
    let p3 = CString::new(".git/HEAD").unwrap();
    let p4 = CString::new(".DS_Store").unwrap();

    assert!(unsafe { ttzip_rust_path_filter_should_include(handle, p1.as_ptr()) });
    assert!(!unsafe { ttzip_rust_path_filter_should_include(handle, p2.as_ptr()) });
    assert!(!unsafe { ttzip_rust_path_filter_should_include(handle, p3.as_ptr()) });
    assert!(!unsafe { ttzip_rust_path_filter_should_include(handle, p4.as_ptr()) });

    unsafe { ttzip_rust_path_filter_free(handle) };
}

#[test]
fn test_strip_leading_components_ffi() {
    let path = CString::new("/var/log/app.log").unwrap();
    let mut out_buf = [0i8; 256];

    let status = unsafe {
        ttzip_rust_strip_leading_components(path.as_ptr(), 2, out_buf.as_mut_ptr(), out_buf.len())
    };
    assert_eq!(status, 0);

    let out_str = unsafe { std::ffi::CStr::from_ptr(out_buf.as_ptr()) }
        .to_str()
        .unwrap();
    assert_eq!(out_str, "app.log");
}

#[test]
fn test_metadata_helpers_and_glob_ffi() {
    let git_path = CString::new(".git/config").unwrap();
    assert!(unsafe { ttzip_rust_is_vcs_metadata(git_path.as_ptr()) });

    let ds_path = CString::new("folder/.DS_Store").unwrap();
    assert!(unsafe { ttzip_rust_is_mac_junk_metadata(ds_path.as_ptr()) });

    let pat = CString::new("*.rs").unwrap();
    let target = CString::new("src/main.rs").unwrap();
    assert!(unsafe { ttzip_rust_glob_matches(pat.as_ptr(), target.as_ptr(), true) });
}
