// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use super::path_sanitizer::*;

#[test]
fn test_basic_path_normalization() {
    let res = sanitize_path("folder//subfolder/./file.txt");
    assert_eq!(res.normalized_path, "folder/subfolder/file.txt");
    assert_eq!(res.win32_formatted_path, "folder\\subfolder\\file.txt");
    assert!(!res.is_absolute);
    assert!(!res.is_unc);
    assert!(!res.has_traversal_attack);
    assert!(res.is_safe());
}

#[test]
fn test_windows_backslash_separators() {
    let res = sanitize_path(r"folder\subfolder\file.txt");
    assert_eq!(res.normalized_path, "folder/subfolder/file.txt");
    assert_eq!(res.win32_formatted_path, r"folder\subfolder\file.txt");
    assert!(!res.is_absolute);
    assert!(!res.has_traversal_attack);
    assert!(res.is_safe());
}

#[test]
fn test_zipslip_traversal_neutralization_and_detection() {
    // Escaping above sandbox root at depth 0
    let res = sanitize_path("safe/../../outside/secret.txt");
    assert_eq!(res.normalized_path, "outside/secret.txt");
    assert!(res.has_traversal_attack);
    assert!(!res.is_safe());

    let res2 = sanitize_path("../../etc/passwd");
    assert_eq!(res2.normalized_path, "etc/passwd");
    assert!(res2.has_traversal_attack);
    assert!(!res2.is_safe());

    let res3 = sanitize_path("a/b/../../c");
    assert_eq!(res3.normalized_path, "c");
    assert!(!res3.has_traversal_attack);
    assert!(res3.is_safe());

    let res4 = sanitize_path("..../evil.exe");
    assert_eq!(res4.normalized_path, "..../evil.exe");
    assert!(!res4.has_traversal_attack);
}

#[test]
fn test_null_byte_rejection() {
    let res = sanitize_path("valid_file.txt\0malicious");
    assert!(res.has_traversal_attack);
    assert!(!res.is_safe());
}

#[test]
fn test_multi_dot_non_traversal_filenames() {
    let res = sanitize_path("release..notes.txt");
    assert_eq!(res.normalized_path, "release..notes.txt");
    assert!(!res.has_traversal_attack);
    assert!(res.is_safe());

    let res2 = sanitize_path("subfolder/file.v1..2.dat");
    assert_eq!(res2.normalized_path, "subfolder/file.v1..2.dat");
    assert!(!res2.has_traversal_attack);
    assert!(res2.is_safe());
}

#[test]
fn test_windows_reserved_device_names() {
    let res_con = sanitize_path("docs/con.txt");
    assert!(res_con.is_windows_reserved);
    assert!(!res_con.is_safe());

    let res_prn = sanitize_path("PRN/report.pdf");
    assert!(res_prn.is_windows_reserved);
    assert!(!res_prn.is_safe());

    let res_aux = sanitize_path("aux");
    assert!(res_aux.is_windows_reserved);
    assert!(!res_aux.is_safe());

    let res_nul = sanitize_path("sub/nul.tar.gz");
    assert!(res_nul.is_windows_reserved);
    assert!(!res_nul.is_safe());

    let res_com1 = sanitize_path("COM1.dat");
    assert!(res_com1.is_windows_reserved);
    assert!(!res_com1.is_safe());

    let res_com0 = sanitize_path("com0");
    assert!(res_com0.is_windows_reserved);
    assert!(!res_com0.is_safe());

    let res_lpt9 = sanitize_path("lpt9");
    assert!(res_lpt9.is_windows_reserved);
    assert!(!res_lpt9.is_safe());

    let res_clock = sanitize_path("clock$");
    assert!(res_clock.is_windows_reserved);
    assert!(!res_clock.is_safe());

    let res_physical = sanitize_path(r"\\.\PhysicalDrive0");
    assert!(res_physical.is_windows_reserved);
    assert!(!res_physical.is_safe());
}

