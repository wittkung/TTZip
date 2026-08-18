// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Action type identifier dispatched from macOS Finder context menu or Services.
/// Conforms strictly to `contracts/finder-sync-action.json`.
public enum FinderSyncActionIdentifier: String, Codable, Sendable, CaseIterable {
    case extractHere = "extract_here"
    case extractToSubfolder = "extract_to_subfolder"
    case inspectArchive = "inspect_archive"
    case compressQuick7z = "compress_quick_7z"
    case compressQuickZip = "compress_quick_zip"
    case compressSeparate = "compress_separate"
    case compressAndDeleteSource = "compress_and_delete_source"
    case compressModalAdvanced = "compress_modal_advanced"
    case autofillPassword = "autofill_password"
    case computeHash = "compute_hash"
}

/// Request model representing an IPC action request dispatched from FinderSync context menus or Services.
/// Conforms strictly to `contracts/finder-sync-action.json`.
public struct FinderSyncActionRequest: Codable, Sendable, Equatable {
    public let actionIdentifier: String
    public let sourcePaths: [String]
    public let destinationDirectory: String?
    public let sanitizeMacMetadata: Bool
    public let password: String?
    
    public var typedAction: FinderSyncActionIdentifier? {
        FinderSyncActionIdentifier(rawValue: actionIdentifier)
    }
    
    public init(
        actionIdentifier: String,
        sourcePaths: [String],
        destinationDirectory: String? = nil,
        sanitizeMacMetadata: Bool = false,
        password: String? = nil
    ) {
        self.actionIdentifier = actionIdentifier
        self.sourcePaths = sourcePaths
        self.destinationDirectory = destinationDirectory
        self.sanitizeMacMetadata = sanitizeMacMetadata
        self.password = password
    }
    
    public init(
        action: FinderSyncActionIdentifier,
        sourcePaths: [String],
        destinationDirectory: String? = nil,
        sanitizeMacMetadata: Bool = false,
        password: String? = nil
    ) {
        self.actionIdentifier = action.rawValue
        self.sourcePaths = sourcePaths
        self.destinationDirectory = destinationDirectory
        self.sanitizeMacMetadata = sanitizeMacMetadata
        self.password = password
    }
}
