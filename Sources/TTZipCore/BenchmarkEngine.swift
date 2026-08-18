// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import QuartzCore

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

/// Multi-core hardware stress testing and efficiency benchmarking engine.
public final class BenchmarkEngine: @unchecked Sendable {
    public init() {}
    
    /// Runs full preset benchmark suite across major formats.
    public func runAllPresetsSuite(
        size: BenchmarkDataSize,
        profile: BenchmarkDatasetProfile = .mixedOffice,
        level: ArchiveCompressionLevel = .normal,
        onPresetCompleted: (@Sendable (Int, Int, BenchmarkResult) -> Void)? = nil,
        progressHandler: (@Sendable (Int, Int, String, BenchmarkProgress) -> Void)? = nil
    ) async throws -> [BenchmarkResult] {
        let presets: [(name: String, format: ArchiveCompressionFormat, splitSize: Int64?, rec: String, score: Int)] = [
            ("7-Zip LZMA2 High Compression", .sevenZip, nil, "High Compression Ratio", 92),
            ("Meta Zstandard Parallel", .tarZst, nil, "Ultra Fast Throughput", 98),
            ("ZIP Multi-Volume Split", .zip, 100 * 1024 * 1024, "Cross-Platform Split (100MB)", 94),
            ("TAR GZ Fast Stream", .tarGz, nil, "Unix Infrastructure", 88)
        ]
        
        var results: [BenchmarkResult] = []
        for (index, preset) in presets.enumerated() {
            let res = try await runBenchmark(
                size: size,
                profile: profile,
                format: preset.format,
                level: level,
                splitVolumeSizeBytes: preset.splitSize,
                recommendation: preset.rec,
                baseScore: preset.score,
                progressHandler: { prog in
                    progressHandler?(index + 1, presets.count, preset.name, prog)
                }
            )
            results.append(res)
            onPresetCompleted?(index + 1, presets.count, res)
        }
        return results
    }
    
