// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive task history record domain entity model.
public struct ArchiveTaskRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var commandName: String
    public var archivePath: String
    public var targetPath: String
    public var isSuccess: Bool
    public var timestamp: Date
    public var fileSizeByte: Int64
    
    public init(
        id: UUID = UUID(),
        commandName: String,
        archivePath: String,
        targetPath: String,
        isSuccess: Bool,
        timestamp: Date = Date(),
        fileSizeByte: Int64 = 0
    ) {
        self.id = id
        self.commandName = commandName
        self.archivePath = archivePath
        self.targetPath = targetPath
        self.isSuccess = isSuccess
        self.timestamp = timestamp
        self.fileSizeByte = fileSizeByte
    }
}

/// Command history manager and invoker maintaining dual Undo/Redo stacks.
public final class CommandHistoryManager: @unchecked Sendable {
    public static let shared = CommandHistoryManager()
    
    public let maxHistoryCapacity: Int
    private var records: [ArchiveTaskRecord] = []
    
    private var undoStack: [ArchiveCommandProtocol] = []
    private var redoStack: [ArchiveCommandProtocol] = []
    private let lock = NSLock()
    private var currentOperationTask: Task<Void, Never>? = nil
    
    public init(maxHistoryCapacity: Int = 50) {
        self.maxHistoryCapacity = maxHistoryCapacity
    }
    
    private func chainTask<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) -> Task<T, Error> {
        lock.lock()
        defer { lock.unlock() }
        let previousTask = currentOperationTask
        
        let newTask = Task<T, Error> {
            _ = await previousTask?.result
            return try await block()
        }
        
        currentOperationTask = Task {
            _ = await newTask.result
        }
        
        return newTask
    }
    
    private func runSerialized<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = chainTask(block)
        return try await task.value
    }
    
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !undoStack.isEmpty
    }
    
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    public var undoStackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count
    }
    
    public var redoStackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.count
    }
    
    public var undoHistoryDescriptions: [String] {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.map { $0.description }
    }
    
    public var redoHistoryDescriptions: [String] {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.map { $0.description }
    }
    
    public func getHistoryRecords() throws -> [ArchiveTaskRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }
    
    public func getRecentHistoryRecords(limit: Int) throws -> [ArchiveTaskRecord] {
        lock.lock()
        defer { lock.unlock() }
        let sorted = records.sorted { $0.timestamp > $1.timestamp }
        return Array(sorted.prefix(limit))
    }
    
    /// Constructs `ArchiveTaskRecord` from command execution.
    public func makeRecord(for command: ArchiveCommandProtocol, isSuccess: Bool) -> ArchiveTaskRecord {
        return ArchiveTaskRecord(
            id: UUID(),
            commandName: command.description,
            archivePath: "archive_\(command.commandId.prefix(8)).zip",
            targetPath: "/tmp/TTZip/Output",
            isSuccess: isSuccess,
            timestamp: Date(),
            fileSizeByte: 1024
        )
    }
    
    /// Executes command and pushes to undo stack if supported, clearing redo branch.
    public func execute(command: ArchiveCommandProtocol) async throws -> CommandResult {
        try await runSerialized {
            let result = try await command.execute()
            
            self.clearRedoStack()
            if command.isUndoable {
                self.pushUndo(command)
            }
            
            let record = ArchiveTaskRecord(
                id: UUID(),
                commandName: command.description,
                archivePath: "archive_\(command.commandId.prefix(8)).zip",
                targetPath: "/tmp/TTZip/Output",
                isSuccess: result.success,
                timestamp: Date(),
                fileSizeByte: 1024
            )
            self.appendRecord(record)
            
            return result
        }
    }
    
    private func appendRecord(_ record: ArchiveTaskRecord) {
        lock.lock()
        defer { lock.unlock() }
        records.append(record)
        if records.count > maxHistoryCapacity {
            records.removeFirst()
        }
    }
    
    /// Reverts the most recently executed command.
    @discardableResult
    public func undo() async throws -> CommandResult? {
        try await runSerialized {
            guard let command = self.popUndo() else {
                return nil
            }
            
            do {
                try await command.undo()
                self.pushRedo(command)
                
                return CommandResult(
                    commandId: command.commandId,
                    success: true,
                    message: "Successfully reverted: [\(command.description)]"
                )
            } catch {
                self.restoreUndoOnFailure(command)
                throw error
            }
        }
    }
    
    /// Re-executes the most recently reverted command.
    @discardableResult
    public func redo() async throws -> CommandResult? {
        try await runSerialized {
            guard let command = self.popRedo() else {
                return nil
            }
            
            do {
                let result = try await command.execute()
                self.pushUndo(command)
                return result
            } catch {
                self.restoreRedoOnFailure(command)
                throw error
            }
        }
    }
    
    /// Clears undo/redo stacks and purges associated disk backup resources.
    public func clearHistory() {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        discarded.append(contentsOf: undoStack)
        discarded.append(contentsOf: redoStack)
        undoStack.removeAll()
        redoStack.removeAll()
        records.removeAll()
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func pushUndo(_ command: ArchiveCommandProtocol) {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        undoStack.append(command)
        discarded.append(contentsOf: redoStack)
        redoStack.removeAll()
        
        while undoStack.count > maxHistoryCapacity {
            discarded.append(undoStack.removeFirst())
        }
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    private func clearRedoStack() {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        discarded.append(contentsOf: redoStack)
        redoStack.removeAll()
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    private func popUndo() -> ArchiveCommandProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.popLast()
    }
    
    private func pushRedo(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        redoStack.append(command)
    }
    
    private func popRedo() -> ArchiveCommandProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.popLast()
    }
    
    private func restoreUndoOnFailure(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        undoStack.append(command)
    }
    
    private func restoreRedoOnFailure(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        redoStack.append(command)
    }
}
