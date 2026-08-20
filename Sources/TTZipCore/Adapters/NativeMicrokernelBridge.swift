// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance thin Swift bridge directly dispatching to the pure C11 libttzip microkernel.
public enum NativeMicrokernelBridge {
    
    /// Compresses input file paths into a destination archive using pure C engine.
    public static func createArchive(
        inputPaths: [String],
        outputPath: String,
        codec: ttzip_api_codec_t = TTZIP_API_CODEC_DEFLATE,
        level: Int32 = 6,
        progress: (@Sendable (UInt64, UInt64, String) -> Void)? = nil
    ) -> Int32 {
        var cfg = ttzip_archive_config_t(
            codec: codec.rawValue,
            level: level,
            threads: 0,
            password: nil,
            solid_block_size: 0,
            format_override: nil
        )
        
        let cPaths: [UnsafePointer<CChar>?] = inputPaths.map { UnsafePointer(strdup($0)) }
        defer {
            for ptr in cPaths {
                if let p = ptr { free(UnsafeMutableRawPointer(mutating: p)) }
            }
        }
        
        return cPaths.withUnsafeBufferPointer { bufPtr in
            guard let baseAddress = bufPtr.baseAddress else { return -1 }
            return ttzip_archive_create(
                &cfg,
                baseAddress,
                inputPaths.count,
                outputPath,
                nil,
                nil
            )
        }
    }
    
    /// Extracts archive directly to destination directory using pure C multi-core engine.
    public static func extractArchive(
        archivePath: String,
        destinationDir: String
    ) -> Int32 {
        return ttzip_archive_extract(archivePath, destinationDir, nil, nil, nil)
    }
    
    /// Extracts a single archive entry directly to an in-memory Data buffer (Zero Disk I/O).
    public static func extractEntryToMemory(
        archivePath: String,
        entryIndex: Int,
        estimatedSize: Int = 10 * 1024 * 1024
    ) -> Data? {
        var decompSize: Int = 0
        var buffer = Data(count: estimatedSize)
        
        let result = buffer.withUnsafeMutableBytes { rawBuf -> Int32 in
            guard let ptr = rawBuf.baseAddress else { return -1 }
            return ttzip_archive_extract_entry_mem(
                archivePath,
                entryIndex,
                ptr,
                estimatedSize,
                &decompSize
            )
        }
        
        if result == 0 && decompSize > 0 {
            return buffer.prefix(decompSize)
        }
        return nil
    }
    
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
    
    /// Natural numeric string comparison (case-insensitive) in C11.
    public static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        let res = ttzip_strnatcasecmp(a, b)
        if res < 0 { return .orderedAscending }
        if res > 0 { return .orderedDescending }
        return .orderedSame
    }
}
