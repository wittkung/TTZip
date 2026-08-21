// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Disaster recovery and damaged archive repair engine with NEON-accelerated TOC reconstruction.
public final class ArchiveRepairEngine: @unchecked Sendable {
    public init() {}
    
    /// Scans a damaged archive and reconstructs readable payload data into a repaired archive.
    /// - Parameters:
    ///   - damagedArchivePath: Path to the corrupted archive file.
    ///   - repairedOutputPath: Destination path for the recovered archive.
    /// - Returns: Count of successfully salvaged entries.
    /// - Throws: `ArchiveError` if file cannot be accessed or repair fails.
    public func repairArchive(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: damagedArchivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: .processing,
            bytesProcessed: 0,
            totalBytes: 100,
            currentFileName: (damagedArchivePath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: nil,
            operationType: .repair
        ))
        
        var count = 0
        if let nativeSalvaged = repairArchiveNative(
            damagedArchivePath: damagedArchivePath,
            repairedOutputPath: repairedOutputPath
        ) {
            count = nativeSalvaged
        } else {
            count = try await ArchiveRepairStrategyContext.shared.repairArchive(
                damagedArchivePath: damagedArchivePath,
                repairedOutputPath: repairedOutputPath
            )
        }
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: .completed,
            bytesProcessed: Int64(count),
            totalBytes: Int64(count),
            currentFileName: (repairedOutputPath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: 0,
            operationType: .repair
        ))
        
        ArchiveEventCenter.shared.postArchiveCompleted(
            archivePath: repairedOutputPath,
            operationType: .repair,
            duration: 0.1,
            totalBytes: Int64(count)
        )
        
        return count
    }
    
    /// Fast hardware NEON-accelerated direct archive repair via Rust FFI.
    public func repairArchiveNative(damagedArchivePath: String, repairedOutputPath: String) -> Int? {
        guard FileManager.default.fileExists(atPath: damagedArchivePath) else { return nil }
        
        // 1. Check for Reed-Solomon self-healing recovery record
        var hasRecord = false
        _ = CUnsafeBufferAdapter.withCString(damagedArchivePath) { cSrc in
            guard let cSrc = cSrc else { return Int32(-1) }
            return ttzip_rust_rs_inspect_recovery_record_file(cSrc, nil, nil, nil, nil, nil, &hasRecord)
        }
        
        if hasRecord {
            var repaired = false
            let status = CUnsafeBufferAdapter.withCString(damagedArchivePath) { cSrc in
                guard let cSrc = cSrc else { return Int32(-1) }
                return ttzip_rust_rs_repair_archive_streaming(cSrc, &repaired)
            }
            if status == 0 && repaired {
                if damagedArchivePath != repairedOutputPath {
                    try? FileManager.default.removeItem(atPath: repairedOutputPath)
                    try? FileManager.default.copyItem(atPath: damagedArchivePath, toPath: repairedOutputPath)
                }
                return 1
            }
        }
        
        // 2. Direct format repair via Rust microkernel FFI
        return CUnsafeBufferAdapter.withCString(damagedArchivePath) { cSrc in
            CUnsafeBufferAdapter.withCString(repairedOutputPath) { cDst in
                guard let cSrc = cSrc, let cDst = cDst else { return nil }
                var salvaged: Int = 0
                let status = ttzip_rust_archive_repair_auto(cSrc, cDst, &salvaged)
                if status == TTZIP_STATUS_OK && salvaged > 0 {
                    return salvaged
                }
                return nil
            }
        }
    }
}
