// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// In-memory microbenchmark execution engine conforming to TurboBench and lzbench standards.
///
/// Features:
/// 1. Page-aligned contiguous memory operation eliminating disk I/O and file system locks.
/// 2. Monotonic hardware timer (`PlatformMonotonicTimer`) eliminating syscall context switch overhead.
/// 3. Adaptive 500ms time clamping with warmup passes eliminating timer quantization noise.
/// 4. Byte-level verification (`memcmp`) asserting codec output integrity.
public final class InMemoryBenchmarkEngine: Sendable {
    public static let shared = InMemoryBenchmarkEngine()

    private init() {
        PlatformMonotonicTimer.initialize()
    }

    /// Runs in-memory benchmark across configured format and compression level matrices.
    public func runInMemoryBenchmark(
        config: InMemoryBenchmarkConfig,
        progressCallback: (@Sendable (String) -> Void)? = nil
    ) async throws -> BenchmarkSuiteReport {
        let startTimeNanos = PlatformMonotonicTimer.nowNanoseconds()
        let calibration = PlatformMonotonicTimer.calibrationInfo()
        var results: [AlgorithmBenchmarkResult] = []

        progressCallback?("🚀 Initializing in-memory benchmark engine [Buffer: \(config.bufferSizeBytes / (1024 * 1024)) MB, Warmup: \(config.warmupPasses) passes, Window: \(config.minDurationMs) ms]...")

        // 1. Generate deterministic page-aligned test corpus
        var sampleSize = Int(config.bufferSizeBytes)
        var fileData: Data? = nil
        if let customPath = config.customInputPath, let data = try? Data(contentsOf: URL(fileURLWithPath: customPath)), !data.isEmpty {
            fileData = data
            sampleSize = data.count
        }

        guard let srcRaw = NativeCoreArchitecture.allocateAlignedPageBuffer(capacity: sampleSize) else {
            throw NSError(domain: "TTZipInMemoryBenchmark", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate aligned memory for benchmark source"])
        }
        let srcBuffer = srcRaw.assumingMemoryBound(to: UInt8.self)
        defer {
            NativeCoreArchitecture.deallocateAlignedPageBuffer(srcRaw)
        }

        if let data = fileData {
            data.withUnsafeBytes { raw in
                if let base = raw.baseAddress {
                    memcpy(srcBuffer, base, sampleSize)
                }
            }
        } else {
            generateBenchmarkCorpus(into: srcBuffer, size: sampleSize)
        }

        // 2. Iterate algorithm and level matrix
        let formats = config.selectedFormats
        let levels = config.selectedLevels

        for formatStr in formats {
            let normalizedFmt = formatStr.lowercased().trimmingCharacters(in: .whitespaces)
            for level in levels {
                if config.enableThermalGuard {
                    if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
                        progressCallback?("🔥 检测到硬件热饱和 (Thermal Pressure: \(ProcessInfo.processInfo.thermalState.rawValue))，进入自适应冷却休眠...")
                        while ProcessInfo.processInfo.thermalState != .nominal {
                            try await Task.sleep(nanoseconds: 500_000_000)
                        }
                        try await Task.sleep(nanoseconds: 1_500_000_000) // 稳频
                    }
                }
                if let res = benchmarkAlgorithm(
                    format: normalizedFmt,
                    level: level,
                    src: srcBuffer,
                    srcSize: sampleSize,
                    config: config,
                    progressCallback: progressCallback
                ) {
                    results.append(res)
                }
            }
        }

        let endTimeNanos = PlatformMonotonicTimer.nowNanoseconds()
        let totalWallDurationMs = Double(endTimeNanos - startTimeNanos) / 1_000_000.0
        let totalBytes = Int64(sampleSize) * Int64(results.count)
        let allPassed = results.allSatisfy { $0.integrityVerified }

        let report = BenchmarkSuiteReport(
            timerCalibration: calibration,
            totalInputBytes: totalBytes,
            totalWallDurationMs: totalWallDurationMs,
            results: results,
            allPassed: allPassed
        )

        return report
    }

    public func exportJSONReport(report: BenchmarkSuiteReport, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Deterministic Test Corpus Generator

    private func generateBenchmarkCorpus(into buffer: UnsafeMutablePointer<UInt8>, size: Int) {
        var seed: UInt64 = 0x123456789ABCDEF0
        func nextRand() -> UInt32 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return UInt32(truncatingIfNeeded: seed >> 32)
        }

        let phrases = [
            "{\"timestamp\":\"2026-08-17T04:40:00Z\",\"level\":\"INFO\",\"logger\":\"TTZipNativeCore\",\"message\":\"",
            "Apple Silicon ARM NEON SIMD Accelerated In-Memory Streaming Compression Pipeline Execution",
            "powturbo/TurboBench and inikep/lzbench high-precision hardware monotonic clock alignment",
            "Zero-copy APFS clonefile direct I/O memory mapped buffer page fault elimination matrix"
        ]

        var offset = 0
        while offset < size {
            let pick = Int(nextRand() % UInt32(phrases.count))
            let phrase = phrases[pick]
            let pBytes = Array(phrase.utf8)
            let copyLen = min(pBytes.count, size - offset)
            pBytes.withUnsafeBytes { rawPtr in
                buffer.advanced(by: offset).initialize(from: rawPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: copyLen)
            }
            offset += copyLen

            let randCount = min(16, size - offset)
            for i in 0..<randCount {
                buffer[offset + i] = UInt8(nextRand() & 0xFF)
            }
            offset += randCount
        }
    }
}
