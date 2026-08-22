// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public enum ArchiveTaskExecutionState: String, Sendable, Codable, CaseIterable {
    case queued = "queued"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

public struct QueuedArchiveOperation: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var operationType: ArchiveOperationType
    public var state: ArchiveTaskExecutionState
    public var totalBytes: Int64
    public var bytesProcessed: Int64
    public var throughputMBs: Double
    public var errorMessage: String?
    
    public var fractionCompleted: Double {
        totalBytes > 0 ? Double(bytesProcessed) / Double(totalBytes) : 0.0
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        operationType: ArchiveOperationType,
        state: ArchiveTaskExecutionState = .queued,
        totalBytes: Int64 = 0,
        bytesProcessed: Int64 = 0,
        throughputMBs: Double = 0.0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.operationType = operationType
        self.state = state
        self.totalBytes = totalBytes
        self.bytesProcessed = bytesProcessed
        self.throughputMBs = throughputMBs
        self.errorMessage = errorMessage
    }
}
