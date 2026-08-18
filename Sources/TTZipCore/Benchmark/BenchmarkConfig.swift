// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Benchmark execution and competitor matrix configuration model.
public struct BenchmarkRunConfig: Sendable {
    /// Format filter list (nil executes all default formats).
    public var selectedFormats: [ArchiveCompressionFormat]?
    
    /// Compression level filter list (nil executes all default levels).
    public var selectedLevels: [ArchiveCompressionLevel]?
    
    /// Target competitor tools filter list.
    public var selectedTools: [String]?
    
    /// Large dataset filter descriptor (e.g. "500MB").
    public var hugeSizeFilter: String?
    
    /// Custom benchmark input paths.
    public var customFilePaths: [String]?
    
    /// Aborts execution immediately on performance regression or verification error.
    public var stopOnLagOrError: Bool
    
    /// Automatically detects and schedules highest-performing system competitor.
    public var autoBestCompetitor: Bool
    
    /// Verification mode asserting dominance over all competitors.
    public var verifyAllDominance: Bool
    
    /// Regression filter configuration file path.
    public var filterConfigPath: String?
    
    /// Restricts execution exclusively to 500MB dataset payload.
    public var hugeOnly: Bool
    
    public init(
        selectedFormats: [ArchiveCompressionFormat]? = nil,
        selectedLevels: [ArchiveCompressionLevel]? = nil,
        selectedTools: [String]? = nil,
        hugeSizeFilter: String? = nil,
        customFilePaths: [String]? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        verifyAllDominance: Bool = false,
        filterConfigPath: String? = nil,
        hugeOnly: Bool = false
    ) {
        self.selectedFormats = selectedFormats
        self.selectedLevels = selectedLevels
        self.selectedTools = selectedTools
        self.hugeSizeFilter = hugeSizeFilter
        self.customFilePaths = customFilePaths
        self.stopOnLagOrError = stopOnLagOrError
        self.autoBestCompetitor = autoBestCompetitor
        self.verifyAllDominance = verifyAllDominance
        self.filterConfigPath = filterConfigPath
        self.hugeOnly = hugeOnly
    }
}
