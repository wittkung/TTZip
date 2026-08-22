// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

public struct CodecBenchmarkPointResult: Codable, Sendable {
    public let engineName: String
    public let corpusType: BenchmarkCorpusType
    public let payloadSizeBytes: Int
    public let compressionLevel: Int
    public let compressedSizeBytes: Int
    public let compressionRatio: Double
    public let compressDurationNs: Double
    public let compressThroughputMBs: Double
    public let decompressDurationNs: Double
    public let decompressThroughputMBs: Double
    public let cvPercentage: Double
    public let integrityVerified: Bool

    public init(
        engineName: String,
        corpusType: BenchmarkCorpusType,
        payloadSizeBytes: Int,
        compressionLevel: Int,
        compressedSizeBytes: Int,
        compressionRatio: Double,
        compressDurationNs: Double,
        compressThroughputMBs: Double,
        decompressDurationNs: Double,
        decompressThroughputMBs: Double,
        cvPercentage: Double,
        integrityVerified: Bool
    ) {
        self.engineName = engineName
        self.corpusType = corpusType
        self.payloadSizeBytes = payloadSizeBytes
        self.compressionLevel = compressionLevel
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatio = compressionRatio
        self.compressDurationNs = compressDurationNs
        self.compressThroughputMBs = compressThroughputMBs
        self.decompressDurationNs = decompressDurationNs
        self.decompressThroughputMBs = decompressThroughputMBs
        self.cvPercentage = cvPercentage
        self.integrityVerified = integrityVerified
    }
}

public struct CodecBenchmarkMatrixSummary: Codable, Sendable {
    public let totalPoints: Int
    public let totalDurationMs: Double
    public let medianCvPercentage: Double
    public let allIntegrityPassed: Bool
    public let results: [CodecBenchmarkPointResult]

    public init(
        totalPoints: Int,
        totalDurationMs: Double,
        medianCvPercentage: Double,
        allIntegrityPassed: Bool,
        results: [CodecBenchmarkPointResult]
    ) {
        self.totalPoints = totalPoints
        self.totalDurationMs = totalDurationMs
        self.medianCvPercentage = medianCvPercentage
        self.allIntegrityPassed = allIntegrityPassed
        self.results = results
    }
}
