// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-level in-place archive mutation and live editing coordinator.
public final class InPlaceArchiveMutationEngine: @unchecked Sendable {
    public static let shared = InPlaceArchiveMutationEngine()
    
    private let lock = NSLock()
    private var activeSessions: [String: InPlaceEditSession] = [:]
    
    private init() {}
    
    /// Begins a live in-place editing session by extracting target entry to an isolated temporary staging file.
    public func beginEditingSession(
        archivePath: String,
        entryPath: String,
        password: String? = nil
    ) async throws -> InPlaceEditSession {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZip_Edit_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sanitizedEntryName = (entryPath as NSString).lastPathComponent
        let stagedFile = tempDir.appendingPathComponent(sanitizedEntryName)
        
        _ = try await TTZipEngineFacade.shared.quickExtract(
            archivePath: archivePath,
            destinationDir: tempDir.path,
            password: password
        )
        
        let session = InPlaceEditSession(
            archivePath: archivePath,
            entryPath: entryPath,
            stagedFilePath: stagedFile.path,
            stagedDirectoryPath: tempDir.path,
            state: .active,
            initialHash: HashCalculator.calculateSHA256(filePath: stagedFile.path) ?? "",
            lastKnownMtime: (try? FileManager.default.attributesOfItem(atPath: stagedFile.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        )
        
        setSession(session)
        return session
    }
    
    /// Starts watching an active editing session and auto-syncs modifications back into the archive.
    public func startWatchingAndAutoSync(
        session: InPlaceEditSession,
        password: String? = nil,
        onSyncCompleted: (@Sendable (InPlaceEditSession, Result<Void, Error>) -> Void)? = nil
    ) {
        FileWatcherEngine.shared.watchEditingSession(session: session) { [weak self] updatedSession in
            Task {
                do {
                    try await self?.syncModifiedFile(session: updatedSession, password: password)
                    onSyncCompleted?(updatedSession, .success(()))
                } catch {
                    onSyncCompleted?(updatedSession, .failure(error))
                }
            }
        }
    }
    
    /// Syncs modified staged file back into the target archive.
    public func syncModifiedFile(session: InPlaceEditSession, password: String? = nil) async throws {
        guard FileManager.default.fileExists(atPath: session.stagedFilePath) else { return }
        
        try await addFilesToArchive(
            archivePath: session.archivePath,
            sourceFilePaths: [session.stagedFilePath],
            destinationVirtualFolder: (session.entryPath as NSString).deletingLastPathComponent,
            password: password
        )
    }
    
    /// Adds files into an existing archive using in-place mutation or transactional repacking.
    public func addFilesToArchive(
        archivePath: String,
        sourceFilePaths: [String],
        destinationVirtualFolder: String? = nil,
        password: String? = nil
    ) async throws {
        guard !sourceFilePaths.isEmpty else { return }
        
        var outSession: OpaquePointer?
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            ttzip_rust_inplace_session_begin(cPath, 1, &outSession)
        }
        
        if status == TTZIP_STATUS_OK, let session = outSession {
            defer { ttzip_rust_inplace_session_free(session) }
            for src in sourceFilePaths {
                let entryName = (src as NSString).lastPathComponent
                _ = CUnsafeBufferAdapter.withCString(src) { cSrc in
                    CUnsafeBufferAdapter.withCString(entryName) { cEntry in
                        ttzip_rust_inplace_session_append(session, cEntry, cSrc)
                    }
                }
            }
            _ = ttzip_rust_inplace_session_commit(session)
        }
    }
    
    /// Deletes specific entries from inside an existing archive.
    public func deleteEntriesFromArchive(
        archivePath: String,
        entryPathsToDelete: [String],
        password: String? = nil
    ) async throws {
        guard !entryPathsToDelete.isEmpty else { return }
        
        var outSession: OpaquePointer?
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            ttzip_rust_inplace_session_begin(cPath, 1, &outSession)
        }
        
        if status == TTZIP_STATUS_OK, let session = outSession {
            defer { ttzip_rust_inplace_session_free(session) }
            for entryPath in entryPathsToDelete {
                _ = CUnsafeBufferAdapter.withCString(entryPath) { cEntry in
                    ttzip_rust_inplace_session_delete(session, cEntry)
                }
            }
            _ = ttzip_rust_inplace_session_commit(session)
        }
    }
    
    /// Closes and cleans up an in-place editing session and its temporary directory.
    public func closeEditingSession(session: InPlaceEditSession) {
        removeSession(sessionId: session.sessionId)
        try? FileManager.default.removeItem(atPath: session.stagedDirectoryPath)
    }
    
    private func setSession(_ session: InPlaceEditSession) {
        lock.lock()
        defer { lock.unlock() }
        activeSessions[session.sessionId] = session
    }
    
    private func removeSession(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        activeSessions.removeValue(forKey: sessionId)
    }
}

// MARK: - In-Place Edit Session

//
//


/// State of an in-place editing session.
public enum InPlaceEditState: String, Sendable, Codable {
    case active
    case syncing
    case completed
    case failed
}

/// In-place editing session data model for tracking live temporary files.
public struct InPlaceEditSession: Sendable, Identifiable, Equatable {
    public var id: String { sessionId }
    public let sessionId: String
    public let archivePath: String
    public let entryPath: String
    public let stagedFilePath: String
    public let stagedDirectoryPath: String
    public var state: InPlaceEditState
    public var initialHash: String
    public var lastKnownMtime: Double
    public var hasUnsavedChanges: Bool
    public var errorMessage: String?
    
    public init(
        sessionId: String = UUID().uuidString,
        archivePath: String,
        entryPath: String,
        stagedFilePath: String,
        stagedDirectoryPath: String,
        state: InPlaceEditState = .active,
        initialHash: String = "",
        lastKnownMtime: Double = Date().timeIntervalSince1970,
        hasUnsavedChanges: Bool = false,
        errorMessage: String? = nil
    ) {
        self.sessionId = sessionId
        self.archivePath = archivePath
        self.entryPath = entryPath
        self.stagedFilePath = stagedFilePath
        self.stagedDirectoryPath = stagedDirectoryPath
        self.state = state
        self.initialHash = initialHash
        self.lastKnownMtime = lastKnownMtime
        self.hasUnsavedChanges = hasUnsavedChanges
        self.errorMessage = errorMessage
    }
}
