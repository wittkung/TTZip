// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Queue Operation Types

/// Operation classification for the global operations queue and telemetry.
public enum QueueOperationType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case compress = "compress"
    case extract = "extract"
    case test = "test"
    case repair = "repair"
    case batchCompress = "batch_compress"
    case batchExtract = "batch_extract"
}

// MARK: - Archive Task Execution State

/// Lifecycle execution states for queued and running archive operations.
public enum ArchiveTaskExecutionState: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case queued = "queued"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Queue Task Priority

/// String-aligned priority tiers conforming to JSON telemetry contracts.
public enum QueueTaskPriority: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case critical = "critical"
    case userInitiated = "userInitiated"
    case utility = "utility"
    case background = "background"

    /// Maps from TTZipCore internal `TaskPriorityLevel`.
    public init(priorityLevel: TaskPriorityLevel) {
        switch priorityLevel {
        case .critical:
            self = .critical
        case .userInitiated:
            self = .userInitiated
        case .utility:
            self = .utility
        case .background:
            self = .background
        }
    }

    /// Maps back to TTZipCore internal `TaskPriorityLevel`.
    public var priorityLevel: TaskPriorityLevel {
        switch self {
        case .critical:
            return .critical
        case .userInitiated:
            return .userInitiated
        case .utility:
            return .utility
        case .background:
            return .background
        }
    }
}

// MARK: - Global Operations Queue Event

/// Real-time task lifecycle and progress telemetry event emitted by the global operations scheduler.
/// Conforms strictly to `contracts/global-operations-queue-event.json`.
public struct GlobalOperationsQueueEvent: Sendable, Codable, Equatable, Hashable {
    /// Unique identifier of the task (UUID v4 format).
    public let taskId: String
    
    /// Human-readable label or target filename.
    public let taskName: String
    
    /// Operation classification string ("compress", "extract", "test", "repair", "batch_compress", "batch_extract").
    public let operationType: String
    
    /// Current lifecycle status ("queued", "running", "paused", "completed", "failed", "cancelled").
    public let state: String
    
    /// Execution priority tier ("critical", "userInitiated", "utility", "background").
    public let priority: String
    
    /// Processed payload volume in bytes.
    public let bytesProcessed: Int64
    
    /// Expected total volume in bytes.
    public let totalBytes: Int64
    
    /// Completion fraction [0.0, 1.0].
    public let fractionCompleted: Double
    
    /// Instantaneous I/O and processing speed in MB/s.
    public let throughputMBs: Double
    
    /// ETA in seconds until task completion.
    public let estimatedTimeRemainingSeconds: Double?
    
    /// Error details if task failed.
    public let errorMessage: String?

    public init(
        taskId: String,
        taskName: String,
        operationType: String,
        state: String,
        priority: String,
        bytesProcessed: Int64,
        totalBytes: Int64,
        fractionCompleted: Double,
        throughputMBs: Double,
        estimatedTimeRemainingSeconds: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.taskId = taskId
        self.taskName = taskName
        self.operationType = operationType
        self.state = state
        self.priority = priority
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.fractionCompleted = fractionCompleted
        self.throughputMBs = throughputMBs
        self.estimatedTimeRemainingSeconds = estimatedTimeRemainingSeconds
        self.errorMessage = errorMessage
    }

    /// Convenience initializer accepting typed enum definitions.
    public init(
        taskId: UUID,
        taskName: String,
        operationType: QueueOperationType,
        state: ArchiveTaskExecutionState,
        priority: QueueTaskPriority,
        bytesProcessed: Int64,
        totalBytes: Int64,
        fractionCompleted: Double,
        throughputMBs: Double,
        estimatedTimeRemainingSeconds: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.taskId = taskId.uuidString
        self.taskName = taskName
        self.operationType = operationType.rawValue
        self.state = state.rawValue
        self.priority = priority.rawValue
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.fractionCompleted = fractionCompleted
        self.throughputMBs = throughputMBs
        self.estimatedTimeRemainingSeconds = estimatedTimeRemainingSeconds
        self.errorMessage = errorMessage
    }

    /// Typed operation type if matching defined `QueueOperationType`.
    public var typedOperationType: QueueOperationType? {
        return QueueOperationType(rawValue: operationType)
    }

    /// Typed lifecycle state if matching defined `ArchiveTaskExecutionState`.
    public var typedState: ArchiveTaskExecutionState? {
        return ArchiveTaskExecutionState(rawValue: state)
    }

    /// Typed priority tier if matching defined `QueueTaskPriority`.
    public var typedPriority: QueueTaskPriority? {
        return QueueTaskPriority(rawValue: priority)
    }
}

// MARK: - Queued Archive Operation

/// Domain model representing a managed task within the global multi-task scheduler.
public struct QueuedArchiveOperation: Sendable, Identifiable, Equatable, Hashable {
    /// Unique task identifier.
    public let id: UUID
    
    /// Human-readable task name or filename.
    public var name: String
    
    /// Operation classification.
    public var operationType: ArchiveOperationType
    
    /// Scheduler priority tier.
    public var priority: TaskPriorityLevel
    
    /// Task creation timestamp.
    public var createdAt: Date
    
    /// Current execution state.
    public var state: ArchiveTaskExecutionState
    
    /// Processed volume in bytes.
    public var bytesProcessed: Int64
    
    /// Total expected volume in bytes.
    public var totalBytes: Int64
    
    /// Instantaneous processing throughput in MB/s.
    public var throughputMBs: Double
    
    /// Detailed error message if failed.
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        name: String,
        operationType: ArchiveOperationType,
        priority: TaskPriorityLevel = .userInitiated,
        createdAt: Date = Date(),
        state: ArchiveTaskExecutionState = .queued,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        throughputMBs: Double = 0.0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.operationType = operationType
        self.priority = priority
        self.createdAt = createdAt
        self.state = state
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.throughputMBs = throughputMBs
        self.errorMessage = errorMessage
    }

    /// Progress completion ratio [0.0, 1.0].
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return state == .completed ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }

    /// Translates the queued operation into a telemetry queue event.
    public func toTelemetryEvent(
        estimatedTimeRemaining: Double? = nil
    ) -> GlobalOperationsQueueEvent {
        let opTypeStr: String
        switch operationType {
        case .compress: opTypeStr = QueueOperationType.compress.rawValue
        case .extract: opTypeStr = QueueOperationType.extract.rawValue
        case .repair: opTypeStr = QueueOperationType.repair.rawValue
        case .batch: opTypeStr = QueueOperationType.batchCompress.rawValue
        case .recover: opTypeStr = QueueOperationType.repair.rawValue
        case .inspect: opTypeStr = QueueOperationType.test.rawValue
        }

        return GlobalOperationsQueueEvent(
            taskId: id.uuidString,
            taskName: name,
            operationType: opTypeStr,
            state: state.rawValue,
            priority: QueueTaskPriority(priorityLevel: priority).rawValue,
            bytesProcessed: bytesProcessed,
            totalBytes: totalBytes,
            fractionCompleted: fractionCompleted,
            throughputMBs: throughputMBs,
            estimatedTimeRemainingSeconds: estimatedTimeRemaining,
            errorMessage: errorMessage
        )
    }
}
