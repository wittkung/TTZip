// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Composite / macro command orchestrating a sequence of archive operations with automated reverse rollback.
public final class MacroArchiveCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool {
        commands.allSatisfy { $0.isUndoable }
    }
    
    public let commands: [ArchiveCommandProtocol]
    private let lock = NSLock()
    
    private var executedSubCommands: [ArchiveCommandProtocol] = []
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        commands: [ArchiveCommandProtocol]
    ) {
        self.commandId = commandId
        self.commands = commands
        self.description = description ?? "Macro command (\(commands.count) atomic steps)"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        clearExecutedList()
        
        var combinedArtifacts: [String] = []
        var combinedBackups: [String: String] = [:]
        
        for (index, command) in commands.enumerated() {
            do {
                let subResult = try await command.execute()
                
                appendExecutedCommand(command)
                
                combinedArtifacts.append(contentsOf: subResult.artifactsCreated)
                for (k, v) in subResult.backupPaths {
                    combinedBackups[k] = v
                }
            } catch {
                let rollbackErrors = await performRollback()
                
                throw CommandError.macroExecutionFailed(
                    failedIndex: index,
                    underlyingError: error.localizedDescription,
                    rollbackErrors: rollbackErrors
                )
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        markAsExecuted()
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "Macro command executed successfully (\(commands.count) sub-steps)",
            artifactsCreated: combinedArtifacts,
            backupPaths: combinedBackups,
            executionDuration: duration
        )
    }
    
    public func undo() async throws {
        let (executed, toUndo) = getUndoStateAndReset()
        guard executed || !toUndo.isEmpty else {
            throw CommandError.invalidState(reason: "Macro command has not been executed; cannot undo.")
        }
        
        var undoErrors: [String] = []
        var remainingCommands = toUndo
        
        for command in toUndo.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
                _ = remainingCommands.popLast()
            } catch {
                undoErrors.append("Undo failed for [\(command.description)]: \(error.localizedDescription)")
            }
        }
        
        if !undoErrors.isEmpty {
            restoreUnfinishedState(remainingCommands)
            throw CommandError.undoFailed(reason: undoErrors.joined(separator: "; "))
        }
    }
    
    public func purgeBackupResources() {
        for command in commands {
            command.purgeBackupResources()
        }
    }
    
    // MARK: - Rollback Helpers
    
    private func performRollback() async -> [String] {
        let toRollback = getExecutedListAndReset()
        
        var rollbackErrors: [String] = []
        for command in toRollback.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
            } catch {
                rollbackErrors.append("Rollback failed for [\(command.description)]: \(error.localizedDescription)")
            }
        }
        
        return rollbackErrors
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func clearExecutedList() {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.removeAll()
        isExecutedState = false
    }
    
    private func appendExecutedCommand(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.append(command)
    }
    
    private func markAsExecuted() {
        lock.lock()
        defer { lock.unlock() }
        isExecutedState = true
    }
    
    private func restoreUnfinishedState(_ unfinished: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands = unfinished
        isExecutedState = !unfinished.isEmpty
    }
    
    private func getExecutedListAndReset() -> [ArchiveCommandProtocol] {
        lock.lock()
        defer { lock.unlock() }
        let list = executedSubCommands
        executedSubCommands.removeAll()
        isExecutedState = false
        return list
    }
    
    private func getUndoStateAndReset() -> (executed: Bool, list: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        let wasExecuted = isExecutedState
        let list = executedSubCommands
        isExecutedState = false
        executedSubCommands.removeAll()
        return (wasExecuted, list)
    }
}
