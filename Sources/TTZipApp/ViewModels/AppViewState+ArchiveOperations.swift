// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension AppViewState {
    public func openArchiveAsFolder(url: URL) {
        self.activePreviewFileURL = nil
        self.activePreviewFileName = nil
        self.currentArchivePath = nil
        self.currentDirectory = url.deletingLastPathComponent()
        self.selectedDiskItem = DiskItemInfo(url: url)
        self.activeTab = .home
        self.addRecentArchive(path: url.path)
    }
    
    public func previewMediaFile(path: String) {
        let url = URL(fileURLWithPath: path)
        self.activePreviewFileURL = url
        self.activePreviewFileName = url.lastPathComponent
        self.activeTab = .home
    }
    
    public func closeMediaPreview() {
        self.activePreviewFileURL = nil
        self.activePreviewFileName = nil
    }
    
    public func quickExtractArchive(
        archivePath: String,
        targetDir: String? = nil,
        password: String? = nil,
        isSmartExtract: Bool = true,
        trashSourceAfterExtract: Bool = false
    ) async {
        let archiveURL = URL(fileURLWithPath: archivePath)
        let archiveName = archiveURL.deletingPathExtension().lastPathComponent
        let parentDir = targetDir ?? archiveURL.deletingLastPathComponent().path
        let parentURL = URL(fileURLWithPath: parentDir)
        
        let pwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        var destDir: String
        if isSmartExtract {
            let entries = (try? await ArchiveReader().inspect(archivePath: archivePath, password: pwd)) ?? []
            let smartRes = SmartExtractResolver.resolve(
                entryPaths: entries.map { $0.path },
                destinationParentURL: parentURL,
                archiveStemName: archiveName
            )
            destDir = smartRes.finalExtractionURL.path
        } else {
            destDir = (parentDir as NSString).appendingPathComponent(archiveName)
        }

        let stateMachine = createAndBindTaskStateMachine(taskName: "QuickExtract_\(archiveName)")
        try? stateMachine.start()
        
        await MainActor.run {
            self.statusMessage = "Extracting \(archiveName)..."
        }
        
        do {
            let res = try await SecurityProtectionProxy.shared.quickExtract(
                archivePath: archivePath,
                destinationDir: destDir,
                password: pwd,
                autoVaultUnlock: self.passwordVault.autoUnlockArchives
            )
            try? stateMachine.complete()
            await MainActor.run {
                if res.isVaultUnlocked, let pwd = res.unlockedPassword {
                    self.statusMessage = "Extracted with vault password: \(archiveName)"
                    ArchivePasswordStore.shared.setPassword(pwd, for: archivePath)
                } else {
                    self.statusMessage = "Extraction complete: \(archiveName)"
                }
                self.fileViewer.revealInFinder(at: destDir)
                if trashSourceAfterExtract {
                    try? FileManager.default.trashItem(at: archiveURL, resultingItemURL: nil)
                }
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Extraction failed: \(error.localizedDescription)"
                self.pendingEncryptedPath = archivePath
                self.showPasswordPrompt = true
            }
        }
    }

    public func extractSingleEntry(archivePath: String, entryPath: String, isDirectory: Bool, destinationDir: String) async {
        let name = (entryPath as NSString).lastPathComponent
        let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        await MainActor.run {
            self.statusMessage = "Extracting entry: \(name)..."
        }
        
        do {
            try await SecurityProtectionProxy.shared.extractSingleEntry(archivePath: archivePath, entryPath: entryPath, destinationDir: destinationDir, password: pwd)
            let targetExtractedFile = (destinationDir as NSString).appendingPathComponent(name)
            await MainActor.run {
                self.statusMessage = "Extracted entry: \(name)"
                self.fileViewer.revealInFinder(at: targetExtractedFile)
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Extraction failed: \(error.localizedDescription)"
            }
        }
    }
    
    @discardableResult
    public func loadArchive(path: String, password: String? = nil) async -> Bool {
        closeMediaPreview()
        isLoading = true
        statusMessage = "Reading archive metadata..."
        activeTab = .home
        
        do {
            let res = try await TTZipEngineFacade.shared.inspectArchiveCached(
                archivePath: path,
                password: password,
                autoVaultUnlock: self.passwordVault.autoUnlockArchives
            )
            self.currentArchivePath = path
            self.activePassword = res.unlockedPassword
            self.currentEntries = res.entries
            if let pwd = res.unlockedPassword, !pwd.isEmpty {
                self.statusMessage = "Unlocked with vault password"
            } else {
                self.statusMessage = "Loaded \(res.entries.count) entries"
            }
            self.isLoading = false
            self.showPasswordPrompt = false
            self.addRecentArchive(path: path)
            self.prefetchArchiveEntries(path: path, entries: res.entries, count: 16)
            NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: path)
            return true
        } catch {
            self.pendingEncryptedPath = path
            self.showPasswordPrompt = true
            self.statusMessage = "Archive is encrypted. Enter password to view contents."
            self.isLoading = false
            return false
        }
    }
    
    /// Prefetches initial or visible archive entries into the 16-way sharded VFS LZ4 cache pool.
    public func prefetchArchiveEntries(path: String, entries: [ArchiveEntry], count: Int = 16) {
        let candidates = Array(entries.filter { !$0.isDirectory && $0.uncompressedSize > 0 && $0.uncompressedSize <= 2 * 1024 * 1024 }.prefix(count))
        guard !candidates.isEmpty else { return }
        
        let pwd = self.activePassword
        Task.detached(priority: .background) {
            for entry in candidates {
                if VFSLz4CachePool.shared.getCachedEntry(archivePath: path, entryPath: entry.path) == nil {
                    if let data = try? await ArchiveSelectiveExtractor.shared.extractSingleEntryData(archivePath: path, entryPath: entry.path, password: pwd) {
                        VFSLz4CachePool.shared.cacheEntry(archivePath: path, entryPath: entry.path, data: data)
                    }
                }
            }
        }
    }
    
    /// Prefetches entries within a scrolling viewport window into the VFS cache pool.
    public func prefetchVisibleWindow(path: String, startIndex: Int, count: Int = 32) {
        let entries = self.currentEntries
        guard startIndex >= 0 && startIndex < entries.count else { return }
        let endIndex = min(entries.count, startIndex + count)
        let window = Array(entries[startIndex..<endIndex])
        prefetchArchiveEntries(path: path, entries: window, count: count)
    }
    
    /// Clears cached entries associated with the specified archive.
    public func clearArchiveVFSCache(path: String) {
        VFSLz4CachePool.shared.clearSession(sessionId: path)
    }
    
    public func addRecentArchive(path: String) {
        let record = RecentArchiveRecord(path: path)
        var updated = recentArchives.filter { $0.path != path }
        updated.insert(record, at: 0)
        if updated.count > 12 {
            updated = Array(updated.prefix(12))
        }
        recentArchives = updated
        saveRecentArchivesToStorage()
    }
    
    public func removeRecentArchive(path: String) {
        recentArchives.removeAll { $0.path == path }
        saveRecentArchivesToStorage()
    }
    
    func loadRecentArchivesFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: recentArchivesKey),
              let records = try? JSONDecoder().decode([RecentArchiveRecord].self, from: data) else {
            return
        }
        recentArchives = records.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    
    func saveRecentArchivesToStorage() {
        if let data = try? JSONEncoder().encode(recentArchives) {
            UserDefaults.standard.set(data, forKey: recentArchivesKey)
        }
    }
    
    public func cancelPasswordPrompt() {
        showPasswordPrompt = false
        pendingEncryptedPath = nil
        if currentEntries.isEmpty {
            currentArchivePath = nil
            activePassword = nil
            statusMessage = "Decryption cancelled"
        }
    }
    
    public func openCompressWorkspace(paths: [String] = []) {
        selectedPathsToCompress = paths
        activeTab = .compressWorkspace
    }
    
    public func reset() {
        if let path = currentArchivePath {
            VFSLz4CachePool.shared.clearSession(sessionId: path)
        }
        currentArchivePath = nil
        activePassword = nil
        currentEntries = []
        statusMessage = "Ready"
        isLoading = false
        activeTab = .home
    }
}
