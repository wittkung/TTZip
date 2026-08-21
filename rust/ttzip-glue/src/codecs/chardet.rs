// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Universal Character Set Detection Codec.
//!
//! Provides automated charset detection for legacy archives (GB18030, Shift-JIS, Big5, EUC-KR, Windows-1252, etc.).

use crate::charset::detect_charset as native_detect_charset;
use crate::types::TTZipStatus;

/// Pure Safe Rust Universal Charset Detector.
#[derive(Debug, Default)]
pub struct CharsetDetector {
    buffer: Vec<u8>,
}

impl CharsetDetector {
    /// Creates a new character set detector instance.
    pub fn new() -> Result<Self, TTZipStatus> {
        Ok(Self {
            buffer: Vec::with_capacity(1024),
        })
    }

    /// Feeds arbitrary binary or text data into the detector.
    pub fn handle_data(&mut self, data: &[u8]) -> Result<(), TTZipStatus> {
        self.buffer.extend_from_slice(data);
        Ok(())
    }

    /// Notifies the detector of the end of input stream.
    pub fn data_end(&mut self) {}

    /// Resets the detector state for another stream.
    pub fn reset(&mut self) {
        self.buffer.clear();
    }

    /// Retrieves detected character encoding name, or None if undetermined.
    pub fn detected_charset(&self) -> Option<String> {
        native_detect_charset(&self.buffer)
    }
}

/// One-shot detection helper for raw byte buffers.
pub fn detect_charset(data: &[u8]) -> Option<String> {
    native_detect_charset(data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_utf8_detection() {
        let utf8_text = "这是 TTZip 原生字符集探测测试，包含中文与 Emoji 🚀".as_bytes();
        let detected = detect_charset(utf8_text);
        assert!(detected.is_some());
        let name = detected.unwrap().to_uppercase();
        assert!(name.contains("UTF-8") || name.contains("UTF8"));
    }

    #[test]
    fn test_detector_reuse_with_reset() {
        let mut detector = CharsetDetector::new().expect("create detector");

        let text1 = "Hello world UTF-8 text".as_bytes();
        detector.handle_data(text1).unwrap();
        detector.data_end();
        let _ = detector.detected_charset();

        detector.reset();

        let text2 = "另一段中文测试数据，用于测试 reset 状态机重用".as_bytes();
        detector.handle_data(text2).unwrap();
        detector.data_end();
        let detected2 = detector.detected_charset();
        assert!(detected2.is_some());
    }
}
