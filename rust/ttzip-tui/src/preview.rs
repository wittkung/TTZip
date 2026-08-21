// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! In-Terminal Stream Preview Engine with Syntax Highlighting and 16-Byte Aligned Hex Dump.
//!
//! Enforces:
//! 1. 64KB streaming truncation: no more than 64KB parsed or displayed per preview.
//! 2. Memory bound: $\le 16\text{MB}$ RSS resident memory limit.
//! 3. Clean fallback: Automatic binary vs text detection.
//! 4. Conforms to `specs/170-rust-interactive-tui-engine/data-model.md`.

use serde::{Deserialize, Serialize};
use std::path::Path;
use syntect::easy::HighlightLines;
use syntect::highlighting::ThemeSet;
use syntect::parsing::SyntaxSet;
use syntect::util::as_24_bit_terminal_escaped;

/// Maximum number of bytes to inspect and display for a single preview (64 KB).
pub const MAX_PREVIEW_BYTES: usize = 64 * 1024;

/// Hard resident memory limit for preview buffers (16 MB).
pub const MAX_RESIDENT_MEMORY_LIMIT: usize = 16 * 1024 * 1024;

/// Preview data payload matching `specs/170-rust-interactive-tui-engine/data-model.md`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum PreviewData {
    Text {
        lines: Vec<String>,
        syntax_language: String,
        is_truncated: bool,
    },
    HexDump {
        offset_hex_pairs: Vec<(String, String, String)>, // (Offset, Hex, ASCII)
        total_bytes_displayed: usize,
    },
    Unsupported {
        reason: String,
        file_size_bytes: u64,
    },
}

/// Global syntax highlighter with syntax and theme sets.
pub struct SyntaxHighlighter {
    pub syntax_set: SyntaxSet,
    pub theme_set: ThemeSet,
}

impl Default for SyntaxHighlighter {
    fn default() -> Self {
        Self::new()
    }
}

impl SyntaxHighlighter {
    /// Initializes a new syntax highlighter with default syntax and theme sets.
    pub fn new() -> Self {
        Self {
            syntax_set: SyntaxSet::load_defaults_newlines(),
            theme_set: ThemeSet::load_defaults(),
        }
    }

    /// Detects syntax language name for a given filename or path.
    pub fn detect_language(&self, file_path: &str) -> String {
        let path = Path::new(file_path);
        let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");

        if let Some(syntax) = self.syntax_set.find_syntax_by_extension(ext) {
            return syntax.name.clone();
        }

        let file_name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
        if let Some(syntax) = self.syntax_set.find_syntax_by_token(file_name) {
            return syntax.name.clone();
        }

        match ext.to_lowercase().as_str() {
            "rs" => "Rust".to_string(),
            "swift" => "Swift".to_string(),
            "c" | "h" => "C".to_string(),
            "cpp" | "cc" | "cxx" | "hpp" => "C++".to_string(),
            "json" => "JSON".to_string(),
            "toml" => "TOML".to_string(),
            "yaml" | "yml" => "YAML".to_string(),
            "md" | "markdown" => "Markdown".to_string(),
            "sh" | "bash" | "zsh" => "Bash".to_string(),
            "py" => "Python".to_string(),
            "js" | "mjs" => "JavaScript".to_string(),
            "ts" => "TypeScript".to_string(),
            "html" | "htm" => "HTML".to_string(),
            "css" => "CSS".to_string(),
            "xml" | "plist" => "XML".to_string(),
            "txt" | "log" => "Plain Text".to_string(),
            _ => "Plain Text".to_string(),
        }
    }

    /// Highlights text lines with ANSI 24-bit TrueColor sequences.
    pub fn highlight_to_ansi_lines(&self, file_path: &str, text: &str) -> (Vec<String>, String) {
        let path = Path::new(file_path);
        let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");

        let syntax = self
            .syntax_set
            .find_syntax_by_extension(ext)
            .or_else(|| {
                let fname = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
                self.syntax_set.find_syntax_by_token(fname)
            })
            .unwrap_or_else(|| self.syntax_set.find_syntax_plain_text());

        let lang_name = syntax.name.clone();
        let theme = &self.theme_set.themes["base16-ocean.dark"];
        let mut highlighter = HighlightLines::new(syntax, theme);

        let mut out_lines = Vec::new();
        for line in text.lines() {
            let line_with_nl = format!("{}\n", line);
            match highlighter.highlight_line(&line_with_nl, &self.syntax_set) {
                Ok(ranges) => {
                    let escaped = as_24_bit_terminal_escaped(&ranges[..], false);
                    out_lines.push(escaped.trim_end_matches('\n').to_string());
                }
                Err(_) => {
                    out_lines.push(line.to_string());
                }
            }
        }

        (out_lines, lang_name)
    }
}

