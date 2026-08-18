// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput streaming decompressor for Zstandard (.zst) format.
public final class ZstdStreamExtractor: @unchecked Sendable {
    public static let shared = ZstdStreamExtractor()
    
    private init() {}
    
    /// Decompresses a Zstandard archive container from source path to destination path.
    public func decompress(
        srcPath: String,
        dstPath: String,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tuner = AppleSiliconTuner.shared
        tuner.boostCurrentThreadPriority()
        
        let fileManager = FileManager.default
        let srcBytes = (try? fileManager.attributesOfItem(atPath: srcPath)[.size] as? Int64) ?? 0
        let startTime = Date()
        
        progressHandler?(ArchiveProgress(
            state: .processing,
            bytesProcessed: 0,
            totalBytes: srcBytes,
            currentFileName: (srcPath as NSString).lastPathComponent,
            throughputMBs: 0.0
        ))
        
        let result = ttzip_zstd_decompress_file_stream(srcPath, dstPath, dictPath)
        
        if result == 0 {
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let outBytes = (try? fileManager.attributesOfItem(atPath: dstPath)[.size] as? Int64) ?? 0
            let throughput = (Double(outBytes) / (1024.0 * 1024.0)) / duration
            
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: outBytes,
                totalBytes: outBytes,
                currentFileName: (dstPath as NSString).lastPathComponent,
                throughputMBs: throughput
            ))
            return true
        } else {
            TTLogger.error("Zstandard C decompression error code: \(result)")
        }
        
        return false
    }
}
