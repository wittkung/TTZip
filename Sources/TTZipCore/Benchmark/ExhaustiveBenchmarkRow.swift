// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

/// Metrics row representing a single benchmark permutation.
public struct ExhaustiveBenchmarkRow: Sendable, Identifiable, Codable {
    public var id: String { "\(dimensionName)_\(format.rawValue)_\(level.rawValue)_\(isEncrypted)" }
    public let dimensionName: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let isEncrypted: Bool
    public let datasetSizeBytes: Int64
    public let archiveSizeBytes: Int64
    public let compressDurationSeconds: Double
    public let compressThroughputMBs: Double
    public let extractDurationSeconds: Double
    public let extractThroughputMBs: Double
    public let compressionRatioPercent: Double
    public let sha256Matched: Bool

    public init(
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
        sha256Matched: Bool
    ) {
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
        self.sha256Matched = sha256Matched
    }
}
