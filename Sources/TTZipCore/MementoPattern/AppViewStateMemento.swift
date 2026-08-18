// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Workspace navigation tab classification.
public enum WorkspaceTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case home = "home"
    case compressWorkspace = "compressWorkspace"
    case presets = "presets"
    case benchmark = "benchmark"
    case vault = "vault"
    case settings = "settings"
    
    public var id: String { rawValue }
}

/// GUI workspace state snapshot memento.
public struct AppViewStateMemento: ArchiveMementoProtocol, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    
    public let activeTab: WorkspaceTab
    public let currentArchivePath: String?
    public let selectedPresetID: UUID?
    public let searchQuery: String
    public let isSidebarExpanded: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        activeTab: WorkspaceTab = .home,
        currentArchivePath: String? = nil,
        selectedPresetID: UUID? = nil,
        searchQuery: String = "",
        isSidebarExpanded: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.activeTab = activeTab
        self.currentArchivePath = currentArchivePath
        self.selectedPresetID = selectedPresetID
        self.searchQuery = searchQuery
        self.isSidebarExpanded = isSidebarExpanded
    }
}

/// Caretaker managing undo/redo history for workspace layout state.
public final class AppViewStateCaretaker: ArchiveCaretakerProtocol, @unchecked Sendable {
    private var undoStack: [AppViewStateMemento] = []
    private var redoStack: [AppViewStateMemento] = []
    private let lock = NSRecursiveLock()
    
    public var maxDepth: Int
    
    public init(maxDepth: Int = 50) {
        self.maxDepth = maxDepth
    }
    
    public func saveMemento(_ memento: AppViewStateMemento) {
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
    
    public func undo() -> AppViewStateMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard undoStack.count > 1 else { return nil }
        let current = undoStack.removeLast()
        redoStack.append(current)
        return undoStack.last
    }
    
    public func redo() -> AppViewStateMemento? {
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
    
    public func peekUndo() -> AppViewStateMemento? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.last
    }
    
    public func peekRedo() -> AppViewStateMemento? {
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
    
    public var currentSnapshot: AppViewStateMemento? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.last
    }
}
