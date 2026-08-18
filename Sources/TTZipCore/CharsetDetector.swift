// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Character encoding detection and filename sanitization interface.
public enum CharsetDetector {
    /// Detects charset encoding name (e.g. GB18030, UTF-8, Shift-JIS) from raw byte sequence.
    public static func detectCharset(data: Data) -> String {
        return CharsetDetectionStrategyContext.shared.detectCharset(data: data)
    }
    
    /// Sanitizes raw filename byte sequences into valid Unicode Swift String.
    public static func sanitizeFilename(bytes: Data) -> String {
        return CharsetDetectionStrategyContext.shared.sanitizeFilename(bytes: bytes)
    }
    
    /// Clears charset detection LRU caching structures.
    public static func clearCache() {
        CharsetDetectionStrategyContext.shared.clearCache()
    }
}
