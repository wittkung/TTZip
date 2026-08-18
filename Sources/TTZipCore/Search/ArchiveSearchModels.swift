// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// In-archive deep search query parameters.
public struct ArchiveSearchQuery: Sendable, Codable, Equatable, Hashable {
    public let queryText: String
    public let isRegex: Bool
    public let caseSensitive: Bool
    public let minSizeBytes: Int64?
    public let maxSizeBytes: Int64?
    public let fileExtensions: [String]?

    public init(
        queryText: String,
        isRegex: Bool = false,
        caseSensitive: Bool = false,
        minSizeBytes: Int64? = nil,
        maxSizeBytes: Int64? = nil,
        fileExtensions: [String]? = nil
    ) {
        self.queryText = queryText
        self.isRegex = isRegex
        self.caseSensitive = caseSensitive
        self.minSizeBytes = minSizeBytes
        self.maxSizeBytes = maxSizeBytes
        self.fileExtensions = fileExtensions
    }
}

/// In-archive deep search execution result and telemetry metrics.
public struct ArchiveSearchResult: Sendable, Codable, Equatable {
    public let matchedIndices: [Int32]
    public let matchedEntriesCount: Int
    public let totalScannedEntries: Int
    public let searchDurationMs: Double

    public init(
        matchedIndices: [Int32],
        matchedEntriesCount: Int,
        totalScannedEntries: Int,
        searchDurationMs: Double
    ) {
        self.matchedIndices = matchedIndices
        self.matchedEntriesCount = matchedEntriesCount
        self.totalScannedEntries = totalScannedEntries
        self.searchDurationMs = searchDurationMs
    }
}
