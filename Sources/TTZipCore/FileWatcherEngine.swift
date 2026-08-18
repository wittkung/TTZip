// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// In-archive live file editing and filesystem change observer engine.
///
/// Implements a robust Dual-Tier (File FD + Parent Directory) DispatchSource Watcher with 100~350ms debounce
/// to reliably detect both in-place file stream modifications and atomic "safe-saves" (inode swaps) by external editors
/// (TextEdit, VS Code, Xcode, Vim) without losing tracking.
public final class FileWatcherEngine: @unchecked Sendable {
    public static let shared = FileWatcherEngine()
    
    private struct ActiveWatchSession {
        let dirSource: DispatchSourceFileSystemObject?
        let dirFd: Int32?
        let fileSource: DispatchSourceFileSystemObject?
        let fileFd: Int32?
        let directoryPath: String
        let fileName: String
        let filePath: String
        let targetArchivePath: String
        let entryPath: String
        var debounceItem: DispatchWorkItem?
        var lastKnownHash: String?
        var lastKnownMtime: Double
    }
    
    private var activeSessions: [String: ActiveWatchSession] = [:]
    private let lock = NSLock()
    private let watchQueue = DispatchQueue(label: "com.ttzip.filewatcher", qos: .default)
    
    private init() {}
    
    /// Starts watching an active in-place editing session.
    public func watchEditingSession(
        session: InPlaceEditSession,
        onFileModified: @escaping @Sendable (InPlaceEditSession) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let sessionKey = session.sessionId
        if let existing = activeSessions.removeValue(forKey: sessionKey) {
            existing.debounceItem?.cancel()
            existing.dirSource?.cancel()
            existing.fileSource?.cancel()
        }
        
        let dirPath = session.stagedDirectoryPath
        let filePath = session.stagedFilePath
        let fileName = (filePath as NSString).lastPathComponent
        
        // 1. Directory Source (captures atomic renames and file additions/deletions)
        let dirFd = open(dirPath, O_EVTONLY)
        let dirSource: DispatchSourceFileSystemObject?
        if dirFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFd,
                eventMask: [.write, .extend, .attrib, .link, .rename],
                queue: watchQueue
            )
            src.setEventHandler { [weak self] in
                self?.handleFileSystemEvent(sessionKey: sessionKey, onFileModified: onFileModified)
            }
            src.setCancelHandler {
                close(dirFd)
            }
            src.resume()
            dirSource = src
        } else {
            dirSource = nil
        }
        
        // 2. Direct File Source (captures in-place stream writes)
        let fileFd = open(filePath, O_EVTONLY)
        let fileSource: DispatchSourceFileSystemObject?
        if fileFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileFd,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: watchQueue
            )
            src.setEventHandler { [weak self] in
                self?.handleFileSystemEvent(sessionKey: sessionKey, onFileModified: onFileModified)
            }
            src.setCancelHandler {
                close(fileFd)
            }
            src.resume()
            fileSource = src
        } else {
            fileSource = nil
        }
        
        let watchSession = ActiveWatchSession(
            dirSource: dirSource,
            dirFd: dirFd >= 0 ? dirFd : nil,
            fileSource: fileSource,
            fileFd: fileFd >= 0 ? fileFd : nil,
            directoryPath: dirPath,
            fileName: fileName,
            filePath: filePath,
            targetArchivePath: session.archivePath,
            entryPath: session.entryPath,
            debounceItem: nil,
            lastKnownHash: session.initialHash,
            lastKnownMtime: session.lastKnownMtime
        )
        
        activeSessions[sessionKey] = watchSession
    }
    
    /// Legacy compatibility wrapper: watches a single file path for modifications.
    public func watchFileForChanges(
        filePath: String,
        targetArchivePath: String,
        onFileModified: @escaping @Sendable (String, String) -> Void
    ) {
        let parentDir = (filePath as NSString).deletingLastPathComponent
        let fileName = (filePath as NSString).lastPathComponent
        let session = InPlaceEditSession(
            archivePath: targetArchivePath,
            entryPath: fileName,
            stagedFilePath: filePath,
            stagedDirectoryPath: parentDir,
            initialHash: HashCalculator.calculateSHA256(filePath: filePath) ?? "",
            lastKnownMtime: Self.getFileMtime(path: filePath)
        )
        
        watchEditingSession(session: session) { updatedSession in
            onFileModified(updatedSession.stagedFilePath, updatedSession.archivePath)
        }
    }
    
    private func handleFileSystemEvent(
        sessionKey: String,
        onFileModified: @escaping @Sendable (InPlaceEditSession) -> Void
    ) {
        lock.lock()
        guard var watchSession = activeSessions[sessionKey] else {
            lock.unlock()
            return
        }
        
        watchSession.debounceItem?.cancel()
        
        let dirPath = watchSession.directoryPath
        let filePath = watchSession.filePath
        let archivePath = watchSession.targetArchivePath
        let entryPath = watchSession.entryPath
        let baselineHash = watchSession.lastKnownHash
        
        let debounceItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            var st = stat()
            guard stat(filePath, &st) == 0 else { return }
            let currentMtime = Double(st.st_mtimespec.tv_sec)
            
            guard let currentHash = HashCalculator.calculateSHA256(filePath: filePath) else { return }
            
            if currentHash != baselineHash {
                self.lock.lock()
                if var sessionToUpdate = self.activeSessions[sessionKey] {
                    sessionToUpdate.lastKnownHash = currentHash
                    sessionToUpdate.lastKnownMtime = currentMtime
                    self.activeSessions[sessionKey] = sessionToUpdate
                }
                self.lock.unlock()
                
                let updatedModel = InPlaceEditSession(
                    sessionId: sessionKey,
                    archivePath: archivePath,
                    entryPath: entryPath,
                    stagedFilePath: filePath,
                    stagedDirectoryPath: dirPath,
                    state: .syncing,
                    initialHash: currentHash,
                    lastKnownMtime: currentMtime,
                    hasUnsavedChanges: true,
                    errorMessage: nil
                )
                
                onFileModified(updatedModel)
            }
        }
        
        watchSession.debounceItem = debounceItem
        activeSessions[sessionKey] = watchSession
        lock.unlock()
        
        // 100ms debounce for rapid physical change notification
        watchQueue.asyncAfter(deadline: .now() + .milliseconds(100), execute: debounceItem)
    }
    
    /// Stops watching a specific session ID.
    public func stopWatching(sessionKey: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let session = activeSessions.removeValue(forKey: sessionKey) {
            session.debounceItem?.cancel()
            session.dirSource?.cancel()
            session.fileSource?.cancel()
        }
    }
    
    /// Stops watching by file path string.
    public func stopWatching(filePath: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let matchingKeys = activeSessions.filter { _, session in
            session.filePath == filePath
        }.map(\.key)
        
        for key in matchingKeys {
            if let session = activeSessions.removeValue(forKey: key) {
                session.debounceItem?.cancel()
                session.dirSource?.cancel()
                session.fileSource?.cancel()
            }
        }
    }
    
    /// Cancels all active dispatch sources and closes file descriptors.
    public func stopAllWatching() {
        lock.lock()
        let sessions = Array(activeSessions.values)
        activeSessions.removeAll()
        lock.unlock()
        
        for session in sessions {
            session.debounceItem?.cancel()
            session.dirSource?.cancel()
            session.fileSource?.cancel()
        }
    }
    
    public func reset() {
        stopAllWatching()
    }
    
    private static func getFileMtime(path: String) -> Double {
        var st = stat()
        if stat(path, &st) == 0 {
            return Double(st.st_mtimespec.tv_sec)
        }
        return Date().timeIntervalSince1970
    }
}
