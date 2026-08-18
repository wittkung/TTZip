// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type encapsulating the execution outcome, artifacts, and rollback metadata of a command.
public struct CommandResult: Sendable, Equatable {
    public let commandId: String
    public let success: Bool
    public let message: String
    public let artifactsCreated: [String]
    public let backupPaths: [String: String]
    public let executionDuration: Double
    public let metadata: [String: String]
    
    public init(
        commandId: String,
        success: Bool,
        message: String,
        artifactsCreated: [String] = [],
        backupPaths: [String: String] = [:],
        executionDuration: Double = 0.0,
        metadata: [String: String] = [:]
    ) {
        self.commandId = commandId
        self.success = success
        self.message = message
        self.artifactsCreated = artifactsCreated
        self.backupPaths = backupPaths
        self.executionDuration = executionDuration
        self.metadata = metadata
    }
}

/// Command execution and rollback error cases.
public enum CommandError: Error, LocalizedError, Equatable {
    case notUndoable(commandId: String)
    case executionFailed(reason: String)
    case undoFailed(reason: String)
    case macroExecutionFailed(failedIndex: Int, underlyingError: String, rollbackErrors: [String])
    case invalidState(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .notUndoable(let id):
            return "Command is not undoable: \(id)"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .undoFailed(let reason):
            return "Command undo failed: \(reason)"
        case .macroExecutionFailed(let idx, let err, let rollbacks):
            return "Macro command failed at step [\(idx)]: \(err). Rollback status: \(rollbacks.isEmpty ? "Success" : "Partial rollback failures (\(rollbacks.joined(separator: "; ")))")"
        case .invalidState(let reason):
            return "Invalid command state: \(reason)"
        }
    }
}
