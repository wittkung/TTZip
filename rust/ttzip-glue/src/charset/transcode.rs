// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-allocation slice transcoder and filename sanitizer powered by `encoding_rs`.

use crate::charset::detector::detect_charset;
use crate::types::TTZipStatus;
use encoding_rs::Encoding;

/// Maps standard charset label to `encoding_rs` Encoding instance.
pub fn lookup_encoding(charset: &str) -> &'static Encoding {
    let lower = charset.to_ascii_lowercase();
    match lower.as_str() {
        "utf-8" | "utf8" | "ascii" => encoding_rs::UTF_8,
        "gb18030" | "gbk" | "gb2312" | "cp936" => encoding_rs::GB18030,
        "shift_jis" | "shift-jis" | "sjis" | "cp932" | "windows-31j" => encoding_rs::SHIFT_JIS,
        "big5" | "cp950" | "big5-hkscs" => encoding_rs::BIG5,
        "euc-kr" | "cp949" | "korean" => encoding_rs::EUC_KR,
        "windows-1252" | "cp1252" | "iso-8859-1" | "latin1" => encoding_rs::WINDOWS_1252,
        other => Encoding::for_label(other.as_bytes()).unwrap_or(encoding_rs::UTF_8),
    }
}

/// Transcodes raw byte sequence to UTF-8 String given character set encoding name.
pub fn transcode_to_utf8(data: &[u8], charset_name: &str) -> Result<String, TTZipStatus> {
    if data.is_empty() {
        return Ok(String::new());
    }
    let encoding = lookup_encoding(charset_name);
    let (cow, _, _had_errors) = encoding.decode(data);
    Ok(cow.into_owned())
}

/// Sanitizes raw filename byte sequence into destination slice buffer with null termination.
///
/// Returns the number of valid UTF-8 bytes written (excluding trailing null byte).
pub fn sanitize_filename_to_slice(data: &[u8], out_buf: &mut [u8]) -> Result<usize, TTZipStatus> {
    if out_buf.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }
    if data.is_empty() {
        out_buf[0] = 0;
        return Ok(0);
    }

    // 1. Fast path: If already valid ASCII or UTF-8
    if data.is_ascii() || std::str::from_utf8(data).is_ok() {
        if data.len() + 1 > out_buf.len() {
            return Err(TTZipStatus::ErrPathTooLong);
        }
        out_buf[..data.len()].copy_from_slice(data);
        out_buf[data.len()] = 0;
        return Ok(data.len());
    }

    // 2. Sniff charset and transcode
    let detected = detect_charset(data).unwrap_or_else(|| "UTF-8".to_string());
    let encoding = lookup_encoding(&detected);

    let mut decoder = encoding.new_decoder();
    let max_needed = decoder
        .max_utf8_buffer_length(data.len())
        .unwrap_or(data.len() * 4);

    if max_needed < out_buf.len() {
        // Direct zero-allocation decode into target buffer
        let cap = out_buf.len() - 1;
        let buf_slice = &mut out_buf[..cap];
        let (_result, _read, written, _had_errors) =
            decoder.decode_to_utf8(data, buf_slice, true);
        out_buf[written] = 0;
        Ok(written)
    } else {
        // Safe intermediate decode if output buffer is bounded
        let (cow, _, _) = encoding.decode(data);
        let utf8_bytes = cow.as_bytes();
        if utf8_bytes.len() + 1 > out_buf.len() {
            return Err(TTZipStatus::ErrPathTooLong);
        }
        out_buf[..utf8_bytes.len()].copy_from_slice(utf8_bytes);
        out_buf[utf8_bytes.len()] = 0;
        Ok(utf8_bytes.len())
    }
}

/// Convenience helper to sanitize raw filename bytes to a safe UTF-8 String.
pub fn sanitize_filename(data: &[u8]) -> String {
    if data.is_empty() {
        return String::new();
    }
    if let Ok(s) = std::str::from_utf8(data) {
        return s.to_string();
    }
    let detected = detect_charset(data).unwrap_or_else(|| "UTF-8".to_string());
    transcode_to_utf8(data, &detected).unwrap_or_else(|_| String::from_utf8_lossy(data).into_owned())
}
