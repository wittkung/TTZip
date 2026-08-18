// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Standardized 7-Zip aligned MIPS hardware benchmark telemetry and scores.
public struct HardwareBenchmarkMetric: Sendable, Codable, Equatable {
    public let dictionarySizeMB: Int
    public let threadCount: Int
    public let compressMIPS: Double
    public let decompressMIPS: Double
    public let totalMIPS: Double
    public let compressSpeedMBs: Double
    public let decompressSpeedMBs: Double
    public let cpuUsagePercent: Double
    public let ratingPerUsageMIPS: Double

    public init(
        dictionarySizeMB: Int,
        threadCount: Int,
        compressMIPS: Double,
        decompressMIPS: Double,
        totalMIPS: Double,
        compressSpeedMBs: Double,
        decompressSpeedMBs: Double,
        cpuUsagePercent: Double,
        ratingPerUsageMIPS: Double
    ) {
        self.dictionarySizeMB = dictionarySizeMB
        self.threadCount = threadCount
        self.compressMIPS = compressMIPS
        self.decompressMIPS = decompressMIPS
        self.totalMIPS = totalMIPS
        self.compressSpeedMBs = compressSpeedMBs
        self.decompressSpeedMBs = decompressSpeedMBs
        self.cpuUsagePercent = cpuUsagePercent
        self.ratingPerUsageMIPS = ratingPerUsageMIPS
    }
}
