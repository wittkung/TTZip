//
//  TUISessionModels.swift
//  TTZipCore
//
//  Created by TTZip on 2026-08-18.
//

import Foundation

/// Represents the mutable state of an active interactive terminal session in `ttzip-cli explore`.
public struct TUISessionState: Sendable, Equatable {
    public var archivePath: String
    public var currentDirectoryPath: String
    public var cursorIndex: Int
    public var scrollOffset: Int
    public var expandedPaths: Set<String>
    public var selectedPaths: Set<String>
    public var visibleRows: [TUIVisibleRow]
    public var isPeeking: Bool
    public var peekContent: TUIPeekContent?
    public var flashMessage: String?
    public var isExiting: Bool
    public var terminalRows: Int
    public var terminalCols: Int

    public init(
        archivePath: String,
        currentDirectoryPath: String = "",
        cursorIndex: Int = 0,
        scrollOffset: Int = 0,
        expandedPaths: Set<String> = [],
        selectedPaths: Set<String> = [],
        visibleRows: [TUIVisibleRow] = [],
        isPeeking: Bool = false,
        peekContent: TUIPeekContent? = nil,
        flashMessage: String? = nil,
        isExiting: Bool = false,
        terminalRows: Int = 24,
        terminalCols: Int = 80
    ) {
        self.archivePath = archivePath
        self.currentDirectoryPath = currentDirectoryPath
        self.cursorIndex = cursorIndex
        self.scrollOffset = scrollOffset
        self.expandedPaths = expandedPaths
        self.selectedPaths = selectedPaths
        self.visibleRows = visibleRows
        self.isPeeking = isPeeking
        self.peekContent = peekContent
        self.flashMessage = flashMessage
        self.isExiting = isExiting
        self.terminalRows = terminalRows
        self.terminalCols = terminalCols
    }
}

/// Represents a single visible row in the interactive terminal directory tree.
public struct TUIVisibleRow: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let depth: Int
    public let isExpanded: Bool
    public let sizeBytes: Int64
    public let formattedSize: String
    public var isSelected: Bool
    public let indentationPrefix: String
    public let iconEmoji: String

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        depth: Int,
        isExpanded: Bool = false,
        sizeBytes: Int64 = 0,
        formattedSize: String = "",
        isSelected: Bool = false,
        indentationPrefix: String = "",
        iconEmoji: String = ""
    ) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.depth = depth
        self.isExpanded = isExpanded
        self.sizeBytes = sizeBytes
        self.formattedSize = formattedSize
        self.isSelected = isSelected
        self.indentationPrefix = indentationPrefix
        self.iconEmoji = iconEmoji
    }
}

/// Encapsulates formatted text lines or binary hex dumps for the in-terminal preview overlay (`p`).
public struct TUIPeekContent: Sendable, Equatable {
    public let filePath: String
    public let mimeType: String
    public let uncompressedSize: Int64
    public let formattedSize: String
    public let lines: [String]
    public let hexDump: String?
    public let metadata: [String: String]
    public let isTruncated: Bool

    public init(
        filePath: String,
        mimeType: String,
        uncompressedSize: Int64,
        formattedSize: String,
        lines: [String] = [],
        hexDump: String? = nil,
        metadata: [String: String] = [:],
        isTruncated: Bool = false
    ) {
        self.filePath = filePath
        self.mimeType = mimeType
        self.uncompressedSize = uncompressedSize
        self.formattedSize = formattedSize
        self.lines = lines
        self.hexDump = hexDump
        self.metadata = metadata
        self.isTruncated = isTruncated
    }
}
