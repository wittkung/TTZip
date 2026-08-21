// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#[cfg(test)]
mod tests {
    use crate::charset::{
        detect_charset, detect_charset_with_confidence, sanitize_filename,
        sanitize_filename_to_slice, transcode_to_utf8, ttzip_rust_detect_charset,
        ttzip_rust_sanitize_filename,
    };
    use crate::types::TTZipStatus;
    use std::ffi::CStr;

    #[test]
    fn test_ascii_fast_path() {
        let ascii_str = "hello_world_2026.zip";
        let (name, conf) = detect_charset_with_confidence(ascii_str.as_bytes());
        assert_eq!(name, "ASCII");
        assert_eq!(conf, 1.0);

        let sanitized = sanitize_filename(ascii_str.as_bytes());
        assert_eq!(sanitized, ascii_str);
    }

    #[test]
    fn test_utf8_detection_and_transcode() {
        let text = "你好，世界！这是一段包含中文、Emoji 🚀 和特殊字符的 UTF-8 测试。";
        let bytes = text.as_bytes();
        let detected = detect_charset(bytes);
        assert_eq!(detected.as_deref(), Some("UTF-8"));

        let sanitized = sanitize_filename(bytes);
        assert_eq!(sanitized, text);
    }

    #[test]
    fn test_simplified_chinese_gb18030() {
        let text = "你好测试文件资料包.txt";
        let (encoded_bytes, _, _) = encoding_rs::GB18030.encode(text);

        let detected = detect_charset(&encoded_bytes);
        assert!(
            detected.as_deref() == Some("GB18030") || detected.as_deref() == Some("GBK"),
            "Expected GB18030/GBK, got {:?}",
            detected
        );

        let sanitized = sanitize_filename(&encoded_bytes);
        assert_eq!(sanitized, text);

        let transcoded = transcode_to_utf8(&encoded_bytes, "GB18030").unwrap();
        assert_eq!(transcoded, text);
    }

    #[test]
    fn test_traditional_chinese_big5() {
        let text = "測試繁體中文檔案說明.txt";
        let (encoded_bytes, _, _) = encoding_rs::BIG5.encode(text);

        let detected = detect_charset(&encoded_bytes);
        assert_eq!(detected.as_deref(), Some("Big5"));

        let sanitized = sanitize_filename(&encoded_bytes);
        assert_eq!(sanitized, text);

        let transcoded = transcode_to_utf8(&encoded_bytes, "Big5").unwrap();
        assert_eq!(transcoded, text);
    }

    #[test]
    fn test_japanese_shift_jis() {
        let text = "日本語テストファイル作成.zip";
        let (encoded_bytes, _, _) = encoding_rs::SHIFT_JIS.encode(text);

        let detected = detect_charset(&encoded_bytes);
        assert_eq!(detected.as_deref(), Some("Shift_JIS"));

        let sanitized = sanitize_filename(&encoded_bytes);
        assert_eq!(sanitized, text);

        let transcoded = transcode_to_utf8(&encoded_bytes, "Shift_JIS").unwrap();
        assert_eq!(transcoded, text);
    }

    #[test]
    fn test_korean_euc_kr() {
        let text = "한국어테스트문서파일.txt";
        let (encoded_bytes, _, _) = encoding_rs::EUC_KR.encode(text);

        let detected = detect_charset(&encoded_bytes);
        assert_eq!(detected.as_deref(), Some("EUC-KR"));

        let sanitized = sanitize_filename(&encoded_bytes);
        assert_eq!(sanitized, text);

        let transcoded = transcode_to_utf8(&encoded_bytes, "EUC-KR").unwrap();
        assert_eq!(transcoded, text);
    }

    #[test]
    fn test_windows_1252_latin() {
        let text = "Café_München_résumé.pdf";
        let (encoded_bytes, _, _) = encoding_rs::WINDOWS_1252.encode(text);

        let sanitized = sanitize_filename(&encoded_bytes);
        assert_eq!(sanitized, text);
    }

    #[test]
    fn test_sanitize_filename_to_slice_buffer() {
        let text = "重要会议纪要.docx";
        let (encoded, _, _) = encoding_rs::GB18030.encode(text);

        let mut out_buf = [0u8; 128];
        let written = sanitize_filename_to_slice(&encoded, &mut out_buf).unwrap();
        let decoded = std::str::from_utf8(&out_buf[..written]).unwrap();
        assert_eq!(decoded, text);
        assert_eq!(out_buf[written], 0);

        // Small buffer test
        let mut small_buf = [0u8; 4];
        let err = sanitize_filename_to_slice(&encoded, &mut small_buf);
        assert_eq!(err, Err(TTZipStatus::ErrPathTooLong));
    }

    #[test]
    fn test_ffi_detect_and_sanitize() {
        let text = "日本語のドキュメント.txt";
        let (encoded, _, _) = encoding_rs::SHIFT_JIS.encode(text);

        // 1. Detect FFI
        let mut name_buf = [0i8; 64];
        let status = ttzip_rust_detect_charset(
            encoded.as_ptr(),
            encoded.len(),
            name_buf.as_mut_ptr(),
            name_buf.len(),
        );
        assert_eq!(status, TTZipStatus::Ok);
        let c_name = unsafe { CStr::from_ptr(name_buf.as_ptr()) }.to_str().unwrap();
        assert_eq!(c_name, "Shift_JIS");

        // 2. Sanitize FFI
        let mut sanitized_buf = [0i8; 128];
        let mut out_len: usize = 0;
        let s_status = ttzip_rust_sanitize_filename(
            encoded.as_ptr(),
            encoded.len(),
            sanitized_buf.as_mut_ptr(),
            sanitized_buf.len(),
            &mut out_len,
        );
        assert_eq!(s_status, TTZipStatus::Ok);
        let res_str = unsafe { CStr::from_ptr(sanitized_buf.as_ptr()) }.to_str().unwrap();
        assert_eq!(res_str, text);
        assert_eq!(out_len, text.len());
    }

    #[test]
    fn test_empty_and_null_ffi() {
        let mut buf = [0i8; 32];
        let mut out_len = 999;
        let s = ttzip_rust_sanitize_filename(
            std::ptr::null(),
            0,
            buf.as_mut_ptr(),
            buf.len(),
            &mut out_len,
        );
        assert_eq!(s, TTZipStatus::Ok);
        assert_eq!(buf[0], 0);
        assert_eq!(out_len, 0);

        let err = ttzip_rust_sanitize_filename(
            std::ptr::null(),
            10,
            buf.as_mut_ptr(),
            buf.len(),
            &mut out_len,
        );
        assert_eq!(err, TTZipStatus::ErrInvalidParam);
    }
}
