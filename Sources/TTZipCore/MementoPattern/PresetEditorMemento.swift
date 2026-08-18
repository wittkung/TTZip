// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Preset editor draft state snapshot memento.
public struct PresetEditorMemento: ArchiveMementoProtocol, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    
    public let presetID: UUID
    public let name: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let splitVolumeSizeBytes: Int64?
    public let skipMacJunk: Bool
    public let skipGitDirectory: Bool
    public let defaultPassword: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        presetID: UUID,
        name: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        splitVolumeSizeBytes: Int64? = nil,
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false,
        defaultPassword: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.presetID = presetID
        self.name = name
        self.format = format
        self.level = level
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        self.skipMacJunk = skipMacJunk
        self.skipGitDirectory = skipGitDirectory
        self.defaultPassword = defaultPassword
    }
}

/// Caretaker managing undo/redo history for compression preset editing drafts.
public final class PresetEditorCaretaker: ArchiveCaretakerProtocol, @unchecked Sendable {
    private var undoStack: [PresetEditorMemento] = []
    private var redoStack: [PresetEditorMemento] = []
    private let lock = NSRecursiveLock()
    
    public var maxDepth: Int
    
    public init(maxDepth: Int = 50) {
        self.maxDepth = maxDepth
    }
    
    public func saveMemento(_ memento: PresetEditorMemento) {
        lock.lock()
        defer { lock.unlock() }
        
        if let top = undoStack.last, top == memento {
            return
        }
        
        undoStack.append(memento)
        redoStack.removeAll()
        
        if undoStack.count > maxDepth {
            undoStack.removeFirst(undoStack.count - maxDepth)
        }
    }
    
    public func undo() -> PresetEditorMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard undoStack.count > 1 else { return nil }
        let current = undoStack.removeLast()
        redoStack.append(current)
        return undoStack.last
    }
    
    public func redo() -> PresetEditorMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(next)
        return next
    }
    
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count > 1
    }
    
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    public func peekUndo() -> PresetEditorMemento? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.last
    }
    
    public func peekRedo() -> PresetEditorMemento? {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.last
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    public var historyCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count
    }
}
