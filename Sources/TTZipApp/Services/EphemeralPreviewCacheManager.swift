// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

/// Actor responsible for sandboxed, ephemeral file staging and automated lifecycle cleanup for Quick Look & Finder drag.
public actor EphemeralPreviewCacheManager {
    public static let shared = EphemeralPreviewCacheManager()
    
    private let sessionRootDirectory: URL
    private var stagedFiles: [String: URL] = [:]
    
    public init() {
        let uniqueSession = "ttzip_previews_\(ProcessInfo.processInfo.processIdentifier)_\(UUID().uuidString)"
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueSession, isDirectory: true)
        self.sessionRootDirectory = tempDir
        
        // Create session directory with restrictive 0o700 permissions
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        
        // Register cleanup on application termination
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await EphemeralPreviewCacheManager.shared.cleanupAll()
            }
        }
    }
    
    /// Stages data into an isolated file in the sandbox and returns its secure URL.
    public func stageFile(data: Data, suggestedFileName: String) throws -> URL {
        let sanitizedName = suggestedFileName.replacingOccurrences(of: "/", with: "_")
        let fileURL = sessionRootDirectory.appendingPathComponent(sanitizedName)
        
        // Write to temporary sibling file and perform atomic rename
        let tempSibling = sessionRootDirectory.appendingPathComponent(".tmp_\(UUID().uuidString)")
        try data.write(to: tempSibling, options: [.atomic])
        
        // Set restrictive 0o600 file permissions
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempSibling.path)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        try FileManager.default.moveItem(at: tempSibling, to: fileURL)
        stagedFiles[sanitizedName] = fileURL
        return fileURL
    }
    
    /// Returns the session directory URL.
    public func getSessionRoot() -> URL {
        return sessionRootDirectory
    }
    
    /// Removes all staged preview files and deletes the session directory.
    public func cleanupAll() {
        stagedFiles.removeAll()
        if FileManager.default.fileExists(atPath: sessionRootDirectory.path) {
            try? FileManager.default.removeItem(at: sessionRootDirectory)
        }
    }
    
    deinit {
        let dir = sessionRootDirectory
        if FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
    }
}
