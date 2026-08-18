// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Core memento state snapshot protocol (Memento Pattern).
public protocol ArchiveMementoProtocol: Sendable {
    var id: UUID { get }
    var timestamp: Date { get }
}

/// Originator protocol creating and restoring state snapshots.
public protocol ArchiveOriginatorProtocol {
    associatedtype Memento: ArchiveMementoProtocol
    
    /// Creates a memento snapshot of current state.
    func createMemento() -> Memento
    
    /// Restores internal state from a memento snapshot.
    func restoreMemento(_ memento: Memento)
}

/// Caretaker protocol managing undo/redo stacks of mementos.
public protocol ArchiveCaretakerProtocol {
    associatedtype Memento: ArchiveMementoProtocol
    
    /// Saves state snapshot.
    func saveMemento(_ memento: Memento)
    
    /// Reverts to preceding state snapshot.
    func undo() -> Memento?
    
    /// Re-applies subsequent state snapshot.
    func redo() -> Memento?
    
    var canUndo: Bool { get }
    var canRedo: Bool { get }
}
