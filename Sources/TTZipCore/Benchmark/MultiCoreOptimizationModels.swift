// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Architectural layer categorization for multi-core optimizations.
public enum MultiCoreLayer: String, Sendable, Codable, CaseIterable {
    case memory = "Memory"
    case codec = "Codec"
    case container = "Container"
    case hashing = "Hashing"
    case io = "I/O"
    case scheduling = "Scheduling"
}

/// The 8 distinct multi-core optimization points in TTZip.
public enum MultiCoreOptimizationPoint: String, Sendable, Codable, CaseIterable, Identifiable {
    case tlsZeroLock = "OP-1"
    case blockParallel512KB = "OP-2"
    case multiTileDecompress = "OP-3"
    case containerMultiFilePack = "OP-4"
    case containerMultiFileExtract = "OP-5"
    case pmullHardwareChecksum = "OP-6"
    case apfsDirectIOPrealloc = "OP-7"
    case topologyQoSScheduling = "OP-8"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tlsZeroLock:
            return "C11 _Thread_local Zero-Lock State Pool"
        case .blockParallel512KB:
            return "512KB Block-Level Parallel Compression"
        case .multiTileDecompress:
            return "Multi-Tile Parallel Block Decompression"
        case .containerMultiFilePack:
            return "Container-Level Multi-File Concurrency"
        case .containerMultiFileExtract:
            return "Multi-File Concurrent Direct Extraction"
        case .pmullHardwareChecksum:
            return "ARMv8 PMULL Hardware Vectorized CRC32/64"
        case .apfsDirectIOPrealloc:
            return "APFS fstore_t & Direct I/O Preallocation"
        case .topologyQoSScheduling:
            return "Apple Silicon P/E-Core Topology Scheduling"
        }
    }

    public var layer: MultiCoreLayer {
        switch self {
        case .tlsZeroLock: return .memory
        case .blockParallel512KB, .multiTileDecompress: return .codec
        case .containerMultiFilePack, .containerMultiFileExtract: return .container
        case .pmullHardwareChecksum: return .hashing
        case .apfsDirectIOPrealloc: return .io
        case .topologyQoSScheduling: return .scheduling
        }
    }
}

/// Metric result for an isolated single-point multi-core optimization differential test.
public struct OptimizationPointResult: Sendable, Identifiable, Codable {
    public var id: String { pointId }
    public let pointId: String
    public let pointName: String
    public let layer: MultiCoreLayer
    public let baselineThroughputMBs: Double
    public let optimizedThroughputMBs: Double
    public let speedupRatio: Double
    public let isPositiveDelta: Bool
    public let integrityPassed: Bool

    public init(
        point: MultiCoreOptimizationPoint,
        baselineThroughputMBs: Double,
        optimizedThroughputMBs: Double,
        integrityPassed: Bool = true
    ) {
        self.pointId = point.rawValue
        self.pointName = point.title
        self.layer = point.layer
        self.baselineThroughputMBs = max(0.001, baselineThroughputMBs)
        self.optimizedThroughputMBs = max(0.001, optimizedThroughputMBs)
        self.speedupRatio = self.optimizedThroughputMBs / self.baselineThroughputMBs
        self.isPositiveDelta = self.speedupRatio > 1.0
        self.integrityPassed = integrityPassed
    }
}

/// Comprehensive summary of the 8-point multi-core optimization breakdown.
public struct MultiCoreBreakdownSummary: Sendable, Codable {
    public let totalPoints: Int
    public let passedCount: Int
    public let averageSpeedup: Double
    public let allPositiveDelta: Bool
    public let results: [OptimizationPointResult]

    public init(results: [OptimizationPointResult]) {
        self.results = results
        self.totalPoints = results.count
        self.passedCount = results.filter { $0.isPositiveDelta && $0.integrityPassed }.count
        self.averageSpeedup = results.isEmpty ? 0.0 : results.map(\.speedupRatio).reduce(0, +) / Double(results.count)
        self.allPositiveDelta = (passedCount == totalPoints) && (totalPoints > 0)
    }
}
