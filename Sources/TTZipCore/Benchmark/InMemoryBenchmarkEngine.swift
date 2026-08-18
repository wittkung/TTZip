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

    // MARK: - Benchmark Algorithm Execution

    private func benchmarkAlgorithm(
        format: String,
        level: Int,
        src: UnsafeMutablePointer<UInt8>,
        srcSize: Int,
        config: InMemoryBenchmarkConfig,
        progressCallback: (@Sendable (String) -> Void)?
    ) -> AlgorithmBenchmarkResult? {
        let maxCompCap = srcSize + max(131072, srcSize / 8)
        guard let compRaw = NativeCoreArchitecture.allocateAlignedPageBuffer(capacity: maxCompCap),
              let decompRaw = NativeCoreArchitecture.allocateAlignedPageBuffer(capacity: srcSize) else {
            return nil
        }
        let compBuffer = compRaw.assumingMemoryBound(to: UInt8.self)
        let decompBuffer = decompRaw.assumingMemoryBound(to: UInt8.self)

        defer {
            NativeCoreArchitecture.deallocateAlignedPageBuffer(compRaw)
            NativeCoreArchitecture.deallocateAlignedPageBuffer(decompRaw)
        }

        let algoName: String
        let compFunc: @Sendable (UnsafePointer<UInt8>, Int, UnsafeMutablePointer<UInt8>, Int, Int) -> Int
        let decompFunc: @Sendable (UnsafePointer<UInt8>, Int, UnsafeMutablePointer<UInt8>, Int) -> Int

        switch format {
        case "zip", "deflate", "zip-deflate", "gz", "tar.gz":
            algoName = "ZIP-Deflate"
            compFunc = { s, sLen, d, dCap, lvl in
                return ttzip_libdeflate_compress(s, sLen, d, dCap, Int32(lvl))
            }
            decompFunc = { s, sLen, d, dCap in
                return ttzip_libdeflate_decompress(s, sLen, d, dCap)
            }

        case "zstd", "tar.zst", "zst":
            algoName = "Zstandard"
            compFunc = { s, sLen, d, dCap, lvl in
                return Int(ttzip_zstd_compress(s, sLen, d, dCap, Int32(lvl)))
            }
            decompFunc = { s, sLen, d, dCap in
                return Int(ttzip_zstd_decompress(s, sLen, d, dCap))
            }

        case "7z", "lzma2", "7z-lzma2":
            algoName = "7Z-LZMA2"
            compFunc = { s, sLen, d, dCap, lvl in
                var outLen: size_t = 0
                let rc = ttzip_lzma2_compress_mt_c(s, sLen, d, dCap, &outLen, Int32(lvl))
                return (rc == 0) ? Int(outLen) : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: size_t = 0
                let rc = ttzip_lzma2_decompress_mt_c(s, sLen, d, dCap, &outLen)
                return (rc == 0) ? Int(outLen) : 0
            }

        case "lz4":
            algoName = "LZ4"
            compFunc = { s, sLen, d, dCap, _ in
                return Int(LZ4_compress_default(UnsafeRawPointer(s).assumingMemoryBound(to: CChar.self),
                                                UnsafeMutableRawPointer(d).assumingMemoryBound(to: CChar.self),
                                                Int32(sLen),
                                                Int32(dCap)))
            }
            decompFunc = { s, sLen, d, dCap in
                return Int(LZ4_decompress_safe(UnsafeRawPointer(s).assumingMemoryBound(to: CChar.self),
                                               UnsafeMutableRawPointer(d).assumingMemoryBound(to: CChar.self),
                                               Int32(sLen),
                                               Int32(dCap)))
            }

        default:
            algoName = format.uppercased()
            compFunc = { s, sLen, d, dCap, lvl in
                return ttzip_libdeflate_compress(s, sLen, d, dCap, Int32(lvl))
            }
            decompFunc = { s, sLen, d, dCap in
                return ttzip_libdeflate_decompress(s, sLen, d, dCap)
            }
        }

        // 1. Warmup passes
        var compressedSize: Int = 0
        for _ in 0..<config.warmupPasses {
            compressedSize = compFunc(src, srcSize, compBuffer, maxCompCap, level)
            guard compressedSize > 0 else { return nil }
            let decompSize = decompFunc(compBuffer, compressedSize, decompBuffer, srcSize)
            guard decompSize == srcSize else { return nil }
        }

        // 2. Compression benchmark loop
        let targetDurationNanos = UInt64(config.minDurationMs) * 1_000_000
        var totalCompNanos: UInt64 = 0
        var compIterations: Int = 0
        var batchSize: Int = 1

        while totalCompNanos < targetDurationNanos {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            for _ in 0..<batchSize {
                _ = compFunc(src, srcSize, compBuffer, maxCompCap, level)
            }
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            let elapsed = (t1 >= t0) ? (t1 - t0) : 1
            totalCompNanos += elapsed
            compIterations += batchSize

            if elapsed < 10_000_000 && totalCompNanos < targetDurationNanos {
                batchSize = (elapsed > 0) ? max(1, batchSize * Int(10_000_000 / elapsed + 1)) : (batchSize * 2)
            }
        }

        let bestCompNanos = (compIterations > 0) ? (totalCompNanos / UInt64(compIterations)) : 1

        // 3. Decompression benchmark loop
        var totalDecompNanos: UInt64 = 0
        var decompIterations: Int = 0
        batchSize = 1

        while totalDecompNanos < targetDurationNanos {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            for _ in 0..<batchSize {
                _ = decompFunc(compBuffer, compressedSize, decompBuffer, srcSize)
            }
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            let elapsed = (t1 >= t0) ? (t1 - t0) : 1
            totalDecompNanos += elapsed
            decompIterations += batchSize

            if elapsed < 10_000_000 && totalDecompNanos < targetDurationNanos {
                batchSize = (elapsed > 0) ? max(1, batchSize * Int(10_000_000 / elapsed + 1)) : (batchSize * 2)
            }
        }

        let bestDecompNanos = (decompIterations > 0) ? (totalDecompNanos / UInt64(decompIterations)) : 1

        // 4. Memory verification
        let isVerified = (memcmp(src, decompBuffer, srcSize) == 0)

        let result = AlgorithmBenchmarkResult(
            algorithm: algoName,
            level: level,
            uncompressedBytes: Int64(srcSize),
            compressedBytes: Int64(compressedSize),
            compressionTimeNs: bestCompNanos,
            decompressionTimeNs: bestDecompNanos,
            iterationsCompleted: compIterations,
            integrityVerified: isVerified,
            useBinaryUnits: config.useBinaryUnits
        )

        if let cb = progressCallback {
            let rowStr = formatRowOutput(result: result, turboBenchFormat: config.turboBenchOutput)
            cb("ROW:\(rowStr)")
        }

        return result
    }

    // MARK: - Output Formatting & Report Serialization

    public func formatRowOutput(result: AlgorithmBenchmarkResult, turboBenchFormat: Bool) -> String {
        let verifyStr = result.integrityVerified ? "PASSED (OK)" : "FAILED (ERR)"
        let cSizeStr = "\(result.compressedBytes)"
        let algoPadded = result.algorithm.padding(toLength: 16, withPad: " ", startingAt: 0)
        let cSizePadded = cSizeStr.padding(toLength: 11, withPad: " ", startingAt: 0)

        if turboBenchFormat {
            return String(format: "%@ | %2d | %@ | %6.2fx | %5.1f%% | %11.1f MB/s | %11.1f MB/s | %5d | %@",
                          algoPadded,
                          result.level,
                          cSizePadded,
                          result.ratio,
                          result.spaceSavingsPct,
                          result.compressionSpeedMBs,
                          result.decompressionSpeedMBs,
                          result.iterationsCompleted,
                          verifyStr)
        } else {
            return String(format: "%@ | L%-2d | CSize: %@ | Ratio: %5.2fx (%4.1f%%) | Comp: %9.1f MB/s | Decomp: %9.1f MB/s | Iters: %4d | %@",
                          algoPadded,
                          result.level,
                          cSizePadded,
                          result.ratio,
                          result.spaceSavingsPct,
                          result.compressionSpeedMBs,
                          result.decompressionSpeedMBs,
                          result.iterationsCompleted,
                          verifyStr)
        }
    }

    public func generateTurboBenchTable(report: BenchmarkSuiteReport) -> String {
        var out = ""
        out += "========================================================================================================================\n"
        out += "📊 In-Memory Benchmark Results (TurboBench / lzbench Model / Apple Silicon RAM)\n"
        out += "========================================================================================================================\n"
        out += "Algorithm        | Lvl| CSize (B)   |  Ratio | Space % |    Comp (MB/s) |   Decomp (MB/s) | Iters | Integrity\n"
        out += "------------------------------------------------------------------------------------------------------------------------\n"
        for r in report.results {
            out += formatRowOutput(result: r, turboBenchFormat: true) + "\n"
        }
        out += "========================================================================================================================\n"
        out += String(format: "⏱️ Wall Duration: %.2f ms | Processed Throughput: %.1f MB | Clock: %@ (%llu Hz) | Resolution: %.1f ns\n",
                      report.totalWallDurationMs,
                      Double(report.totalInputBytes) / (1024.0 * 1024.0),
                      report.timerCalibration.timerBackend as NSString,
                      report.timerCalibration.frequencyHz,
                      report.timerCalibration.resolutionNanos)
        return out
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
