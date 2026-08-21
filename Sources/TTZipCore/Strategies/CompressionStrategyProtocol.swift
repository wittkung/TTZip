// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Performance estimation metrics for candidate compression strategies.
public struct CompressionPerformanceEstimate: Sendable, Equatable {
    public let expectedRatioPercent: Double
    public let estimatedThroughputMBs: Double
    public let recommendedThreadCount: Int
    public let description: String
    
    public init(
        expectedRatioPercent: Double,
        estimatedThroughputMBs: Double,
        recommendedThreadCount: Int,
        description: String
    ) {
        self.expectedRatioPercent = expectedRatioPercent
        self.estimatedThroughputMBs = estimatedThroughputMBs
        self.recommendedThreadCount = recommendedThreadCount
        self.description = description
    }
}

/// Abstract compression strategy interface (Strategy Pattern).
public protocol CompressionStrategyProtocol: Sendable {
    /// Unique strategy identifier.
    var strategyId: String { get }
    /// Human-readable strategy name.
    var displayName: String { get }
    /// Primary supported archive format.
    var supportedFormat: ArchiveCompressionFormat { get }
    
    /// Determines whether strategy can handle the given payload characteristics.
    func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool
    
    /// Predicts throughput and compression ratio based on Apple Silicon chip topology.
    func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate
    
    /// Executes compression strategy.
    func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool
}

// MARK: - Concrete Compression Strategies

/// 1. High-throughput Libdeflate NEON vectorized compression strategy (`LibdeflateCompressionStrategy`).
public final class LibdeflateCompressionStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "libdeflate"
    public let displayName: String = "Libdeflate NEON Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .zip
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        guard targetFormat == .zip || targetFormat == .gz || targetFormat == .tarGz else { return false }
        return true
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        let threads = topology.performanceCores
        let throughput = Double(threads) * 180.0
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 45.0,
            estimatedThroughputMBs: throughput,
            recommendedThreadCount: threads,
            description: "Libdeflate ARM64 NEON acceleration engine balanced for throughput and ZIP ratio"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: supportedFormat)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: supportedFormat,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}

/// 2. Apple Silicon LZFSE zero-copy hardware compression strategy (`AppleSiliconLZFSEStrategy`).
public final class AppleSiliconLZFSEStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "apple_silicon_lzfse"
    public let displayName: String = "Apple Silicon LZFSE Hardware Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .zip
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        #if arch(arm64)
        return targetFormat == .zip && payloadBytes >= 10 * 1024 * 1024
        #else
        return false
        #endif
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        let threads = topology.totalCores
        let throughput = Double(threads) * 320.0
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 55.0,
            estimatedThroughputMBs: throughput,
            recommendedThreadCount: threads,
            description: "Apple Silicon hardware-accelerated LZFSE and APFS extent cloning engine"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: .zip)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zip,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}

/// 3. Zstandard (zst) maximum throughput strategy (`ZstdStrategy`).
public final class ZstdStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "zstd"
    public let displayName: String = "Zstandard (Zstd) Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .zst
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        return targetFormat == .zst || targetFormat == .tarZst || inputExtensions.contains(".zst")
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        let threads = topology.totalCores
        let throughput = Double(threads) * 250.0
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 40.0,
            estimatedThroughputMBs: throughput,
            recommendedThreadCount: threads,
            description: "Meta Zstandard multi-threaded long-distance matching engine"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: .zst)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zst,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}

/// 4. 7-Zip LZMA2 solid high-density compression strategy (`SevenZipStrategy`).
public final class SevenZipStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "seven_zip"
    public let displayName: String = "7-Zip (LZMA2 Solid) Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .sevenZip
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        return targetFormat == .sevenZip || ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { inputExtensions.contains($0) })
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        let threads = topology.totalCores
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 28.0,
            estimatedThroughputMBs: Double(threads) * 45.0,
            recommendedThreadCount: threads,
            description: "7-Zip LZMA2 solid dictionary compression for maximum density"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: .sevenZip)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .sevenZip,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}

/// 5. POSIX TAR streaming container strategy (`POSIXTarStrategy`).
public final class POSIXTarStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "posix_tar"
    public let displayName: String = "POSIX Tar Streaming Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .tar
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        return targetFormat == .tar || targetFormat == .tarGz || targetFormat == .tarBz2 || targetFormat == .tarXz
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 100.0,
            estimatedThroughputMBs: 1200.0,
            recommendedThreadCount: 1,
            description: "POSIX 512-byte aligned container stream operating at raw I/O throughput"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: .tar)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .tar,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}

/// 6. Store direct bypass strategy for pre-compressed or high-entropy data (`StoreStrategy`).
public final class StoreStrategy: CompressionStrategyProtocol {
    public let strategyId: String = "store_bypass"
    public let displayName: String = "Store Direct Bypass Strategy"
    public let supportedFormat: ArchiveCompressionFormat = .zip
    
    /// Pre-compressed multimedia file extensions.
    public static let preCompressedExtensions: Set<String> = [
        ".mp4", ".mov", ".m4v", ".mkv", ".avi",
        ".png", ".jpg", ".jpeg", ".webp", ".heic",
        ".zip", ".gz", ".7z", ".rar", ".zst", ".bz2", ".xz",
        ".mp3", ".aac", ".flac", ".pdf"
    ]
    
    public init() {}
    
    public func canHandle(payloadBytes: Int64, inputExtensions: [String], targetFormat: ArchiveCompressionFormat) -> Bool {
        if inputExtensions.isEmpty { return false }
        let preCompressedCount = inputExtensions.filter { Self.preCompressedExtensions.contains($0.lowercased()) }.count
        return Double(preCompressedCount) / Double(inputExtensions.count) >= 0.5
    }
    
    public func estimatePerformance(payloadBytes: Int64, topology: AppleSiliconTuner.ChipTopology) -> CompressionPerformanceEstimate {
        return CompressionPerformanceEstimate(
            expectedRatioPercent: 99.5,
            estimatedThroughputMBs: 1500.0,
            recommendedThreadCount: topology.totalCores,
            description: "Store bypass mode eliminating CPU recompression overhead for pre-compressed payloads"
        )
    }
    
    public func compress(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let writer = ArchiveEngineFactory.makeWriter(for: .zip)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zip,
            level: .store,
            inputPaths: inputPaths,
            options: options,
            password: password
        )
        return true
    }
}
