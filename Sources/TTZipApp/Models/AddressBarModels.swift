// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI

/// Active input mode for the omnibar.
public enum AddressBarInputMode: String, Sendable, Codable, CaseIterable {
    case pathNavigation
    case spotlightSearch
}

/// Category of evaluated path destination.
public enum PathResolutionType: String, Sendable, Codable, CaseIterable {
    case directory
    case archive
    case file
    case notFound
    case permissionRequired
}

/// Comprehensive outcome of evaluating and resolving a raw path string.
public struct PathResolutionResult: Sendable, Equatable {
    public let rawInput: String
    public let sanitizedPath: String
    public let destinationType: PathResolutionType
    public let exists: Bool
    public let isDirectory: Bool
    public let isArchive: Bool
    public let errorMessage: String?
    
    public init(
        rawInput: String,
        sanitizedPath: String,
        destinationType: PathResolutionType,
        exists: Bool,
        isDirectory: Bool,
        isArchive: Bool,
        errorMessage: String? = nil
    ) {
        self.rawInput = rawInput
        self.sanitizedPath = sanitizedPath
        self.destinationType = destinationType
        self.exists = exists
        self.isDirectory = isDirectory
        self.isArchive = isArchive
        self.errorMessage = errorMessage
    }
}

/// Represents an autocompleted filesystem entry in the suggestion list.
public struct PathSuggestionItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let displayName: String
    public let parentPath: String
    public let isDirectory: Bool
    public let isArchive: Bool
    public let systemIconName: String
    public let matchHighlightRange: [Int]
    
    public init(
        id: String? = nil,
        path: String,
        displayName: String,
        parentPath: String,
        isDirectory: Bool,
        isArchive: Bool,
        systemIconName: String,
        matchHighlightRange: [Int] = [0, 0]
    ) {
        self.id = id ?? path
        self.path = path
        self.displayName = displayName
        self.parentPath = parentPath
        self.isDirectory = isDirectory
        self.isArchive = isArchive
        self.systemIconName = systemIconName
        self.matchHighlightRange = matchHighlightRange
    }
}

/// Represents a single clickable breadcrumb segment within the idle path bar.
public struct BreadcrumbSegment: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let fullURL: URL
    public let isRoot: Bool
    public let isLast: Bool
    
    public init(
        id: String,
        title: String,
        fullURL: URL,
        isRoot: Bool = false,
        isLast: Bool = false
    ) {
        self.id = id
        self.title = title
        self.fullURL = fullURL
        self.isRoot = isRoot
        self.isLast = isLast
    }
}
