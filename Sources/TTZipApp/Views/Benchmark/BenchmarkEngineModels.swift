// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Benchmark payload size options.
public enum BenchmarkDataSize: String, Sendable, CaseIterable, Identifiable {
    case tiny = "50 MB (Micro Sampling)"
    case small = "100 MB (Fast Response Test)"
    case medium = "500 MB (Standard Benchmark)"
    case large = "1.0 GB (1GB Flagship Stream)"
    case stress = "2.0 GB (Full Load Stress Test)"

    public var id: String { rawValue }

    public var bytes: Int64 {
        switch self {
        case .tiny: return 50 * 1024 * 1024
        case .small: return 100 * 1024 * 1024
        case .medium: return 500 * 1024 * 1024
        case .large: return 1024 * 1024 * 1024
        case .stress: return 2048 * 1024 * 1024
        }
    }

    public var sizeMB: Double {
        return Double(bytes) / (1024.0 * 1024.0)
    }
}

/// Benchmark dataset entropy and content profile categories.
public enum BenchmarkDatasetProfile: String, Sendable, CaseIterable, Identifiable {
    case codeText = "High-Redundancy Code & Text"
    case mixedOffice = "Mixed Office & Engineering Documents"
    case mediaBinary = "High-Entropy Media & Binary"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .codeText: return "Highly compressible text, JSON, and source code testing dictionary pattern matching"
        case .mixedOffice: return "Balanced mixture of documents, PDFs, and scripts testing realistic workloads"
        case .mediaBinary: return "Low redundancy binary stream testing maximum I/O and codec throughput limits"
        }
    }
}

/// Comprehensive benchmark evaluation report.
public struct BenchmarkResult: Sendable, Identifiable {
    public var id: String { "\(formatName)_\(dataSizeMB)MB_\(UUID().uuidString)" }

    public let dataSizeMB: Double
    public let elapsedSeconds: Double
    public let throughputMBs: Double              // Compression throughput (MB/s)
    public let decompressionThroughputMBs: Double // Decompression throughput (MB/s)
    public let originalSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let compressionRatioPercent: Double   // Compressed volume ratio (%)
    public let spaceSavedPercent: Double          // Space savings ratio (%)
    public let nativeMacOsSeconds: Double
    public let speedupMultiplier: Double         // Speedup multiplier relative to macOS native zip
    public let installedCompetitorScores: [CompetitorRealScore] // Installed competitor metrics

    public var kekaSpeedup: Double {
        installedCompetitorScores.first(where: { $0.tool.toolId == "keka" || $0.tool.toolId == "7zip_cli" })?.relativeSpeedupVsNative ?? 0.0
    }
    public var winzipSpeedup: Double {
        installedCompetitorScores.first(where: { $0.tool.toolId == "winzip" })?.relativeSpeedupVsNative ?? 0.0
    }

    public let chipName: String
    public let usedCores: Int
    public let formatName: String
    public let datasetProfileName: String
    public let efficiencyScore: Int               // Overall engineering efficiency score (0 - 100)
    public let recommendationBadge: String         // Recommendation badge

    public init(
        dataSizeMB: Double,
        elapsedSeconds: Double,
        throughputMBs: Double,
        decompressionThroughputMBs: Double = 0.0,
        originalSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        nativeMacOsSeconds: Double,
        speedupMultiplier: Double,
        installedCompetitorScores: [CompetitorRealScore] = [],
        chipName: String,
        usedCores: Int,
        formatName: String,
        datasetProfileName: String = "Mixed Office Documents",
        efficiencyScore: Int = 85,
        recommendationBadge: String = "Recommended"
    ) {
        self.dataSizeMB = dataSizeMB
        self.elapsedSeconds = elapsedSeconds
        self.throughputMBs = throughputMBs
        self.decompressionThroughputMBs = decompressionThroughputMBs
        self.originalSizeBytes = originalSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.spaceSavedPercent = max(0.0, 100.0 - compressionRatioPercent)
        self.nativeMacOsSeconds = nativeMacOsSeconds
        self.speedupMultiplier = speedupMultiplier
        self.installedCompetitorScores = installedCompetitorScores
        self.chipName = chipName
        self.usedCores = usedCores
        self.formatName = formatName
        self.datasetProfileName = datasetProfileName
        self.efficiencyScore = efficiencyScore
        self.recommendationBadge = recommendationBadge
    }
}

public struct BenchmarkProgress: Sendable {
    public enum State: Sendable {
        case idle
        case generatingData
        case compressing
        case finished
        case failed(String)
    }

    public var state: State = .idle
    public var bytesProcessed: Int64 = 0
    public var totalBytes: Int64 = 0
    public var currentThroughputMBs: Double = 0.0
    public var progressPercent: Double = 0.0
    public var statusText: String = "Ready"

    public init(
        state: State = .idle,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentThroughputMBs: Double = 0.0,
        progressPercent: Double = 0.0,
        statusText: String = "Ready"
    ) {
        self.state = state
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.currentThroughputMBs = currentThroughputMBs
        self.progressPercent = progressPercent
        self.statusText = statusText
    }
}
