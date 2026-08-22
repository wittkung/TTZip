// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension AppViewState {
    // MARK: - Command Undo / Redo
    
    public func updateUndoRedoState() {
        self.canUndo = historyManager.canUndo
        self.canRedo = historyManager.canRedo
        self.lastCommandDescription = historyManager.undoHistoryDescriptions.last
    }
    
    @discardableResult
    public func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult {
        guard !self.isLoading else {
            throw CommandError.invalidState(reason: "Another task is in progress.")
        }
        self.isLoading = true
        defer {
            self.isLoading = false
            updateUndoRedoState()
        }
        do {
            let result = try await historyManager.execute(command: command)
            self.statusMessage = "Command succeeded: [\(command.description)]"
            return result
        } catch {
            self.statusMessage = "Command failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    public func performUndo() {
        guard !self.isLoading && historyManager.canUndo else { return }
        self.isLoading = true
        Task { @MainActor in
            defer {
                self.isLoading = false
                self.updateUndoRedoState()
            }
            do {
                if let res = try await historyManager.undo() {
                    self.statusMessage = "Undone: \(res.message)"
                }
            } catch {
                self.statusMessage = "Undo failed: \(error.localizedDescription)"
            }
        }
    }
    
    public func performRedo() {
        guard !self.isLoading && historyManager.canRedo else { return }
        self.isLoading = true
        Task { @MainActor in
            defer {
                self.isLoading = false
                self.updateUndoRedoState()
            }
            do {
                if let res = try await historyManager.redo() {
                    self.statusMessage = "Redone: \(res.message)"
                }
            } catch {
                self.statusMessage = "Redo failed: \(error.localizedDescription)"
            }
        }
    }
}
