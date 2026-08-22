// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive operation type classification.
public enum ArchiveOperationType: String, Sendable, Equatable, CaseIterable {
    case compress = "Compress"
    case extract = "Extract"
    case repair = "Repair"
    case batch = "Batch"
    case recover = "PasswordRecovery"
    case inspect = "Inspect"
}

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

/// Detailed progress data packet delivered to archive progress observers.
public struct ArchiveProgressInfo: Sendable, Equatable {
    public let state: ArchiveProgress.State
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let currentFileName: String
    public let throughputMBs: Double
    public let estimatedTimeRemaining: TimeInterval?
    public let operationType: ArchiveOperationType
    
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }
    
    public init(
        state: ArchiveProgress.State = .processing,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentFileName: String = "",
        throughputMBs: Double = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil,
        operationType: ArchiveOperationType = .compress
    ) {
        self.state = state
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(0, totalBytes)
        self.currentFileName = currentFileName
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
        if let eta = estimatedTimeRemaining, !eta.isNaN, !eta.isInfinite, eta >= 0 {
            self.estimatedTimeRemaining = eta
        } else {
            self.estimatedTimeRemaining = nil
        }
        self.operationType = operationType
    }
}

/// Progress data packet delivered to multi-file and batch task observers.
public struct BatchProgressInfo: Sendable, Equatable {
    public let completedTasks: Int
    public let totalTasks: Int
    public let currentTaskPath: String
    public let totalBytesProcessed: Int64
    public let totalBytesCount: Int64
    public let throughputMBs: Double
    public let estimatedTimeRemaining: TimeInterval?
    
    public var fractionCompleted: Double {
        guard totalTasks > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(completedTasks) / Double(totalTasks)))
    }
    
    public init(
        completedTasks: Int,
        totalTasks: Int,
        currentTaskPath: String = "",
        totalBytesProcessed: Int64 = 0,
        totalBytesCount: Int64 = 0,
        throughputMBs: Double = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.completedTasks = max(0, completedTasks)
        self.totalTasks = max(0, totalTasks)
        self.currentTaskPath = currentTaskPath
        self.totalBytesProcessed = max(0, totalBytesProcessed)
        self.totalBytesCount = max(0, totalBytesCount)
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
        if let eta = estimatedTimeRemaining, !eta.isNaN, !eta.isInfinite, eta >= 0 {
            self.estimatedTimeRemaining = eta
        } else {
            self.estimatedTimeRemaining = nil
        }
    }
}

/// Archive progress observer protocol.
public protocol ArchiveProgressObserverProtocol: AnyObject, Sendable {
    func onProgressUpdated(_ progress: ArchiveProgressInfo)
    func onBatchProgressUpdated(_ progress: BatchProgressInfo)
}

extension ArchiveProgressObserverProtocol {
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {}
    public func onBatchProgressUpdated(_ progress: BatchProgressInfo) {}
}

/// System-wide global archive event type.
public enum ArchiveEventType: String, Sendable, Equatable, Hashable, CaseIterable {
    case archiveCompleted
    case extractionFailed
    case securityThreatIntercepted
    case passwordVaultUnlocked
    case presetChanged
    case taskStateChanged
}

/// System-wide global archive event payload data.
public enum ArchiveEvent: Sendable, Equatable {
    case archiveCompleted(archivePath: String, operationType: ArchiveOperationType, duration: TimeInterval, totalBytes: Int64)
    case extractionFailed(archivePath: String, error: String)
    case securityThreatIntercepted(archivePath: String, threatDescription: String)
    case passwordVaultUnlocked(archivePath: String, password: String, isVaultUnlocked: Bool)
    case presetChanged(oldPresetName: String?, newPresetName: String)
    case taskStateChanged(taskId: UUID, oldState: String, newState: String)
    
    public var eventType: ArchiveEventType {
        switch self {
        case .archiveCompleted: return .archiveCompleted
        case .extractionFailed: return .extractionFailed
        case .securityThreatIntercepted: return .securityThreatIntercepted
        case .passwordVaultUnlocked: return .passwordVaultUnlocked
        case .presetChanged: return .presetChanged
        case .taskStateChanged: return .taskStateChanged
        }
    }
    
    public var archivePath: String? {
        switch self {
        case .archiveCompleted(let path, _, _, _): return path
        case .extractionFailed(let path, _): return path
        case .securityThreatIntercepted(let path, _): return path
        case .passwordVaultUnlocked(let path, _, _): return path
        case .presetChanged, .taskStateChanged: return nil
        }
    }
}

/// System-wide global archive event observer protocol.
public protocol ArchiveEventObserverProtocol: AnyObject, Sendable {
    func onArchiveEvent(_ event: ArchiveEvent)
}
