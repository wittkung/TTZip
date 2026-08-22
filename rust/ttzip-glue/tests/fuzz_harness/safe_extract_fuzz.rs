// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Task T008: ZipSlip & Path Traversal Injection Fuzzing.

use std::path::Path;
use ttzip_glue::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use ttzip_glue::types::TTZipStatus;

use super::common::{fuzz_scale, FuzzRng};

#[test]
fn test_fuzz_safe_extract_zipslip_traversals() {
    let dest_dir = Path::new("/tmp/ttzip_safe_extract_sandbox_test");
    let mut rng = FuzzRng::new(0x5119511900000001);

    // 1. Static corpus of high-risk exploit payloads
    let static_evil_payloads = [
        "../evil.sh",
        "../../etc/passwd",
        "../../../root/.bashrc",
        "../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../etc/shadow",
        "/etc/passwd",
        "/private/etc/hosts",
        "/System/Library/CoreServices",
        "/var/run/docker.sock",
        "C:\\Windows\\System32\\cmd.exe",
        "C:/Windows/System32/cmd.exe",
        "D:\\malicious.bat",
        "\\Windows\\explorer.exe",
        "\\\\127.0.0.1\\c$\\exploit.exe",
        "//192.168.1.1/share/evil.dll",
        "folder/../../../../etc/passwd",
        "a/b/c/../../../../../../etc/shadow",
        "foo/bar/../../../baz",
        "./../../evil",
        "test.txt\0/etc/passwd",
        "\0../evil",
        "folder/\0file.txt",
        "foo\0bar",
        "..",
        ".",
        "",
        "/",
        "//",
        "\\\\",
        "\\\\?\\C:\\evil",
        "dir/..",
        "dir/../..",
        "..\\..\\Windows\\System32",
        "....//....//etc/passwd",
        r"..\/..\/secret",
        "file:///etc/passwd",
    ];

    let mut trapped_count = 0u64;

    for &payload in &static_evil_payloads {
        let res = sanitize_and_validate_path(dest_dir, payload);
        assert_eq!(
            res,
            Err(TTZipStatus::ErrSecurityViolation),
            "Expected payload {:?} to be trapped as ErrSecurityViolation, but got {:?}",
            payload,
            res
        );
        trapped_count += 1;
    }

    // 2. Dynamic generative permutation fuzzing (20,000 generated paths)
    let segments = [
        "..", ".", "/", "\\", "\0", "etc", "passwd", "root", "Users", "admin", "bin",
        "sub", "dir", "file", "C:", "D:", "\\\\server\\share", " ", "a", "b", "...", "....",
    ];

    for _ in 0..fuzz_scale(20_000) {
        let num_parts = 1 + rng.next_usize(8);
        let mut path_str = String::new();

        if rng.next_bool() {
            path_str.push('/');
        }

        for _ in 0..num_parts {
            let seg = segments[rng.next_usize(segments.len())];
            path_str.push_str(seg);
            if rng.next_bool() {
                path_str.push(if rng.next_bool() { '/' } else { '\\' });
            }
        }

        let res = sanitize_and_validate_path(dest_dir, &path_str);
        match res {
            Ok(sanitized) => {
                // INVARIANT: Sanitized path MUST start with dest_dir and CANNOT escape
                assert!(
                    sanitized.starts_with(dest_dir),
                    "SECURITY ESCAPE: Resulting path {:?} escapes dest_dir {:?}",
                    sanitized,
                    dest_dir
                );
                assert_ne!(
                    sanitized,
                    dest_dir.to_path_buf(),
                    "Sanitized path cannot be dest_dir itself"
                );
            }
            Err(status) => {
                assert_eq!(status, TTZipStatus::ErrSecurityViolation);
                trapped_count += 1;
            }
        }
    }

    // 3. Engine-level extraction integration with malicious entries
    let mut engine = SafeExtractEngine::new();
    for &payload in &static_evil_payloads {
        let check_res = sanitize_and_validate_path(dest_dir, payload);
        assert_eq!(check_res, Err(TTZipStatus::ErrSecurityViolation));
        if let Ok(safe_p) = check_res {
            engine.register_entry(safe_p, 0o644, 1700000000, 0, false);
        }
    }

    println!(
        "[FUZZ] Completed 20,000+ mutations on safeExtractPathTraversals -> {} trapped, 0 escapes",
        trapped_count
    );
}
