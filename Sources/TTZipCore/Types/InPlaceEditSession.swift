// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
