// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Rust-backed engine for concatenating and reading multi-volume split archives.
public final class SplitVolumeConcatenator: @unchecked Sendable {
    public static let shared = SplitVolumeConcatenator()
    
    public init() {}
    
    /// Joins multi-volume split archive files starting from the first volume seed into a single continuous file.
    public func join(
        firstVolumePath: String,
        outputPath: String,
        progressHandler: (@Sendable (Double) -> Bool)? = nil
    ) throws {
        let status = firstVolumePath.withCString { cFirst in
            outputPath.withCString { cOut in
                if let progressHandler = progressHandler {
                    return withUnsafePointer(to: progressHandler) { ptr in
                        let callback: TTZipProgressCallback = { current, total, _, userData in
                            guard let userData = userData else { return true }
                            let handler = userData.assumingMemoryBound(to: (@Sendable (Double) -> Bool).self).pointee
                            let fraction = total > 0 ? Double(current) / Double(total) : 0.0
                            return handler(fraction)
                        }
                        return ttzip_rust_join_split_volumes(cFirst, cOut, callback, UnsafeMutableRawPointer(mutating: ptr))
                    }
                } else {
                    return ttzip_rust_join_split_volumes(cFirst, cOut, nil, nil)
                }
            }
        }
        
        guard status == TTZIP_STATUS_OK else {
            if status == TTZIP_STATUS_CANCELLED {
                throw ArchiveError.cancelled
            }
            throw ArchiveError.readFailed(code: status.rawValue)
        }
    }
    
    /// Queries the total uncompressed continuous size and volume count for a split volume series.
    public func inspect(seedPath: String) -> (totalSize: UInt64, volumePaths: [String])? {
        guard let handle = seedPath.withCString({ ttzip_rust_split_reader_open($0) }) else {
            return nil
        }
        defer { ttzip_rust_split_reader_free(handle) }
        
        let totalSize = ttzip_rust_split_reader_get_total_size(handle)
        let count = ttzip_rust_split_reader_get_volume_count(handle)
        
        var paths: [String] = []
        paths.reserveCapacity(count)
        var buf = [CChar](repeating: 0, count: 1024)
        for i in 0..<count {
            let res = ttzip_rust_split_reader_get_volume_path(handle, i, &buf, buf.count)
            if res == TTZIP_STATUS_OK {
                buf.withUnsafeBufferPointer { ptr in
                    if let base = ptr.baseAddress {
                        paths.append(String(cString: base))
                    }
                }
            }
        }
        return (totalSize, paths)
    }
}
