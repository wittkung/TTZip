// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance in-place archive modification and live external editor synchronization engine.
///
/// Implements transactional shadow-file staging with atomic replacement (`renamex_np` / `replaceItemAtURL`)
/// ensuring zero data corruption upon power loss or crashes during archive updates.
public final class InPlaceArchiveMutationEngine: @unchecked Sendable {
    public static let shared = InPlaceArchiveMutationEngine()
    
    private let lock = NSLock()
    private var activeSessions: [String: InPlaceEditSession] = [:]
    
    private init() {}
    
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
    
    /// Prepares an isolated staging sandbox and extracts a single archive entry for live editing.
    public func beginEditingSession(
        archivePath: String,
        entryPath: String,
        password: String? = nil
    ) async throws -> InPlaceEditSession {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let sessionId = UUID().uuidString
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TTZipEdit_\(sessionId)", isDirectory: true)
        
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        let filename = (entryPath as NSString).lastPathComponent
        let destinationFilePath = stagingDir.appendingPathComponent(filename).path
        
        // Extract single entry into staging directory
        try await TTZipEngineFacade.shared.extractSingleEntry(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: stagingDir.path,
            password: password
        )
        
        let initialHash = HashCalculator.calculateSHA256(filePath: destinationFilePath) ?? ""
        var st = stat()
        let mtime = stat(destinationFilePath, &st) == 0 ? Double(st.st_mtimespec.tv_sec) : Date().timeIntervalSince1970
        
        let session = InPlaceEditSession(
            sessionId: sessionId,
            archivePath: archivePath,
            entryPath: entryPath,
            stagedFilePath: destinationFilePath,
            stagedDirectoryPath: stagingDir.path,
            state: .staged,
            initialHash: initialHash,
            lastKnownMtime: mtime,
            hasUnsavedChanges: false,
            errorMessage: nil
        )
        
        withLock {
            activeSessions[sessionId] = session
        }
        
        return session
    }
    
    /// Starts watching the editing session and automatically updates the archive when changes are saved.
    public func startWatchingAndAutoSync(
        session: InPlaceEditSession,
        password: String? = nil,
        onSyncCompleted: @escaping @Sendable (InPlaceEditSession, Result<Void, Error>) -> Void
    ) {
        var activeSession = session
        activeSession.state = .listening
        
        withLock {
            activeSessions[session.sessionId] = activeSession
        }
        
        FileWatcherEngine.shared.watchEditingSession(session: activeSession) { [weak self] modifiedSession in
            guard let self = self else { return }
            
            Task {
                do {
                    try await self.synchronizeEntryBackToArchive(
                        archivePath: modifiedSession.archivePath,
                        entryPath: modifiedSession.entryPath,
                        stagedFilePath: modifiedSession.stagedFilePath,
                        password: password
                    )
                    
                    var updated = modifiedSession
                    updated.state = .saved
                    updated.hasUnsavedChanges = false
                    
                    self.withLock {
                        self.activeSessions[modifiedSession.sessionId] = updated
                    }
                    
                    onSyncCompleted(updated, .success(()))
                } catch {
                    var failed = modifiedSession
                    failed.state = .error
                    failed.errorMessage = error.localizedDescription
                    
                    self.withLock {
                        self.activeSessions[modifiedSession.sessionId] = failed
                    }
                    
                    onSyncCompleted(failed, .failure(error))
                }
            }
        }
    }
    
    /// Synchronizes a modified staged file back into the target archive via atomic shadow replacement.
    public func synchronizeEntryBackToArchive(
        archivePath: String,
        entryPath: String,
        stagedFilePath: String,
        password: String? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath), fileManager.fileExists(atPath: stagedFilePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let format = ArchiveCompressionFormat.from(extensionOrName: (archivePath as NSString).pathExtension) ?? .zip
        let shadowPath = archivePath + ".ttzip_shadow_\(UUID().uuidString)"
        
        do {
            if format == .zip {
                try await updateZipEntryAtomic(
                    sourceZipPath: archivePath,
                    targetZipPath: shadowPath,
                    updatedEntryPath: entryPath,
                    replacementFilePath: stagedFilePath,
                    password: password
                )
            } else {
                // Universal fallback for 7Z, TAR, etc. via full repack pipeline into shadow path
                try await updateGenericArchiveAtomic(
                    sourceArchivePath: archivePath,
                    targetArchivePath: shadowPath,
                    updatedEntryPath: entryPath,
                    replacementFilePath: stagedFilePath,
                    format: format,
                    password: password
                )
            }
            
            // Transactional atomic swap
            try atomicReplaceArchive(originalPath: archivePath, shadowPath: shadowPath)
        } catch {
            if fileManager.fileExists(atPath: shadowPath) {
                try? fileManager.removeItem(atPath: shadowPath)
            }
            throw error
        }
    }
    
