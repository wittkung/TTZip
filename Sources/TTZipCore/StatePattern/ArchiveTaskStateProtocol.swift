// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive task state transition error definitions.
public enum ArchiveStateError: Error, LocalizedError, Equatable {
    case invalidTransition(from: String, action: String)
    case taskAlreadyCompleted
    case taskAlreadyFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let action):
            return "Invalid state transition: cannot perform '\(action)' from '\(from)' state."
        case .taskAlreadyCompleted:
            return "Task is already in completed terminal state."
        case .taskAlreadyFailed(let reason):
            return "Task is already in failed terminal state (\(reason))."
        }
    }
}

/// Archive task metrics and throughput measurements.
public struct TaskMetrics: Sendable, Equatable {
    public var startTime: Date?
    public var endTime: Date?
    public var pauseDuration: TimeInterval
    public var processedBytes: Int64
    public var totalBytes: Int64
    public var throughputMBs: Double
    
    public var durationSeconds: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        let cleanPause = max(0, pauseDuration)
        return max(0, end.timeIntervalSince(start) - cleanPause)
    }
    
    /// Progress completion fraction (0.0 ... 1.0) with zero-division safeguard.
    public var progressFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        let raw = Double(processedBytes) / Double(totalBytes)
        return min(1.0, max(0.0, raw))
    }
    
    public init(
        startTime: Date? = nil,
        endTime: Date? = nil,
        pauseDuration: TimeInterval = 0,
        processedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        throughputMBs: Double = 0.0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.pauseDuration = max(0, pauseDuration)
        self.processedBytes = max(0, processedBytes)
        self.totalBytes = max(0, totalBytes)
        self.throughputMBs = max(0.0, throughputMBs)
    }
}

/// Archive task state abstract interface protocol (State Pattern).
public protocol ArchiveTaskStateProtocol: Sendable {
    /// Human-readable state name.
    var stateName: String { get }
    
    /// Whether task can be paused in this state.
    var canPause: Bool { get }
    
    /// Whether task can be resumed in this state.
    var canResume: Bool { get }
    
    /// Whether task can be cancelled in this state.
    var canCancel: Bool { get }
    
    /// Triggers pause action.
    func pause(context: ArchiveTaskContext) throws
    
    /// Triggers resume action.
    func resume(context: ArchiveTaskContext) throws
    
    /// Triggers cancel action.
    func cancel(context: ArchiveTaskContext) throws
    
    /// Triggers failure termination.
    func fail(context: ArchiveTaskContext, error: Error) throws
    
    /// Triggers completion terminal state.
    func complete(context: ArchiveTaskContext) throws
}

public extension ArchiveTaskStateProtocol {
    var canPause: Bool { false }
    var canResume: Bool { false }
    var canCancel: Bool { false }
    
    func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}
