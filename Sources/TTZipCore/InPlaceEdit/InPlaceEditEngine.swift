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
/// Directly delegates append, replace, and delete operations to the native Rust transactional
/// in-place editing engine (`ttzip_rust_inplace_session_*`), guaranteeing atomic commits with zero
/// recompression of untouched container payload data.
public final class InPlaceEditEngine: @unchecked Sendable {
    public static let shared = InPlaceEditEngine()
    
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
    
    /// Synchronizes a modified staged file back into the target archive via Rust transactional C-ABI.
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
        
        let rawFmt = resolveRawFormat(for: archivePath)
        if (rawFmt == 2 || archivePath.hasSuffix(".7z")), let bin7z = SevenZipBinaryResolver.resolveBinaryPath() {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ttzip_7z_inplace_\(UUID().uuidString)")
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDir) }
            
            let destStagedFile = tempDir.appendingPathComponent(entryPath)
            let parentDir = destStagedFile.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try fileManager.copyItem(atPath: stagedFilePath, toPath: destStagedFile.path)
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin7z)
            proc.currentDirectoryURL = tempDir
            var args = ["u", archivePath, entryPath]
            if let p = password, !p.isEmpty {
                args.append("-p\(p)")
            }
            proc.arguments = args
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    return
                }
            }
        }
        
        try CUnsafeBufferAdapter.withCString(archivePath) { cArchive in
            try CUnsafeBufferAdapter.withCString(entryPath) { cEntry in
                try CUnsafeBufferAdapter.withCString(stagedFilePath) { cStaged in
                    guard let cArchive = cArchive, let cEntry = cEntry, let cStaged = cStaged else {
                        throw ArchiveError.fileNotFound
                    }
                    
                    var sessionPtr: OpaquePointer?
                    let beginStatus = ttzip_rust_inplace_session_begin(cArchive, rawFmt, &sessionPtr)
                    guard beginStatus == TTZIP_STATUS_OK, let session = sessionPtr else {
                        throw ArchiveError.invalidFormat
                    }
                    defer { ttzip_rust_inplace_session_free(session) }
                    
                    let replaceStatus = ttzip_rust_inplace_session_replace(session, cEntry, cStaged)
                    guard replaceStatus == TTZIP_STATUS_OK else {
                        throw ArchiveError.readFailed(code: -11)
                    }
                    
                    let commitStatus = ttzip_rust_inplace_session_commit(session)
                    guard commitStatus == TTZIP_STATUS_OK else {
                        throw ArchiveError.readFailed(code: -12)
                    }
                }
            }
        }
    }
    
    /// Adds external files into an existing archive in-place via Rust transactional C-ABI.
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
        guard !sourceFilePaths.isEmpty else { return }
        
        try CUnsafeBufferAdapter.withCString(archivePath) { cArchive in
            guard let cArchive = cArchive else { throw ArchiveError.fileNotFound }
            
            var sessionPtr: OpaquePointer?
            let rawFmt = resolveRawFormat(for: archivePath)
            
            let beginStatus = ttzip_rust_inplace_session_begin(cArchive, rawFmt, &sessionPtr)
            guard beginStatus == TTZIP_STATUS_OK, let session = sessionPtr else {
                throw ArchiveError.invalidFormat
            }
            defer { ttzip_rust_inplace_session_free(session) }
            
            for sourcePath in sourceFilePaths {
                guard fileManager.fileExists(atPath: sourcePath) else { continue }
                let filename = (sourcePath as NSString).lastPathComponent
                let entryPath: String
                if let folder = destinationVirtualFolder, !folder.isEmpty {
                    let trimmed = folder.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    entryPath = "\(trimmed)/\(filename)"
                } else {
                    entryPath = filename
                }
                
                try CUnsafeBufferAdapter.withCString(entryPath) { cEntry in
                    try CUnsafeBufferAdapter.withCString(sourcePath) { cSrc in
                        guard let cEntry = cEntry, let cSrc = cSrc else { return }
                        let appStatus = ttzip_rust_inplace_session_append(session, cEntry, cSrc)
                        if appStatus != TTZIP_STATUS_OK {
                            throw ArchiveError.readFailed(code: -12)
                        }
                    }
                }
            }
            
            let commitStatus = ttzip_rust_inplace_session_commit(session)
            guard commitStatus == TTZIP_STATUS_OK else {
                throw ArchiveError.readFailed(code: -12)
            }
        }
    }
    
    /// Deletes one or more entries in-place from an existing archive via Rust transactional C-ABI.
    public func deleteEntriesFromArchive(
        archivePath: String,
        entryPathsToDelete: Set<String>,
        password: String? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        guard !entryPathsToDelete.isEmpty else { return }
        
        try CUnsafeBufferAdapter.withCString(archivePath) { cArchive in
            guard let cArchive = cArchive else { throw ArchiveError.fileNotFound }
            
            var sessionPtr: OpaquePointer?
            let rawFmt = resolveRawFormat(for: archivePath)
            
            let beginStatus = ttzip_rust_inplace_session_begin(cArchive, rawFmt, &sessionPtr)
            guard beginStatus == TTZIP_STATUS_OK, let session = sessionPtr else {
                throw ArchiveError.invalidFormat
            }
            defer { ttzip_rust_inplace_session_free(session) }
            
            for entryPath in entryPathsToDelete {
                try CUnsafeBufferAdapter.withCString(entryPath) { cEntry in
                    guard let cEntry = cEntry else { return }
                    let delStatus = ttzip_rust_inplace_session_delete(session, cEntry)
                    if delStatus != TTZIP_STATUS_OK {
                        throw ArchiveError.invalidFormat
                    }
                }
            }
            
            let commitStatus = ttzip_rust_inplace_session_commit(session)
            guard commitStatus == TTZIP_STATUS_OK else {
                throw ArchiveError.readFailed(code: -12)
            }
        }
    }
    
    /// Terminates the editing session and cleans up temporary staging artifacts.
    public func closeEditingSession(session: InPlaceEditSession, discardUnsaved: Bool = false) {
        FileWatcherEngine.shared.stopWatching(sessionKey: session.sessionId)
        
        withLock {
            _ = activeSessions.removeValue(forKey: session.sessionId)
        }
        
        try? FileManager.default.removeItem(atPath: session.stagedDirectoryPath)
    }
    
    // MARK: - Private Helpers
    
    private func resolveRawFormat(for path: String) -> Int32 {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "zip": return 1
        case "7z": return 2
        case "tar", "tgz", "gz", "bz2", "xz", "zst": return 3
        default: return 0
        }
    }
}

/// Backwards compatibility typealias.
public typealias InPlaceArchiveMutationEngine = InPlaceEditEngine
