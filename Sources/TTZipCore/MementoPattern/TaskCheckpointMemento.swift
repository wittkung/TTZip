// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Task checkpoint state snapshot memento recording execution metrics for long-running operations.
public struct TaskCheckpointMemento: ArchiveMementoProtocol, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    
    public let taskID: UUID
    public let taskName: String
    public let stateName: String
    public let processedBytes: Int64
    public let totalBytes: Int64
    public let dictionaryOffset: Int64
    public let throughputTPS: Double
    public let checksum: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskID: UUID,
        taskName: String,
        stateName: String,
        processedBytes: Int64,
        totalBytes: Int64,
        dictionaryOffset: Int64,
        throughputTPS: Double = 0.0,
        checksum: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
        self.taskName = taskName
        self.stateName = stateName
        self.processedBytes = processedBytes
        self.totalBytes = totalBytes
        self.dictionaryOffset = dictionaryOffset
        self.throughputTPS = throughputTPS
        self.checksum = checksum
    }
}

/// Task checkpoint caretaker persisting state snapshots to disk for crash recovery and resume capabilities.
public final class TaskCheckpointCaretaker: ArchiveCaretakerProtocol, @unchecked Sendable {
    private var historyStack: [TaskCheckpointMemento] = []
    private var redoStack: [TaskCheckpointMemento] = []
    private let lock = NSRecursiveLock()
    
    public let checkpointsDirectory: URL
    public var maxDepth: Int
    
    public init(customDirectory: URL? = nil, maxDepth: Int = 50) {
        self.maxDepth = maxDepth
        if let customDir = customDirectory {
            self.checkpointsDirectory = customDir
        } else {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.checkpointsDirectory = cachesDir.appendingPathComponent("TTZip/Checkpoints", isDirectory: true)
        }
        ensureDirectoryExists()
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: checkpointsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func saveMemento(_ memento: TaskCheckpointMemento) {
        saveCheckpoint(memento)
    }
    
    /// Persists task checkpoint to memory history and atomic disk JSON.
    public func saveCheckpoint(_ memento: TaskCheckpointMemento) {
        lock.lock()
        defer { lock.unlock() }
        
        historyStack.append(memento)
        redoStack.removeAll()
        
        if historyStack.count > maxDepth {
            historyStack.removeFirst(historyStack.count - maxDepth)
        }
        
        persistToDisk(memento)
    }
    
    private func checkpointFileURL(taskID: UUID) -> URL {
        checkpointsDirectory.appendingPathComponent("checkpoint_\(taskID.uuidString).json")
    }
    
    private func persistToDisk(_ memento: TaskCheckpointMemento) {
        ensureDirectoryExists()
        let fileURL = checkpointFileURL(taskID: memento.taskID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(memento)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort checkpoint write
        }
    }
    
    /// Loads checkpoint for specified taskID from disk.
    public func loadCheckpoint(taskID: UUID) -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = checkpointFileURL(taskID: taskID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let memento = try decoder.decode(TaskCheckpointMemento.self, from: data)
            return memento
        } catch {
            return nil
        }
    }
    
    /// Deletes task checkpoint file from disk.
    public func deleteCheckpoint(taskID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = checkpointFileURL(taskID: taskID)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Lists all persisted checkpoints on disk ordered by timestamp descending.
    public func listCheckpoints() -> [TaskCheckpointMemento] {
        lock.lock()
        defer { lock.unlock() }
        
        ensureDirectoryExists()
        guard let files = try? FileManager.default.contentsOfDirectory(at: checkpointsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var results: [TaskCheckpointMemento] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file),
               let memento = try? decoder.decode(TaskCheckpointMemento.self, from: data) {
                results.append(memento)
            }
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func undo() -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard historyStack.count > 1 else { return nil }
        let current = historyStack.removeLast()
        redoStack.append(current)
        return historyStack.last
    }
    
    public func redo() -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let next = redoStack.popLast() else { return nil }
        historyStack.append(next)
        return next
    }
    
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return historyStack.count > 1
    }
    
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    public func clearAllCheckpoints() {
        lock.lock()
        defer { lock.unlock() }
        
        historyStack.removeAll()
        redoStack.removeAll()
        
        if let files = try? FileManager.default.contentsOfDirectory(at: checkpointsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