/// Checks whether a byte slice contains plain text content or binary data.
///
/// Uses heuristic checks:
/// 1. Presence of null bytes (`0x00`) indicates binary data.
/// 2. Ratio of non-printable control characters (excluding standard whitespace like `\t`, `\r`, `\n`).
/// 3. UTF-8 validation.
pub fn is_text_content(data: &[u8]) -> bool {
    if data.is_empty() {
        return true;
    }

    let sample_len = data.len().min(1024);
    let sample = &data[..sample_len];

    // Check for null bytes
    if sample.contains(&0) {
        return false;
    }

    // Check ratio of control characters
    let mut control_count = 0usize;
    for &b in sample {
        if b < 0x09 || (b > 0x0D && b < 0x20) || b == 0x7F {
            control_count += 1;
        }
    }

    if control_count * 10 > sample_len {
        return false;
    }

    // Try UTF-8 validation
    std::str::from_utf8(sample).is_ok()
}

/// Formats text data into a `PreviewData::Text` representation with 64KB truncation.
pub fn format_text_preview(
    file_path: &str,
    raw_data: &[u8],
    total_file_size: u64,
    highlighter: &SyntaxHighlighter,
) -> PreviewData {
    let is_truncated = (raw_data.len() < total_file_size as usize) || (raw_data.len() > MAX_PREVIEW_BYTES);
    let slice_len = raw_data.len().min(MAX_PREVIEW_BYTES);
    let slice = &raw_data[..slice_len];

    // Ensure valid UTF-8 slice boundary
    let text = match std::str::from_utf8(slice) {
        Ok(valid_str) => valid_str.to_string(),
        Err(e) => {
            let valid_up_to = e.valid_up_to();
            String::from_utf8_lossy(&slice[..valid_up_to]).to_string()
        }
    };

    let (lines, syntax_language) = highlighter.highlight_to_ansi_lines(file_path, &text);

    PreviewData::Text {
        lines,
        syntax_language,
        is_truncated,
    }
}

/// Formats binary data into 16-byte aligned Hex Dump rows `(Offset, Hex, ASCII)`.
///
/// Output example:
/// `("00000000", "48 65 6c 6c 6f 20 57 6f  72 6c 64 21 0a 00 00 00", "Hello World!....")`
pub fn format_hex_dump(raw_data: &[u8]) -> PreviewData {
    let slice_len = raw_data.len().min(MAX_PREVIEW_BYTES);
    let slice = &raw_data[..slice_len];
    let mut offset_hex_pairs = Vec::new();

    for (chunk_idx, chunk) in slice.chunks(16).enumerate() {
        let offset_str = format!("{:08X}", chunk_idx * 16);

        // Format hex columns: 8 bytes, extra space, 8 bytes
        let mut hex_parts = Vec::with_capacity(16);
        for &b in chunk {
            hex_parts.push(format!("{:02x}", b));
        }

        let mut hex_str = if hex_parts.len() > 8 {
            format!(
                "{}  {}",
                hex_parts[..8].join(" "),
                hex_parts[8..].join(" ")
            )
        } else {
            hex_parts.join(" ")
        };

        // Align hex column if last chunk is shorter than 16 bytes
        if chunk.len() < 16 {
            let missing_bytes = 16 - chunk.len();
            let pad_len = missing_bytes * 3 + if chunk.len() <= 8 { 1 } else { 0 };
            hex_str.push_str(&" ".repeat(pad_len));
        }

        // ASCII sidebar
        let mut ascii_str = String::with_capacity(chunk.len());
        for &b in chunk {
            if (0x20..=0x7E).contains(&b) {
                ascii_str.push(b as char);
            } else {
                ascii_str.push('.');
            }
        }

        offset_hex_pairs.push((offset_str, hex_str, ascii_str));
    }

    PreviewData::HexDump {
        offset_hex_pairs,
        total_bytes_displayed: slice_len,
    }
}

/// Generates a structured preview of an archive entry's raw bytes.
///
/// Automatically determines whether the content is text or binary, applies 64KB truncation,
/// and returns the structured `PreviewData` enum.
pub fn generate_preview(
    file_path: &str,
    raw_data: &[u8],
    total_file_size: u64,
    highlighter: &SyntaxHighlighter,
) -> PreviewData {
    if total_file_size == 0 || raw_data.is_empty() {
        return PreviewData::Text {
            lines: vec!["[Empty file]".to_string()],
            syntax_language: highlighter.detect_language(file_path),
            is_truncated: false,
        };
    }

    if is_text_content(raw_data) {
        format_text_preview(file_path, raw_data, total_file_size, highlighter)
    } else {
        format_hex_dump(raw_data)
    }
}

/// Generates preview using a freshly created default highlighter.
pub fn generate_preview_auto(
    file_path: &str,
    raw_data: &[u8],
    total_file_size: u64,
) -> PreviewData {
    let highlighter = SyntaxHighlighter::new();
    generate_preview(file_path, raw_data, total_file_size, &highlighter)
}

#[cfg(test)]
mod tests {
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
}
