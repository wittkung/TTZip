// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper for Mozilla `uchardet` universal character encoding detector.
//!
//! Provides automated charset detection for legacy archives (GB18030, Shift-JIS, Big5, EUC-KR, Windows-1252, etc.).

use crate::types::TTZipStatus;
use std::ffi::CStr;
use std::ptr::NonNull;

enum UchardetOpaque {}

extern "C" {
    fn uchardet_new() -> *mut UchardetOpaque;
    fn uchardet_delete(ud: *mut UchardetOpaque);
    fn uchardet_handle_data(
        ud: *mut UchardetOpaque,
        data: *const libc::c_char,
        len: libc::size_t,
    ) -> libc::c_int;
    fn uchardet_data_end(ud: *mut UchardetOpaque);
    fn uchardet_reset(ud: *mut UchardetOpaque);
    fn uchardet_get_charset(ud: *mut UchardetOpaque) -> *const libc::c_char;
}

/// Safe RAII wrapper around Mozilla `uchardet` detector handle.
pub struct CharsetDetector {
    handle: NonNull<UchardetOpaque>,
}

unsafe impl Send for CharsetDetector {}

impl CharsetDetector {
    /// Creates a new character set detector instance.
    pub fn new() -> Result<Self, TTZipStatus> {
        let ptr = unsafe { uchardet_new() };
        let handle = NonNull::new(ptr).ok_or(TTZipStatus::ErrOutOfMemory)?;
        Ok(Self { handle })
    }

    /// Feeds arbitrary binary or text data into the detector.
    pub fn handle_data(&mut self, data: &[u8]) -> Result<(), TTZipStatus> {
        if data.is_empty() {
            return Ok(());
        }
        let res = unsafe {
            uchardet_handle_data(
                self.handle.as_ptr(),
                data.as_ptr() as *const libc::c_char,
                data.len(),
            )
        };
        if res != 0 {
            Err(TTZipStatus::ErrExtractionFailed)
        } else {
            Ok(())
        }
    }

    /// Notifies the detector of the end of input stream.
    pub fn data_end(&mut self) {
        unsafe {
            uchardet_data_end(self.handle.as_ptr());
        }
    }

    /// Resets the detector state for another stream.
    pub fn reset(&mut self) {
        unsafe {
            uchardet_reset(self.handle.as_ptr());
        }
    }

    /// Retrieves detected iconv-compatible character encoding name, or None if undetermined.
    pub fn detected_charset(&self) -> Option<String> {
        let ptr = unsafe { uchardet_get_charset(self.handle.as_ptr()) };
        if ptr.is_null() {
            return None;
        }
        let c_str = unsafe { CStr::from_ptr(ptr) };
        let s = c_str.to_string_lossy();
        if s.is_empty() {
            None
        } else {
            Some(s.into_owned())
        }
    }
}

impl Drop for CharsetDetector {
    fn drop(&mut self) {
        unsafe {
            uchardet_delete(self.handle.as_ptr());
        }
    }
}

/// One-shot detection helper for raw byte buffers.
pub fn detect_charset(data: &[u8]) -> Option<String> {
    if data.is_empty() {
        return None;
    }
    let mut detector = CharsetDetector::new().ok()?;
    detector.handle_data(data).ok()?;
    detector.data_end();
    detector.detected_charset()
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
