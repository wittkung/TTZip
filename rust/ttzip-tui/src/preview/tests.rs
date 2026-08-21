// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unit tests for in-terminal stream preview and hex dump engine.

use super::*;

#[test]
fn test_syntax_language_detection() {
    let highlighter = SyntaxHighlighter::new();

    assert_eq!(highlighter.detect_language("src/main.rs"), "Rust");
    assert_eq!(highlighter.detect_language("config.json"), "JSON");
    assert_eq!(highlighter.detect_language("README.md"), "Markdown");
    assert_eq!(highlighter.detect_language("Cargo.toml"), "TOML");
    assert_eq!(highlighter.detect_language("native.c"), "C");
    assert_eq!(highlighter.detect_language("App.swift"), "Swift");
    assert_eq!(highlighter.detect_language("unknown.xyz123"), "Plain Text");
}

#[test]
fn test_is_text_content_heuristic() {
    let plain_text = b"Hello world! This is a clean text file with \n and \t.";
    assert!(is_text_content(plain_text));

    let binary_with_null = b"PNG\r\n\x1a\n\x00\x00\x00\rIHDR";
    assert!(!is_text_content(binary_with_null));

    let random_binary: Vec<u8> = (0..=255).collect();
    assert!(!is_text_content(&random_binary));

    let empty = b"";
    assert!(is_text_content(empty));
}

#[test]
fn test_text_preview_generation_and_ansi() {
    let highlighter = SyntaxHighlighter::new();
    let code = b"fn main() {\n    println!(\"Hello TTZip!\");\n}\n";

    let preview = generate_preview("main.rs", code, code.len() as u64, &highlighter);

    match preview {
        PreviewData::Text {
            lines,
            syntax_language,
            is_truncated,
        } => {
            assert_eq!(syntax_language, "Rust");
            assert_eq!(lines.len(), 3);
            assert!(!is_truncated);
            assert!(lines[0].contains("fn"));
        }
        _ => panic!("Expected PreviewData::Text"),
    }
}

#[test]
fn test_hex_dump_formatting_and_alignment() {
    let sample = b"0123456789ABCDEFHello World!";
    let preview = format_hex_dump(sample);

    match preview {
        PreviewData::HexDump {
            offset_hex_pairs,
            total_bytes_displayed,
        } => {
            assert_eq!(total_bytes_displayed, sample.len());
            assert_eq!(offset_hex_pairs.len(), 2);

            // First row (16 bytes: "0123456789ABCDEF")
            let (off0, hex0, asc0) = &offset_hex_pairs[0];
            assert_eq!(off0, "00000000");
            assert_eq!(hex0, "30 31 32 33 34 35 36 37  38 39 41 42 43 44 45 46");
            assert_eq!(asc0, "0123456789ABCDEF");

            // Second row (12 bytes: "Hello World!")
            let (off1, hex1, asc1) = &offset_hex_pairs[1];
            assert_eq!(off1, "00000010");
            assert!(hex1.starts_with("48 65 6c 6c 6f 20 57 6f  72 6c 64 21"));
            assert_eq!(asc1, "Hello World!");
        }
        _ => panic!("Expected PreviewData::HexDump"),
    }
}

#[test]
fn test_truncation_protection_on_large_data() {
    let highlighter = SyntaxHighlighter::new();
    // Create 200 KB synthetic text
    let large_text = "let x = 42;\n".repeat(20000);
    let large_bytes = large_text.as_bytes();
    assert!(large_bytes.len() > MAX_PREVIEW_BYTES);

    let preview = generate_preview("large.rs", large_bytes, large_bytes.len() as u64, &highlighter);

    match preview {
        PreviewData::Text {
            lines,
            is_truncated,
            ..
        } => {
            assert!(is_truncated);
            assert!(!lines.is_empty());
        }
        _ => panic!("Expected PreviewData::Text"),
    }

    // Test large binary
    let large_binary = vec![0xABu8; 500 * 1024];
    let hex_preview = generate_preview("firmware.bin", &large_binary, large_binary.len() as u64, &highlighter);

    match hex_preview {
        PreviewData::HexDump {
            offset_hex_pairs,
            total_bytes_displayed,
        } => {
            assert_eq!(total_bytes_displayed, MAX_PREVIEW_BYTES);
            assert_eq!(offset_hex_pairs.len(), MAX_PREVIEW_BYTES / 16);
        }
        _ => panic!("Expected PreviewData::HexDump"),
    }
}

#[test]
fn test_empty_file_preview() {
    let preview = generate_preview_auto("empty.txt", b"", 0);

    match preview {
        PreviewData::Text {
            lines,
            syntax_language,
            is_truncated,
        } => {
            assert_eq!(lines, vec!["[Empty file]"]);
            assert_eq!(syntax_language, "Plain Text");
            assert!(!is_truncated);
        }
        _ => panic!("Expected PreviewData::Text"),
    }
}
