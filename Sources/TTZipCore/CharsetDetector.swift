// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Character encoding detection and filename sanitization interface.
public enum CharsetDetector {
    /// Detects charset encoding name (e.g. GB18030, UTF-8, Shift-JIS) from raw byte sequence.
    public static func detectCharset(data: Data) -> String {
        if data.isEmpty { return "UTF-8" }
        if String(data: data, encoding: .utf8) != nil {
            return "UTF-8"
        }
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if String(data: data, encoding: gb18030Encoding) != nil {
            return "GB18030"
        }
        let shiftJISEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)))
        if String(data: data, encoding: shiftJISEncoding) != nil {
            return "Shift-JIS"
        }
        let big5Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        if String(data: data, encoding: big5Encoding) != nil {
            return "Big5"
        }
        if String(data: data, encoding: .windowsCP1252) != nil {
            return "Windows-1252"
        }
        return "ISO-8859-1"
    }
    
    /// Sanitizes raw filename byte sequences into valid Unicode Swift String.
    public static func sanitizeFilename(bytes: Data) -> String {
        if let utf8 = String(data: bytes, encoding: .utf8) {
            return utf8
        }
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let gb = String(data: bytes, encoding: gb18030Encoding) {
            return gb
        }
        let shiftJISEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)))
        if let sjis = String(data: bytes, encoding: shiftJISEncoding) {
            return sjis
        }
        return String(decoding: bytes, as: UTF8.self)
    }
    
    /// Clears charset detection caching structures.
    public static func clearCache() {}
}
