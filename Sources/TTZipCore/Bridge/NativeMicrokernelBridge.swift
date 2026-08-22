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
        guard data.count >= 2 else {
            return (TTZIP_KIND_UNKNOWN, "UNKNOWN", "application/octet-stream")
        }
        return data.withUnsafeBytes { rawBuf in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return (TTZIP_KIND_UNKNOWN, "UNKNOWN", "application/octet-stream")
            }
            let len = rawBuf.count
            if len >= 4 && ptr[0] == 0x50 && ptr[1] == 0x4B && ptr[2] == 0x03 && ptr[3] == 0x04 {
                return (TTZIP_KIND_ARCHIVE, "ZIP", "application/zip")
            }
            if len >= 6 && ptr[0] == 0x37 && ptr[1] == 0x7A && ptr[2] == 0xBC && ptr[3] == 0xAF && ptr[4] == 0x27 && ptr[5] == 0x1C {
                return (TTZIP_KIND_ARCHIVE, "7Z", "application/x-7z-compressed")
            }
            if len >= 2 && ptr[0] == 0x1F && ptr[1] == 0x8B {
                return (TTZIP_KIND_ARCHIVE, "GZIP", "application/gzip")
            }
            if len >= 6 && ptr[0] == 0xFD && ptr[1] == 0x37 && ptr[2] == 0x7A && ptr[3] == 0x58 && ptr[4] == 0x5A && ptr[5] == 0x00 {
                return (TTZIP_KIND_ARCHIVE, "XZ", "application/x-xz")
            }
            if len >= 4 && ptr[0] == 0x28 && ptr[1] == 0xB5 && ptr[2] == 0x2F && ptr[3] == 0xFD {
                return (TTZIP_KIND_ARCHIVE, "ZSTD", "application/zstd")
            }
            if len >= 3 && ptr[0] == 0x42 && ptr[1] == 0x5A && ptr[2] == 0x68 {
                return (TTZIP_KIND_ARCHIVE, "BZIP2", "application/x-bzip2")
            }
            if len >= 7 && ptr[0] == 0x52 && ptr[1] == 0x61 && ptr[2] == 0x72 && ptr[3] == 0x21 && ptr[4] == 0x1A && ptr[5] == 0x07 {
                return (TTZIP_KIND_ARCHIVE, "RAR", "application/x-rar-compressed")
            }
            if len >= 8 && ptr[0] == 0x89 && ptr[1] == 0x50 && ptr[2] == 0x4E && ptr[3] == 0x43 && ptr[4] == 0x0D && ptr[5] == 0x0A && ptr[6] == 0x1A && ptr[7] == 0x0A {
                return (TTZIP_KIND_IMAGE, "PNG", "image/png")
            }
            if len >= 3 && ptr[0] == 0xFF && ptr[1] == 0xD8 && ptr[2] == 0xFF {
                return (TTZIP_KIND_IMAGE, "JPEG", "image/jpeg")
            }
            if len >= 6 && ptr[0] == 0x47 && ptr[1] == 0x49 && ptr[2] == 0x46 && ptr[3] == 0x38 && (ptr[4] == 0x37 || ptr[4] == 0x39) && ptr[5] == 0x61 {
                return (TTZIP_KIND_IMAGE, "GIF", "image/gif")
            }
            if len >= 4 && ptr[0] == 0x25 && ptr[1] == 0x50 && ptr[2] == 0x44 && ptr[3] == 0x46 {
                return (TTZIP_KIND_BINARY, "PDF", "application/pdf")
            }
            return (TTZIP_KIND_UNKNOWN, "BINARY", "application/octet-stream")
        }
    }
    
    /// Natural numeric string comparison (case-insensitive) using Foundation.
    public static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        return a.localizedStandardCompare(b)
    }
}
