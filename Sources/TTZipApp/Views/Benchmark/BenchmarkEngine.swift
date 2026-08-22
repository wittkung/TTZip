// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import QuartzCore
import TTZipCore

/// Multi-core hardware stress testing and efficiency benchmarking engine.
public final class BenchmarkEngine: @unchecked Sendable {
    public init() {}

    /// High-resolution monotonic nanoseconds provider
    @inline(__always)
    private func monotonicNanos() -> UInt64 {
        return PlatformMonotonicTimer.nowNanoseconds()
    }

    /// High-precision throughput calculator
    @inline(__always)
    private func calcThroughputMBs(bytes: Int, elapsedSecs: Double) -> Double {
        guard elapsedSecs > 0 else { return 0.0 }
        return (Double(bytes) / elapsedSecs) / (1024.0 * 1024.0)
    }

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

        let startNanos = monotonicNanos()
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
                let currentNanos = self.monotonicNanos()
                let elapsedNanos = max(1_000_000, currentNanos - startNanos)
                let elapsedSecs = Double(elapsedNanos) / 1_000_000_000.0
                let throughput = self.calcThroughputMBs(bytes: Int(prog.bytesProcessed), elapsedSecs: elapsedSecs)
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

        let endNanos = monotonicNanos()
        let elapsedNanos = max(1_000_000, endNanos - startNanos)
        let elapsed = Double(elapsedNanos) / 1_000_000_000.0

        let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputArchivePath)[.size] as? Int64) ?? totalBytes
        let throughput = calcThroughputMBs(bytes: Int(totalBytes), elapsedSecs: elapsed)

        // Measure decompression throughput
        let decompTargetDir = tempDir.appendingPathComponent("decomp_bench").path
        try? FileManager.default.createDirectory(atPath: decompTargetDir, withIntermediateDirectories: true)

        let decompStartNanos = monotonicNanos()
        let extractor = ArchiveEngineFactory.makeExtractor(for: format)
        try? await extractor.extract(archivePath: outputArchivePath, destinationDir: decompTargetDir)
        let decompEndNanos = monotonicNanos()
        let decompElapsedNanos = max(500_000, decompEndNanos - decompStartNanos)
        let decompElapsed = Double(decompElapsedNanos) / 1_000_000_000.0
        let decompSpeed = calcThroughputMBs(bytes: Int(totalBytes), elapsedSecs: decompElapsed)
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
        let startNanos = monotonicNanos()
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
                let currentNanos = self.monotonicNanos()
                let elapsedNanos = max(1_000_000, currentNanos - startNanos)
                let elapsedSecs = Double(elapsedNanos) / 1_000_000_000.0
                let throughput = self.calcThroughputMBs(bytes: Int(prog.bytesProcessed), elapsedSecs: elapsedSecs)
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

        let endNanos = monotonicNanos()
        let elapsedNanos = max(1_000_000, endNanos - startNanos)
        let elapsed = Double(elapsedNanos) / 1_000_000_000.0

        let compressedSize = (try? fm.attributesOfItem(atPath: outputArchivePath)[.size] as? Int64) ?? totalBytes
        let throughput = calcThroughputMBs(bytes: Int(totalBytes), elapsedSecs: elapsed)
        let ratio = totalBytes > 0 ? ((Double(compressedSize) / Double(totalBytes)) * 100.0) : 100.0

        let decompExtractDir = tempDir.appendingPathComponent("decomp_test").path
        let decompStartNanos = monotonicNanos()
        let extractor = ArchiveEngineFactory.makeExtractor(for: format)
        try? await extractor.extract(archivePath: outputArchivePath, destinationDir: decompExtractDir)
        let decompElapsedNanos = max(1_000_000, monotonicNanos() - decompStartNanos)
        let decompElapsed = Double(decompElapsedNanos) / 1_000_000_000.0
        let realDecompThroughput = calcThroughputMBs(bytes: Int(totalBytes), elapsedSecs: decompElapsed)

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
