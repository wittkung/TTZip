// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 硬件时钟校准信息模型
public struct PlatformTimerCalibrationInfo: Codable, Sendable, Equatable {
    public let platformOS: String
    public let architecture: String
    public let timerBackend: String
    public let frequencyHz: UInt64
    public let timebaseNumer: UInt32
    public let timebaseDenom: UInt32
    public let resolutionNanos: Double
    public let overheadNanos: Double

    public init(
        platformOS: String,
        architecture: String,
        timerBackend: String,
        frequencyHz: UInt64,
        timebaseNumer: UInt32,
        timebaseDenom: UInt32,
        resolutionNanos: Double,
        overheadNanos: Double
    ) {
        self.platformOS = platformOS
        self.architecture = architecture
        self.timerBackend = timerBackend
        self.frequencyHz = frequencyHz
        self.timebaseNumer = timebaseNumer
        self.timebaseDenom = timebaseDenom
        self.resolutionNanos = resolutionNanos
        self.overheadNanos = overheadNanos
    }
}

/// 纯内存压测配置参数
public struct InMemoryBenchmarkConfig: Codable, Sendable {
    public var selectedFormats: [String]
    public var selectedLevels: [Int]
    public var bufferSizeBytes: Int64
    public var warmupPasses: Int
    public var minDurationMs: Int
    public var useBinaryUnits: Bool
    public var turboBenchOutput: Bool
    public var enableThermalGuard: Bool
    public var customInputPath: String?

    public init(
        selectedFormats: [String] = ["zip", "7z", "zstd", "lz4"],
        selectedLevels: [Int] = [1, 6],
        bufferSizeBytes: Int64 = 10 * 1024 * 1024, // 10MB default
        warmupPasses: Int = 2,
        minDurationMs: Int = 500,
        useBinaryUnits: Bool = false,
        turboBenchOutput: Bool = false,
        enableThermalGuard: Bool = false,
        customInputPath: String? = nil
    ) {
        self.selectedFormats = selectedFormats
        self.selectedLevels = selectedLevels
        self.bufferSizeBytes = bufferSizeBytes
        self.warmupPasses = max(1, warmupPasses)
        self.minDurationMs = max(100, minDurationMs)
        self.useBinaryUnits = useBinaryUnits
        self.turboBenchOutput = turboBenchOutput
        self.enableThermalGuard = enableThermalGuard
        self.customInputPath = customInputPath
    }
}

/// 单个算法维度的基准测试测量结果 (对标 TurboBench / lzbench 标准指标)
public struct AlgorithmBenchmarkResult: Codable, Sendable {
    public let algorithm: String
    public let level: Int
    public let uncompressedBytes: Int64
    public let compressedBytes: Int64
    public let ratio: Double
    public let spaceSavingsPct: Double
    public let compressionTimeNs: UInt64
    public let decompressionTimeNs: UInt64
    public let compressionSpeedMBs: Double
    public let decompressionSpeedMBs: Double
    public let iterationsCompleted: Int
    public let integrityVerified: Bool

    public init(
        algorithm: String,
        level: Int,
        uncompressedBytes: Int64,
        compressedBytes: Int64,
        compressionTimeNs: UInt64,
        decompressionTimeNs: UInt64,
        iterationsCompleted: Int,
        integrityVerified: Bool,
        useBinaryUnits: Bool = false
    ) {
        self.algorithm = algorithm
        self.level = level
        self.uncompressedBytes = uncompressedBytes
        self.compressedBytes = compressedBytes
        self.iterationsCompleted = max(1, iterationsCompleted)
        self.integrityVerified = integrityVerified

        // 压缩比：Uncompressed / Compressed (TurboBench / lzbench 标准倍数)
        if compressedBytes > 0 {
            self.ratio = Double(uncompressedBytes) / Double(compressedBytes)
            self.spaceSavingsPct = (1.0 - (Double(compressedBytes) / Double(uncompressedBytes))) * 100.0
        } else {
            self.ratio = 1.0
            self.spaceSavingsPct = 0.0
        }

        self.compressionTimeNs = compressionTimeNs
        self.decompressionTimeNs = decompressionTimeNs

        // 吞吐率计算：Uncompressed Bytes / (Time in Seconds * UnitDivider)
        let compSec = max(1e-9, Double(compressionTimeNs) / 1_000_000_000.0)
        let decompSec = max(1e-9, Double(decompressionTimeNs) / 1_000_000_000.0)
        let divider: Double = useBinaryUnits ? (1024.0 * 1024.0) : 1_000_000.0

        self.compressionSpeedMBs = (Double(uncompressedBytes) / compSec) / divider
        self.decompressionSpeedMBs = (Double(uncompressedBytes) / decompSec) / divider
    }
}

/// 全量基准测试运行汇总报告
public struct BenchmarkSuiteReport: Codable, Sendable {
    public let reportId: String
    public let timestamp: String
    public let timerCalibration: PlatformTimerCalibrationInfo
    public let totalInputBytes: Int64
    public let totalWallDurationMs: Double
    public let results: [AlgorithmBenchmarkResult]
    public let allPassed: Bool

    public init(
        reportId: String = UUID().uuidString,
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        timerCalibration: PlatformTimerCalibrationInfo,
        totalInputBytes: Int64,
        totalWallDurationMs: Double,
        results: [AlgorithmBenchmarkResult],
        allPassed: Bool
    ) {
        self.reportId = reportId
        self.timestamp = timestamp
        self.timerCalibration = timerCalibration
        self.totalInputBytes = totalInputBytes
        self.totalWallDurationMs = totalWallDurationMs
        self.results = results
        self.allPassed = allPassed
    }
}
