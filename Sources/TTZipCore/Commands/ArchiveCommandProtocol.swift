// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive command interface protocol (Command Pattern).
///
/// Encapsulates executable and undoable atomic archive commands.
public protocol ArchiveCommandProtocol: Sendable {
    /// Unique command identifier.
    var commandId: String { get }
    
    /// Human-readable command description for Undo/Redo histories and telemetry.
    var description: String { get }
    
    /// Whether the command supports undo operations.
    var isUndoable: Bool { get }
    
    /// Executes the command.
    /// - Returns: Command execution outcome and created artifacts.
    func execute() async throws -> CommandResult
    
    /// Reverts the command execution.
    func undo() async throws
    
    /// Purges disk backups and temporary files allocated for rollback safety.
    func purgeBackupResources()
}

public extension ArchiveCommandProtocol {
    func purgeBackupResources() {
        // Default no-op for commands without persistent disk backups.
    }
}
