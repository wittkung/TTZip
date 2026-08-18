// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Competitor benchmark data row representing single test scenario comparisons.
public struct CompetitorBenchmarkRow: Sendable, Identifiable, Codable {
    public var id: String { "\(toolName)_\(dimensionName)_\(format.rawValue)_\(level.rawValue)_\(isEncrypted)" }
    public let toolName: String                   // Competitor tool name (e.g. "Apple ditto", "7-Zip 7zz CLI", "System tar+zstd")
    public let dimensionName: String              // Dataset name
    public let format: ArchiveCompressionFormat   // Archive format
    public let level: ArchiveCompressionLevel     // Compression level
    public let isEncrypted: Bool                  // Encryption flag
    public let datasetSizeBytes: Int64            // Original dataset size
    public let archiveSizeBytes: Int64            // Competitor archive size
    public let compressDurationSeconds: Double    // Competitor compression duration
    public let compressThroughputMBs: Double       // Competitor compression throughput (MB/s)
    public let extractDurationSeconds: Double     // Competitor extraction duration
    public let extractThroughputMBs: Double        // Competitor extraction throughput (MB/s)
    public let compressionRatioPercent: Double     // Competitor compression ratio (%)
    public let ttzipArchiveSizeBytes: Int64       // TTZip archive size
    public let ttzipCompressionRatioPercent: Double// TTZip compression ratio (%)
    public let ttzipCompressMBs: Double           // TTZip compression throughput (MB/s)
    public let ttzipExtractMBs: Double            // TTZip extraction throughput (MB/s)
    public let compressSpeedupVsCompetitor: Double // TTZip compression speedup multiplier (TTZip MBs / Competitor MBs)
    public let extractSpeedupVsCompetitor: Double  // TTZip extraction speedup multiplier (TTZip MBs / Competitor MBs)
    public let topAopStage: String                 // AOP profiling bottleneck stage description

    public init(
        toolName: String,
        dimensionName: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        isEncrypted: Bool,
        datasetSizeBytes: Int64,
        archiveSizeBytes: Int64,
        compressDurationSeconds: Double,
        compressThroughputMBs: Double,
        extractDurationSeconds: Double,
        extractThroughputMBs: Double,
        compressionRatioPercent: Double,
        ttzipArchiveSizeBytes: Int64,
        ttzipCompressionRatioPercent: Double,
        ttzipCompressMBs: Double,
        ttzipExtractMBs: Double,
        compressSpeedupVsCompetitor: Double,
        extractSpeedupVsCompetitor: Double,
        topAopStage: String = ""
    ) {
        self.toolName = toolName
        self.dimensionName = dimensionName
        self.format = format
        self.level = level
        self.isEncrypted = isEncrypted
        self.datasetSizeBytes = datasetSizeBytes
        self.archiveSizeBytes = archiveSizeBytes
        self.compressDurationSeconds = compressDurationSeconds
        self.compressThroughputMBs = compressThroughputMBs
        self.extractDurationSeconds = extractDurationSeconds
        self.extractThroughputMBs = extractThroughputMBs
        self.compressionRatioPercent = compressionRatioPercent
        self.ttzipArchiveSizeBytes = ttzipArchiveSizeBytes
        self.ttzipCompressionRatioPercent = ttzipCompressionRatioPercent
        self.ttzipCompressMBs = ttzipCompressMBs
        self.ttzipExtractMBs = ttzipExtractMBs
        self.compressSpeedupVsCompetitor = compressSpeedupVsCompetitor
        self.extractSpeedupVsCompetitor = extractSpeedupVsCompetitor
        self.topAopStage = topAopStage
    }
}

/// Peak performance historical benchmark matrix record.
public struct PeakPerformanceRecord: Codable, Sendable {
    public let formatRaw: String
    public let levelRaw: Int
    public let isEncrypted: Bool
    public let dimensionName: String
    public var peakCompressMBs: Double
    public var peakExtractMBs: Double
    public var lastUpdated: Date

    public init(
        formatRaw: String,
        levelRaw: Int,
        isEncrypted: Bool,
        dimensionName: String,
        peakCompressMBs: Double,
        peakExtractMBs: Double,
        lastUpdated: Date = Date()
    ) {
        self.formatRaw = formatRaw
        self.levelRaw = levelRaw
        self.isEncrypted = isEncrypted
        self.dimensionName = dimensionName
        self.peakCompressMBs = peakCompressMBs
        self.peakExtractMBs = peakExtractMBs
        self.lastUpdated = lastUpdated
    }
}