#[test]
fn test_windows_reserved_device_trailing_space_and_dot_variations() {
    let res_con_space = sanitize_path("CON .txt");
    assert!(res_con_space.is_windows_reserved);
    assert!(!res_con_space.is_safe());

    let res_aux_dots = sanitize_path("aux...");
    assert!(res_aux_dots.is_windows_reserved);
    assert!(!res_aux_dots.is_safe());

    let res_com3_spaces = sanitize_path("com3   .dat");
    assert!(res_com3_spaces.is_windows_reserved);
    assert!(!res_com3_spaces.is_safe());
}

#[test]
fn test_non_reserved_legitimate_names() {
    let res_console = sanitize_path("console.txt");
    assert!(!res_console.is_windows_reserved);
    assert!(res_console.is_safe());

    let res_contact = sanitize_path("contact.doc");
    assert!(!res_contact.is_windows_reserved);
    assert!(res_contact.is_safe());

    let res_printer = sanitize_path("printer.pdf");
    assert!(!res_printer.is_windows_reserved);
    assert!(res_printer.is_safe());

    let res_auxiliary = sanitize_path("auxiliary.c");
    assert!(!res_auxiliary.is_windows_reserved);
    assert!(res_auxiliary.is_safe());
}

#[test]
fn test_ntfs_alternate_data_stream_stripping() {
    let res = sanitize_path("invoice.pdf:malicious.exe");
    assert_eq!(res.normalized_path, "invoice.pdf");
    assert_eq!(res.stripped_ads.as_deref(), Some(":malicious.exe"));
    assert!(!res.is_safe());

    let res2 = sanitize_path("file.txt::$DATA");
    assert_eq!(res2.normalized_path, "file.txt");
    assert_eq!(res2.stripped_ads.as_deref(), Some("::$DATA"));
    assert!(!res2.is_safe());

    let res3 = sanitize_path("folder/file.txt:hidden_stream");
    assert_eq!(res3.normalized_path, "folder/file.txt");
    assert_eq!(res3.stripped_ads.as_deref(), Some(":hidden_stream"));
    assert!(!res3.is_safe());
}

#[test]
fn test_windows_drive_letter_preservation() {
    let res = sanitize_path(r"C:\Users\TTZip\archive.zip");
    assert!(res.is_absolute);
    assert_eq!(res.normalized_path, "C:/Users/TTZip/archive.zip");
    assert_eq!(res.win32_formatted_path, r"C:\Users\TTZip\archive.zip");
    assert_eq!(res.stripped_ads, None);
    assert!(!res.is_safe()); // Absolute paths not safe for sandbox extraction
}

#[test]
fn test_windows_unc_path_formatting() {
    let res = sanitize_path(r"\\nas_server\share\backups\data.tar");
    assert!(res.is_unc);
    assert!(res.is_absolute);
    assert_eq!(res.normalized_path, "nas_server/share/backups/data.tar");
    assert_eq!(res.win32_formatted_path, r"\\?\UNC\nas_server\share\backups\data.tar");
    assert!(!res.is_safe());
}

#[test]
fn test_long_path_win32_prefix() {
    let long_subdirs = "subfolder_level_depth/".repeat(20);
    let long_path = format!("C:/{}deep_file.txt", long_subdirs);
    let res = sanitize_path(&long_path);
    assert!(res.is_long_path);
    assert!(res.win32_formatted_path.starts_with(r"\\?\C:\"));
}

#[test]
fn test_unicode_nfc_normalization() {
    // Decomposed NFD 'e' + combining acute accent -> precomposed 'é' (U+00E9)
    let nfd_str = "caf\u{0065}\u{0301}.txt";
    let res = sanitize_path(nfd_str);
    assert_eq!(res.normalized_path, "café.txt");
    assert_eq!(res.normalized_path.chars().count(), 8); // "café.txt" is 8 characters

    // Korean Hangul NFD decomposed -> NFC precomposed
    // ᄀ (U+1100) + ᅡ (U+1161) + ᆨ (U+11A8) -> 각 (U+AC01)
    let hangul_nfd = "\u{1100}\u{1161}\u{11A8}.dat";
    let res_hangul = sanitize_path(hangul_nfd);
    assert_eq!(res_hangul.normalized_path, "각.dat");
}

#[test]
fn test_empty_path() {
    let res = sanitize_path("");
    assert_eq!(res.original_path, "");
    assert_eq!(res.normalized_path, "");
    assert!(!res.is_safe());
}
