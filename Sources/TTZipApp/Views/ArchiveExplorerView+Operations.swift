// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

extension ArchiveExplorerView {
    
    // MARK: - In-Place Live Editing & Mutation Operations
    
    func openSelectedInExternalEditor(_ entry: ArchiveEntry) {
        Task {
            do {
                let session = try await InPlaceArchiveMutationEngine.shared.beginEditingSession(
                    archivePath: archivePath,
                    entryPath: entry.path,
                    password: password
                )
                
                await MainActor.run {
                    self.activeEditSessions[session.sessionId] = session
                    self.syncStatusMessage = "Watching '\(entry.name)' for external changes..."
                }
                
                // Open in default macOS application
                NSWorkspace.shared.open(URL(fileURLWithPath: session.stagedFilePath))
                
                // Start auto sync
                InPlaceArchiveMutationEngine.shared.startWatchingAndAutoSync(
                    session: session,
                    password: password
                ) { updatedSession, result in
                    Task { @MainActor in
                        switch result {
                        case .success:
                            self.syncStatusMessage = "⚡️ Saved & updated '\(entry.name)' in archive"
                            self.reloadArchiveEntries()
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if self.syncStatusMessage?.contains(entry.name) == true {
                                self.syncStatusMessage = nil
                            }
                        case .failure(let err):
                            self.syncStatusMessage = "❌ Sync failed: \(err.localizedDescription)"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncStatusMessage = "Error opening: \(error.localizedDescription)"
                }
            }
        }
    }
    
    final class PathAccumulator: @unchecked Sendable {
        private var paths: [String] = []
        private let lock = NSLock()
        
        func append(_ path: String) {
            lock.lock()
            paths.append(path)
            lock.unlock()
        }
        
        var allPaths: [String] {
            lock.lock()
            defer { lock.unlock() }
            return paths
        }
    }
    
    func handleDropFiles(providers: [NSItemProvider]) {
        let accumulator = PathAccumulator()
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.isFileURL {
                    accumulator.append(url.path)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let paths = accumulator.allPaths
            guard !paths.isEmpty else { return }
            self.isMutatingArchive = true
            self.syncStatusMessage = "Adding \(paths.count) items into archive..."
            
            Task {
                do {
                    try await InPlaceArchiveMutationEngine.shared.addFilesToArchive(
                        archivePath: self.archivePath,
                        sourceFilePaths: paths,
                        destinationVirtualFolder: nil,
                        password: self.password
                    )
                    await MainActor.run {
                        self.isMutatingArchive = false
                        self.syncStatusMessage = "Archive updated successfully"
                        self.reloadArchiveEntries()
                    }
                } catch {
                    await MainActor.run {
                        self.isMutatingArchive = false
                        self.syncStatusMessage = "Failed to add items: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func deleteSelectedEntry(_ entry: ArchiveEntry) {
        isMutatingArchive = true
        syncStatusMessage = "Deleting '\(entry.name)' from archive..."
        
        Task {
            do {
                try await InPlaceArchiveMutationEngine.shared.deleteEntriesFromArchive(
                    archivePath: archivePath,
                    entryPathsToDelete: [entry.path],
                    password: password
                )
                await MainActor.run {
                    self.isMutatingArchive = false
                    self.syncStatusMessage = "Deleted '\(entry.name)'"
                    self.selectedEntryID = nil
                    self.reloadArchiveEntries()
                }
            } catch {
                await MainActor.run {
                    self.isMutatingArchive = false
                    self.syncStatusMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func reloadArchiveEntries() {
        Task {
            let reader = ArchiveReader()
            if let newEntries = try? await reader.inspect(archivePath: archivePath, password: password) {
                await MainActor.run {
                    self.entries = newEntries
                    self.treeStore.updateEntries(newEntries, force: true)
                }
            }
        }
    }
    
    func moveSelectionUp() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx > 0 {
                selectedEntryID = currentList[idx - 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveUp, object: nil)
        }
    }
    
    func moveSelectionDown() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx < currentList.count - 1 {
                selectedEntryID = currentList[idx + 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveDown, object: nil)
        }
    }
    
    func extractSelectedForPreview(entryID: String?) {
        previewTask?.cancel()
        if let oldTempDir = currentTempDir {
            try? FileManager.default.removeItem(at: oldTempDir)
            currentTempDir = nil
        }
        
        guard let entryID = entryID,
              let entry = entries.first(where: { $0.id == entryID || $0.path == entryID }),
              !entry.isDirectory else {
            previewFileURL = nil
            return
        }
        
        let filename = (entry.path as NSString).lastPathComponent
        isExtractingTemp = true
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipPreview_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        currentTempDir = tempDir
        
        previewTask = Task {
            do {
                try await TTZipEngineFacade.shared.extractSingleEntry(
                    archivePath: archivePath,
                    entryPath: entry.path,
                    destinationDir: tempDir.path,
                    password: password
                )
                guard !Task.isCancelled else { return }
                let expectedFileURL = tempDir.appendingPathComponent(filename)
                await MainActor.run {
                    self.previewFileURL = expectedFileURL
                    self.isExtractingTemp = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.previewFileURL = nil
                    self.isExtractingTemp = false
                }
            }
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
