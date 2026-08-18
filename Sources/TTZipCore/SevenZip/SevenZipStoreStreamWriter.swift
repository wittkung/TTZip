// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Fast store mode (Level 0) stream writer for 7z container creation without compression overhead.
public final class SevenZipStoreStreamWriter: @unchecked Sendable {
    public static let shared = SevenZipStoreStreamWriter()
    
    private init() {}
    
    /// Synchronously creates a 7z Store (L0) archive container.
    public func createStoreArchive(
        outputPath: String,
        inputPaths: [String],
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        guard !inputPaths.isEmpty else { return false }
        let startTime = CFAbsoluteTimeGetCurrent()
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        
        let totalInputSize: Int64 = inputPaths.reduce(0) { acc, path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return acc }
            let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
            let size = (attrs[.size] as? Int64) ?? (attrs[.size] as? NSNumber)?.int64Value ?? 0
            return acc + (isDir ? 0 : size)
        }
        if totalInputSize >= 50 * 1024 * 1024 {
            ArchiveDiskPreallocator.preallocate(atPath: outputPath, targetSizeBytes: totalInputSize)
        }
        
        let factory = ArchiveEntryFlyweightFactory.shared
        let internedInputPaths = inputPaths.map { factory.internPath($0) }
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let success = CUnsafeBufferAdapter.withCString(outputPath) { cOutPath in
            CUnsafeBufferAdapter.withCStringsArray(internedInputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutPath = cOutPath else { return false }
                    let res: Int32
                    if cPassword == nil {
                        res = ttzip_create_7z_store_fast_c(cOutPath, cInputPaths, internedInputPaths.count)
                    } else {
                        res = ttzip_create_7z_native_c(cOutPath, cInputPaths, internedInputPaths.count, 0, cPassword)
                    }
                    return res == 0
                }
            }
        }
        if success {
            let duration = max(0.001, CFAbsoluteTimeGetCurrent() - startTime)
            let throughput = (Double(totalInputSize) / (1024.0 * 1024.0)) / duration
            let formattedTotal = ByteCountFormatterFlyweight.shared.string(fromByteCount: totalInputSize)
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: totalInputSize,
                totalBytes: totalInputSize,
                currentFileName: "7z Store packaging complete (\(formattedTotal))",
                throughputMBs: throughput
            ))
        }
        return success
    }
}