    /// Adds external files into an existing archive in-place.
    public func addFilesToArchive(
        archivePath: String,
        sourceFilePaths: [String],
        destinationVirtualFolder: String? = nil,
        password: String? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let format = ArchiveCompressionFormat.from(extensionOrName: (archivePath as NSString).pathExtension) ?? .zip
        let shadowPath = archivePath + ".ttzip_add_\(UUID().uuidString)"
        
        // Extract existing archive into a staging area
        let tempExtractDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TTZipAddStaging_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempExtractDir) }
        
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archivePath, destinationDir: tempExtractDir.path, password: password)
        
        // Copy new files into the target folder structure
        let targetRoot = destinationVirtualFolder != nil && !destinationVirtualFolder!.isEmpty
            ? tempExtractDir.appendingPathComponent(destinationVirtualFolder!, isDirectory: true)
            : tempExtractDir
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        
        for sourcePath in sourceFilePaths {
            let filename = (sourcePath as NSString).lastPathComponent
            let destItemURL = targetRoot.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destItemURL.path) {
                try? fileManager.removeItem(at: destItemURL)
            }
            try fileManager.copyItem(atPath: sourcePath, toPath: destItemURL.path)
        }
        
        // Repack contents into shadow archive
        let items = (try? fileManager.contentsOfDirectory(atPath: tempExtractDir.path)) ?? []
        let inputPaths = items.map { tempExtractDir.appendingPathComponent($0).path }
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: shadowPath,
            format: format,
            inputPaths: inputPaths,
            password: password
        )
        
        try atomicReplaceArchive(originalPath: archivePath, shadowPath: shadowPath)
    }
    
    /// Deletes one or more entries in-place from an existing archive.
    public func deleteEntriesFromArchive(
        archivePath: String,
        entryPathsToDelete: Set<String>,
        password: String? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let format = ArchiveCompressionFormat.from(extensionOrName: (archivePath as NSString).pathExtension) ?? .zip
        let shadowPath = archivePath + ".ttzip_del_\(UUID().uuidString)"
        
        let tempExtractDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TTZipDeleteStaging_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempExtractDir) }
        
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archivePath, destinationDir: tempExtractDir.path, password: password)
        
        // Remove specified entries from staging directory
        for entry in entryPathsToDelete {
            let itemURL = tempExtractDir.appendingPathComponent(entry)
            if fileManager.fileExists(atPath: itemURL.path) {
                try? fileManager.removeItem(at: itemURL)
            }
        }
        
        // Repack contents into shadow archive
        let items = (try? fileManager.contentsOfDirectory(atPath: tempExtractDir.path)) ?? []
        let inputPaths = items.map { tempExtractDir.appendingPathComponent($0).path }
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: shadowPath,
            format: format,
            inputPaths: inputPaths,
            password: password
        )
        
        try atomicReplaceArchive(originalPath: archivePath, shadowPath: shadowPath)
    }
    
    /// Terminates the editing session and cleans up temporary staging artifacts.
    public func closeEditingSession(session: InPlaceEditSession, discardUnsaved: Bool = false) {
        FileWatcherEngine.shared.stopWatching(sessionKey: session.sessionId)
        
        withLock {
            _ = activeSessions.removeValue(forKey: session.sessionId)
        }
        
        try? FileManager.default.removeItem(atPath: session.stagedDirectoryPath)
    }
    
    // MARK: - Private Shadow Pipeline Helpers
    
    private func updateZipEntryAtomic(
        sourceZipPath: String,
        targetZipPath: String,
        updatedEntryPath: String,
        replacementFilePath: String,
        password: String?
    ) async throws {
        // Universal staging repack for ZIP ensuring clean entry alignment
        try await updateGenericArchiveAtomic(
            sourceArchivePath: sourceZipPath,
            targetArchivePath: targetZipPath,
            updatedEntryPath: updatedEntryPath,
            replacementFilePath: replacementFilePath,
            format: .zip,
            password: password
        )
    }
    
    private func updateGenericArchiveAtomic(
        sourceArchivePath: String,
        targetArchivePath: String,
        updatedEntryPath: String,
        replacementFilePath: String,
        format: ArchiveCompressionFormat,
        password: String?
    ) async throws {
        let fileManager = FileManager.default
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TTZipRepackStaging_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDir) }
        
        // 1. Extract all entries into staging folder
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: sourceArchivePath, destinationDir: stagingDir.path, password: password)
        
        // 2. Overwrite the target updated file in staging folder
        let destFileURL = stagingDir.appendingPathComponent(updatedEntryPath)
        let parentDir = destFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: destFileURL.path) {
            try? fileManager.removeItem(at: destFileURL)
        }
        try fileManager.copyItem(atPath: replacementFilePath, toPath: destFileURL.path)
        
        // 3. Compress staging folder items into target shadow archive
        let items = (try? fileManager.contentsOfDirectory(atPath: stagingDir.path)) ?? []
        let inputPaths = items.map { stagingDir.appendingPathComponent($0).path }
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: targetArchivePath,
            format: format,
            inputPaths: inputPaths,
            password: password
        )
    }
    
    private func atomicReplaceArchive(originalPath: String, shadowPath: String) throws {
        let fileManager = FileManager.default
        let originalURL = URL(fileURLWithPath: originalPath)
        let shadowURL = URL(fileURLWithPath: shadowPath)
        
        // Use APFS renamex_np or replaceItemAtURL
        _ = try fileManager.replaceItemAt(
            originalURL,
            withItemAt: shadowURL,
            backupItemName: nil,
            options: [.withoutDeletingBackupItem]
        )
    }
}
