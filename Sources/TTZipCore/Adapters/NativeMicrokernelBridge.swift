// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance thin Swift bridge for format sniffing and natural string sorting.
public enum NativeMicrokernelBridge {
    
    /// Sniffs file format magic numbers in constant time (<1ns).
    public static func sniffMagic(data: Data) -> (kind: ttzip_file_kind_t, format: String, mime: String) {
        return data.withUnsafeBytes { rawBuf in
            guard let ptr = rawBuf.baseAddress else {
                return (TTZIP_KIND_UNKNOWN, "UNKNOWN", "application/octet-stream")
            }
            let info = ttzip_magic_sniff_buffer(ptr, rawBuf.count)
            let fmt = info.format_name != nil ? String(cString: info.format_name) : "UNKNOWN"
            let mime = info.mime_type != nil ? String(cString: info.mime_type) : "application/octet-stream"
            return (info.kind, fmt, mime)
        }
    }
    
    /// Natural numeric string comparison (case-insensitive) using Foundation.
    public static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        return a.localizedStandardCompare(b)
    }
}

