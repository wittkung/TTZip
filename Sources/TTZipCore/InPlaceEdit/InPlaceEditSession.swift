// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Lifecycle states for an active in-place archive editing session.
public enum InPlaceEditSessionState: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    /// Archive entry has been extracted into the private staging directory.
    case staged = "staged"
    /// Filesystem watcher is actively listening for write/rename events on the staged file or directory.
    case listening = "listening"
    /// External changes detected; shadow repack and archive synchronization in progress.
    case syncing = "syncing"
    /// Changes successfully synchronized and committed to the destination archive.
    case saved = "saved"
    /// Staging directory cleaned up and file descriptors closed.
    case closed = "closed"
    /// Session encountered an unrecoverable I/O or mutation error.
    case error = "error"
}

/// Type alias for domain model consistency.
public typealias EditSessionState = InPlaceEditSessionState

/// Represents an active in-place file editing and filesystem change monitoring session.
///
/// Corresponds to JSON schema `specs/079-professional-grade-gap-audit/contracts/in-place-edit-session.json`.
public struct InPlaceEditSession: Sendable, Codable, Equatable, Identifiable, Hashable {
    /// Unique identifier of the editing session (UUID v4).
    public let sessionId: String
    
    /// Absolute filesystem path to the target archive file on disk.
    public let archivePath: String
    
    /// Relative virtual path of the target file entry within the archive.
    public let entryPath: String
    
    /// Absolute filesystem path to the temporary staged file extracted for external editing.
    public let stagedFilePath: String
    
    /// Absolute filesystem path to the private parent directory monitored via kqueue.
    public let stagedDirectoryPath: String
    
    /// Lifecycle state of the editing session.
    public var state: InPlaceEditSessionState
    
    /// SHA-256 hex digest of the entry at extraction time.
    public let initialHash: String
    
    /// POSIX timestamp (seconds) of the most recent file modification.
    public var lastKnownMtime: Double
    
    /// True if the staged file has modifications not yet synchronized back into the archive.
    public var hasUnsavedChanges: Bool
    
    /// Diagnostic error message if the session encountered an error.
    public var errorMessage: String?
    
    /// Conformance to `Identifiable`.
    public var id: String {
        return sessionId
    }
    
    /// Designated initializer for creating an active in-place editing session.
    public init(
        sessionId: String = UUID().uuidString,
        archivePath: String,
        entryPath: String,
        stagedFilePath: String,
        stagedDirectoryPath: String,
        state: InPlaceEditSessionState = .staged,
        initialHash: String,
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