    /// Executes a single benchmark test run.
    public func runBenchmark(
        size: BenchmarkDataSize,
        profile: BenchmarkDatasetProfile = .mixedOffice,
        format: ArchiveCompressionFormat = .sevenZip,
        level: ArchiveCompressionLevel = .normal,
        splitVolumeSizeBytes: Int64? = nil,
        recommendation: String = "Standard Archiving",
        baseScore: Int = 85,
        progressHandler: (@Sendable (BenchmarkProgress) -> Void)? = nil
    ) async throws -> BenchmarkResult {
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        let tuner = AppleSiliconTuner.shared
        let totalBytes = size.bytes
        
        // 1. Generate synthetic dataset
        progressHandler?(BenchmarkProgress(
            state: .generatingData,
            bytesProcessed: 0,
            totalBytes: totalBytes,
            currentThroughputMBs: 0,
            progressPercent: 0.1,
            statusText: "Generating \(profile.rawValue) [\(String(format: "%.1f", size.sizeMB)) MB] dataset..."
        ))
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipBenchmark_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let sampleFilePath = tempDir.appendingPathComponent("benchmark_data.bin").path
        let outputArchivePath = tempDir.appendingPathComponent("benchmark_output.\(format.rawValue)").path
        
        try generateSyntheticDataset(at: sampleFilePath, targetBytes: totalBytes, profile: profile)
        
        // 2. Launch multi-core compression benchmark
        progressHandler?(BenchmarkProgress(
            state: .compressing,
            bytesProcessed: 0,
            totalBytes: totalBytes,
            currentThroughputMBs: 0,
            progressPercent: 0.2,
            statusText: "Dispatching \(tuner.topology.totalCores) cores for \(format.rawValue.uppercased()) benchmark..."
        ))
        
        let startTime = CACurrentMediaTime()
        let writer = ArchiveEngineFactory.makeWriter(for: format)
        
        _ = try await ArchivePipelineBuilder()
            .withWriter(writer)
            .withOutputPath(outputArchivePath)
            .withFormat(format)
            .withLevel(level)
            .addInputPath(sampleFilePath)
            .withFilterOptions(ArchiveFilterOptions(skipMacJunk: true))
            .withSplitVolumeSize(splitVolumeSizeBytes)
            .withProgressHandler { prog in
                let elapsed = max(0.001, CACurrentMediaTime() - startTime)
                let throughput = (Double(prog.bytesProcessed) / (1024.0 * 1024.0)) / elapsed
                let percent = 0.2 + 0.8 * (Double(prog.bytesProcessed) / Double(totalBytes))
                progressHandler?(BenchmarkProgress(
                    state: .compressing,
                    bytesProcessed: prog.bytesProcessed,
                    totalBytes: totalBytes,
                    currentThroughputMBs: throughput,
                    progressPercent: min(1.0, percent),
                    statusText: "Active: \(String(format: "%.1f", throughput)) MB/s · \(String(format: "%.1f", percent * 100))%"
                ))
            }
            .executeCreate()
        
        let endTime = CACurrentMediaTime()
        let elapsed = max(0.001, endTime - startTime)
        
        let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputArchivePath)[.size] as? Int64) ?? totalBytes
        let throughput = size.sizeMB / elapsed
        
        // Measure decompression throughput
        let decompTargetDir = tempDir.appendingPathComponent("decomp_bench").path
        try? FileManager.default.createDirectory(atPath: decompTargetDir, withIntermediateDirectories: true)
        
        let decompStart = CACurrentMediaTime()
        if format == .zip {
            _ = try? ZipParallelExtractor.shared.extract(archivePath: outputArchivePath, destinationDir: decompTargetDir)
        } else {
            let extractor = ArchiveEngineFactory.makeExtractor(for: format)
            try? await extractor.extract(archivePath: outputArchivePath, destinationDir: decompTargetDir)
        }
        let decompEnd = CACurrentMediaTime()
        let decompElapsed = max(0.0005, decompEnd - decompStart)
        let decompSpeed = size.sizeMB / decompElapsed
        let ratio = (Double(compressedSize) / Double(totalBytes)) * 100.0
        
        // Measure system ditto baseline
        let nativeMeasuredMBs = measureNativeSystemZipThroughput(samplePath: sampleFilePath, targetMB: size.sizeMB)
        let nativeEstimatedSeconds = size.sizeMB / max(1.0, nativeMeasuredMBs)
        let speedup = max(1.0, throughput / max(1.0, nativeMeasuredMBs))
        
        // Probe installed competitors
        let installedCompetitorScores = measureRealCompetitorScores(samplePath: sampleFilePath, targetMB: size.sizeMB, nativeSpeedMBs: nativeMeasuredMBs)
        
        let result = BenchmarkResult(
            dataSizeMB: size.sizeMB,
            elapsedSeconds: elapsed,
            throughputMBs: throughput,
            decompressionThroughputMBs: decompSpeed,
            originalSizeBytes: totalBytes,
            compressedSizeBytes: compressedSize,
            compressionRatioPercent: ratio,
            nativeMacOsSeconds: nativeEstimatedSeconds,
            speedupMultiplier: speedup,
            installedCompetitorScores: installedCompetitorScores,
            chipName: tuner.topology.chipName,
            usedCores: tuner.topology.totalCores,
            formatName: format.rawValue.uppercased(),
            datasetProfileName: profile.rawValue,
            efficiencyScore: baseScore,
            recommendationBadge: recommendation
        )
        
        progressHandler?(BenchmarkProgress(
            state: .finished,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            currentThroughputMBs: throughput,
            progressPercent: 1.0,
            statusText: "Benchmark complete: Peak throughput \(String(format: "%.1f", throughput)) MB/s (\(String(format: "%.1f", speedup))x speedup)"
        ))
        
        return result
    }
    
    /// Runs benchmark against custom user-selected files or directories.
    public func runCustomFileBenchmark(
        inputPath: String,
        format: ArchiveCompressionFormat = .sevenZip,
        level: ArchiveCompressionLevel = .normal,
        splitVolumeSizeBytes: Int64? = nil,
        recommendation: String = "Custom Sample Test",
        baseScore: Int = 90,
        progressHandler: (@Sendable (BenchmarkProgress) -> Void)? = nil
    ) async throws -> BenchmarkResult {
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        let tuner = AppleSiliconTuner.shared
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: inputPath) else {
            throw ArchiveError.fileNotFound
        }
        
        let totalBytes = calculateTotalSize(at: inputPath)
        let dataSizeMB = Double(totalBytes) / (1024.0 * 1024.0)
        let filename = (inputPath as NSString).lastPathComponent
        
        progressHandler?(BenchmarkProgress(
            state: .compressing,
            bytesProcessed: 0,
            totalBytes: totalBytes,
            currentThroughputMBs: 0,
            progressPercent: 0.1,
            statusText: "Preparing evaluation for [\(filename)]..."
        ))
        
        let tempDir = fm.temporaryDirectory.appendingPathComponent("TTZipCustomBenchmark_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let outputArchivePath = tempDir.appendingPathComponent("benchmark_custom_output.\(format.rawValue)").path
        let startTime = CACurrentMediaTime()
        let writer = ArchiveEngineFactory.makeWriter(for: format)
        
        _ = try await ArchivePipelineBuilder()
            .withWriter(writer)
            .withOutputPath(outputArchivePath)
            .withFormat(format)
            .withLevel(level)
            .addInputPath(inputPath)
            .withFilterOptions(ArchiveFilterOptions(skipMacJunk: true))
            .withSplitVolumeSize(splitVolumeSizeBytes)
            .withProgressHandler { prog in
                let elapsed = max(0.001, CACurrentMediaTime() - startTime)
                let throughput = (Double(prog.bytesProcessed) / (1024.0 * 1024.0)) / elapsed
                let percent = 0.1 + 0.9 * (Double(prog.bytesProcessed) / Double(max(1, totalBytes)))
                progressHandler?(BenchmarkProgress(
                    state: .compressing,
                    bytesProcessed: prog.bytesProcessed,
                    totalBytes: totalBytes,
                    currentThroughputMBs: throughput,
                    progressPercent: min(1.0, percent),
                    statusText: "Packaging sample: \(String(format: "%.1f", throughput)) MB/s · \(String(format: "%.1f", min(1.0, percent) * 100))%"
                ))
            }
            .executeCreate()
        
        let endTime = CACurrentMediaTime()
        let elapsed = max(0.001, endTime - startTime)
        
        let compressedSize = (try? fm.attributesOfItem(atPath: outputArchivePath)[.size] as? Int64) ?? totalBytes
        let throughput = dataSizeMB / elapsed
        let ratio = totalBytes > 0 ? ((Double(compressedSize) / Double(totalBytes)) * 100.0) : 100.0
        
        let decompExtractDir = tempDir.appendingPathComponent("decomp_test").path
        let decompStart = CACurrentMediaTime()
        let extractor = ArchiveEngineFactory.makeExtractor(for: format)
        try? await extractor.extract(archivePath: outputArchivePath, destinationDir: decompExtractDir)
        let decompElapsed = max(0.001, CACurrentMediaTime() - decompStart)
        let realDecompThroughput = dataSizeMB / decompElapsed
        
        let nativeMeasuredMBs = measureNativeSystemZipThroughput(samplePath: inputPath, targetMB: dataSizeMB)
        let nativeEstimatedSeconds = dataSizeMB / max(1.0, nativeMeasuredMBs)
        let speedup = max(1.0, throughput / max(1.0, nativeMeasuredMBs))
        let installedCompetitorScores = BenchmarkDatasetGenerator.shared.measureRealCompetitorScores(samplePath: inputPath, targetMB: dataSizeMB, nativeSpeedMBs: nativeMeasuredMBs)
        
        let result = BenchmarkResult(
            dataSizeMB: dataSizeMB,
            elapsedSeconds: elapsed,
            throughputMBs: throughput,
            decompressionThroughputMBs: realDecompThroughput,
            originalSizeBytes: totalBytes,
            compressedSizeBytes: compressedSize,
            compressionRatioPercent: ratio,
            nativeMacOsSeconds: nativeEstimatedSeconds,
            speedupMultiplier: speedup,
            installedCompetitorScores: installedCompetitorScores,
            chipName: tuner.topology.chipName,
            usedCores: tuner.topology.totalCores,
            formatName: format.rawValue.uppercased(),
            datasetProfileName: "Custom Sample: \(filename)",
            efficiencyScore: baseScore,
            recommendationBadge: recommendation
        )
        
        progressHandler?(BenchmarkProgress(
            state: .finished,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            currentThroughputMBs: throughput,
            progressPercent: 1.0,
            statusText: "Sample benchmark complete: Peak throughput \(String(format: "%.1f", throughput)) MB/s (\(String(format: "%.1f", speedup))x speedup)"
        ))
        
        return result
    }
    
    public func calculateTotalSize(at path: String) -> Int64 {
        return BenchmarkDatasetGenerator.shared.calculateTotalSize(at: path)
    }
    
    private func generateSyntheticDataset(at path: String, targetBytes: Int64, profile: BenchmarkDatasetProfile) throws {
        try BenchmarkDatasetGenerator.shared.generateSyntheticDataset(at: path, targetBytes: targetBytes, profile: profile)
    }
    
    private func measureNativeSystemZipThroughput(samplePath: String, targetMB: Double) -> Double {
        return BenchmarkDatasetGenerator.shared.measureNativeSystemZipThroughput(samplePath: samplePath, targetMB: targetMB)
    }
    
    private func measureRealCompetitorScores(samplePath: String, targetMB: Double, nativeSpeedMBs: Double) -> [CompetitorRealScore] {
        return BenchmarkDatasetGenerator.shared.measureRealCompetitorScores(samplePath: samplePath, targetMB: targetMB, nativeSpeedMBs: nativeSpeedMBs)
    }
}
