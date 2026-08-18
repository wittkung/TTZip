// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive operation type classification.
public enum ArchiveOperationType: String, Sendable, Equatable, CaseIterable {
    case compress = "compress"
    case extract = "extract"
    case repair = "repair"
    case batch = "batch"
    case recover = "recover"
    case inspect = "inspect"
}

/// Detailed progress telemetry payload for archive operations.
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
    
    /// Calculates estimated time remaining (ETA) safely guarding against division by zero.
    public static func calculateETA(bytesProcessed: Int64, totalBytes: Int64, throughputMBs: Double) -> TimeInterval? {
        guard totalBytes > 0, bytesProcessed >= 0, totalBytes > bytesProcessed else { return nil }
        guard throughputMBs.isFinite, !throughputMBs.isNaN, throughputMBs > 0.0001 else { return nil }
        let remainingBytes = Double(totalBytes - bytesProcessed)
        let remainingMB = remainingBytes / (1024.0 * 1024.0)
        let eta = remainingMB / throughputMBs
        return (eta.isFinite && !eta.isNaN && eta >= 0) ? eta : nil
    }
}

/// Batch task progress telemetry payload.
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

/// Archive progress observer protocol (Observer Pattern).
public protocol ArchiveProgressObserverProtocol: AnyObject, Sendable {
    func onProgressUpdated(_ progress: ArchiveProgressInfo)
    func onBatchProgressUpdated(_ progress: BatchProgressInfo)
}

extension ArchiveProgressObserverProtocol {
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {}
    public func onBatchProgressUpdated(_ progress: BatchProgressInfo) {}
}

/// Global system event types.
public enum ArchiveEventType: String, Sendable, Equatable, Hashable, CaseIterable {
    case archiveCompleted
    case extractionFailed
    case securityThreatIntercepted
    case passwordVaultUnlocked
    case presetChanged
    case taskStateChanged
}

/// Global system event payloads.
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

/// Global system event observer protocol.
public protocol ArchiveEventObserverProtocol: AnyObject, Sendable {
    func onArchiveEvent(_ event: ArchiveEvent)
}

/// Event bus protocol for subscribing and posting system events.
public protocol ArchiveEventCenterProtocol: Sendable {
    func addObserver(
        _ observer: ArchiveEventObserverProtocol,
        forEvents events: Set<ArchiveEventType>?,
        dispatchQueue: DispatchQueue?
    )
    func removeObserver(_ observer: ArchiveEventObserverProtocol)
    func removeAllObservers()
    func post(event: ArchiveEvent)
    var observerCount: Int { get }
}
