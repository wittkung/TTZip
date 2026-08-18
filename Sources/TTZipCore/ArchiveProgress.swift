// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Real-time progress and telemetry metadata for archiving operations.
public struct ArchiveProgress: Sendable {
    /// Progress lifecycle states.
    public enum State: Sendable, Equatable {
        case idle
        case processing
        case completed
        case cancelled
        case failed(error: String)
    }
    
    /// Current execution state.
    public let state: State
    /// Number of bytes processed so far.
    public let bytesProcessed: Int64
    /// Total byte size of expected workload.
    public let totalBytes: Int64
    /// Name or path of file currently being compressed or extracted.
    public let currentFileName: String
    /// Monotonic throughput calculation in MB/s.
    public let throughputMBs: Double
    
    /// Normalized fraction completed (0.0 to 1.0).
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }
    
    public init(
        state: State = .idle,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentFileName: String = "",
        throughputMBs: Double = 0.0
    ) {
        self.state = state
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(0, totalBytes)
        self.currentFileName = currentFileName
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
    }
    
    public static let zero = ArchiveProgress()
}
