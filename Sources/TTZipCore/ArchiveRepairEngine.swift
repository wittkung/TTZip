// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Disaster recovery and damaged archive repair engine.
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
        
        let count = try await ArchiveRepairStrategyContext.shared.repairArchive(
            damagedArchivePath: damagedArchivePath,
            repairedOutputPath: repairedOutputPath
        )
        
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
}
