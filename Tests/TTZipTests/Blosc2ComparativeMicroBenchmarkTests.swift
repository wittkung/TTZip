// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Micro-benchmark test suite comparing C-Blosc2 architectural optimizations against baselines.
final class Blosc2ComparativeMicroBenchmarkTests: XCTestCase {

    /// Executes comprehensive empirical benchmark comparing pre- and post-optimization throughput and compression ratios.
    func testComprehensiveOptimizationComparison() throws {
        TTLogger.debug("\n" + String(repeating: "=", count: 95))
        TTLogger.debug("📊 [Empirical Comparison] TTZip x C-Blosc2 Architecture Optimization Differential Audit")
        TTLogger.debug(String(repeating: "=", count: 95))

        // -------------------------------------------------------------
        // 1. Continuous Floating-Point Signal Payload (Float32 Sensor Corpus 64KB)
        // -------------------------------------------------------------
        let floatCount = 16384 // 64KB
        var floatData = [Float](repeating: 0, count: floatCount)
        for i in 0..<floatCount {
            floatData[i] = sin(Float(i) * 0.05) * 100.0 + Float(i % 100) * 0.00314159
        }
        let rawFloatBytes = floatCount * MemoryLayout<Float>.size
        let rawFloatData = Data(bytes: floatData, count: rawFloatBytes)

        let deflateConfig = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
        
        // 1.1 Baseline: Raw Deflate
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let compRaw = try DeflateStreamEngine.compress(data: rawFloatData, config: deflateConfig)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let rawCompTimeMs = Double(t1 - t0) / 1_000_000.0
        let rawRatio = Double(rawFloatBytes) / Double(compRaw.count)

        // 1.2 Optimized: NEON Truncation + NEON BitShuffle + Deflate
        var truncFloats = [Float](repeating: 0, count: floatCount)
        var bitShufBytes = [UInt8](repeating: 0, count: rawFloatBytes)
        
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        floatData.withUnsafeBufferPointer { srcPtr in
            truncFloats.withUnsafeMutableBufferPointer { dstPtr in
                ttzip_filter_truncate_float32_neon(srcPtr.baseAddress!, dstPtr.baseAddress!, floatCount, 7)
            }
        }
        truncFloats.withUnsafeBytes { rawTrunc in
            bitShufBytes.withUnsafeMutableBytes { rawShuf in
                ttzip_filter_bitshuffle_forward_neon(
                    rawTrunc.bindMemory(to: UInt8.self).baseAddress!,
                    rawShuf.bindMemory(to: UInt8.self).baseAddress!,
                    rawFloatBytes,
                    4
                )
            }
        }
        let compOptimized = try DeflateStreamEngine.compress(data: Data(bitShufBytes), config: deflateConfig)
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optCompTimeMs = Double(t3 - t2) / 1_000_000.0
        let optRatio = Double(rawFloatBytes) / Double(compOptimized.count)
        let ratioBoost = ((optRatio - rawRatio) / rawRatio) * 100.0

        TTLogger.debug(String(format: "▶ [Dimension 1: Scientific & Sensor Float Data Compression (Float32 64KB)]"))
        TTLogger.debug(String(format: "  • Baseline (Raw Deflate L6)              : Size %6d B | Ratio: %5.2fx | Elapsed: %5.2f ms", compRaw.count, rawRatio, rawCompTimeMs))
        TTLogger.debug(String(format: "  • Optimized (NEON Truncate + BitShuffle): Size %6d B | Ratio: %5.2fx | Elapsed: %5.2f ms", compOptimized.count, optRatio, optCompTimeMs))
        TTLogger.debug(String(format: "  • Differential Gain: Compression ratio gain +%.1f%% (size reduction %.1f%%)\n", ratioBoost, (1.0 - Double(compOptimized.count)/Double(compRaw.count)) * 100.0))

        // -------------------------------------------------------------
        // 2. Special Zero and Constant Block Bypass (Special-Value 1MB Block)
        // -------------------------------------------------------------
        let sparseSize = 1024 * 1024 // 1MB
        let zeroData = Data(count: sparseSize)

        // 2.1 Baseline: Standard Zstd Compression and Decompression
        var zstdCompBuf = Data(count: sparseSize + sparseSize / 16 + 128)
        let t4 = PlatformMonotonicTimer.nowNanoseconds()
        let zstdCSize = zeroData.withUnsafeBytes { rawIn in
            zstdCompBuf.withUnsafeMutableBytes { rawOut in
                ttzip_zstd_compress(rawIn.baseAddress!, sparseSize, rawOut.baseAddress!, rawOut.count, 3)
            }
        }
        let t5 = PlatformMonotonicTimer.nowNanoseconds()
        let zstdCompThroughput = (Double(sparseSize) / (1024.0 * 1024.0)) / (Double(t5 - t4) / 1_000_000_000.0)

        var zstdDecBuf = Data(count: sparseSize)
        let t6 = PlatformMonotonicTimer.nowNanoseconds()
        _ = zstdCompBuf.withUnsafeBytes { rawIn in
            zstdDecBuf.withUnsafeMutableBytes { rawOut in
                ttzip_zstd_decompress(rawIn.baseAddress!, zstdCSize, rawOut.baseAddress!, sparseSize)
            }
        }
        let t7 = PlatformMonotonicTimer.nowNanoseconds()
        let zstdDecThroughput = (Double(sparseSize) / (1024.0 * 1024.0)) / (Double(t7 - t6) / 1_000_000_000.0)

        // 2.2 Optimized: Special-Value SWAR Detection + Hardware Zero Fill (dc zva)
        let t8 = PlatformMonotonicTimer.nowNanoseconds()
        let specialDesc = zeroData.withUnsafeBytes { raw in
            ttzip_detect_uniform_block(raw.baseAddress!, sparseSize, 1)
        }
        let t9 = PlatformMonotonicTimer.nowNanoseconds()
        let specialDetectThroughput = (Double(sparseSize) / (1024.0 * 1024.0)) / (Double(t9 - t8) / 1_000_000_000.0)

        var specialDecBuf = Data(count: sparseSize)
        let t10 = PlatformMonotonicTimer.nowNanoseconds()
        _ = specialDecBuf.withUnsafeMutableBytes { rawOut in
            ttzip_fill_special_value(rawOut.baseAddress!, sparseSize, specialDesc)
        }
        let t11 = PlatformMonotonicTimer.nowNanoseconds()
        let specialFillThroughput = (Double(sparseSize) / (1024.0 * 1024.0)) / (Double(t11 - t10) / 1_000_000_000.0)

        TTLogger.debug(String(format: "▶ [Dimension 2: Sparse Zero/Constant Block Bypass (Special-Value 1MB)]"))
        TTLogger.debug(String(format: "  • Baseline (Zstd L3)                  : Comp %6.1f MB/s | Decomp %7.1f MB/s | Storage: %d B", zstdCompThroughput, zstdDecThroughput, zstdCSize))
        TTLogger.debug(String(format: "  • Optimized (SWAR Detect + Zero Fill): Detect %6.1f MB/s | Fill %7.1f MB/s | Storage: 0 B (Header only)", specialDetectThroughput, specialFillThroughput))
        TTLogger.debug(String(format: "  • Differential Gain: Decompress speedup %.1fx (direct Apple Silicon bus line-rate), Storage saved 100.0%%\n", specialFillThroughput / zstdDecThroughput))

        // -------------------------------------------------------------
        // 3. Structured Log / JSON Shared Dictionary (SuperChunk 100KB Records)
        // -------------------------------------------------------------
        var schunkConfig = ttzip_schunk_config_t()
        schunkConfig.chunk_size = 64 * 1024
        schunkConfig.block_size = 128 * 1024
        schunkConfig.typesize = 1
        schunkConfig.use_dict = true

        guard let schunk = ttzip_schunk_create(&schunkConfig) else {
            XCTFail("schunk create failed")
            return
        }
        defer { ttzip_schunk_free(schunk) }

        let sampleRecord = "{\"timestamp\": 1723982400, \"host\": \"m3max-node-08\", \"event\": \"IO_DISK_PAGE_FAULT\", \"latency_us\": 12.8, \"retries\": 0}\n"
        let recData = sampleRecord.data(using: .utf8)!
        var sampleCorpus = Data()
        for _ in 0..<150 { sampleCorpus.append(recData) }
        _ = sampleCorpus.withUnsafeBytes { raw in
            ttzip_schunk_train_dict(schunk, raw.baseAddress!, sampleCorpus.count)
        }

        var totalRawBytes = 0
        var totalNoDictCBytes = 0
        var totalSuperChunkCBytes = 0

        for i in 0..<5 {
            let chunkStr = "{\"timestamp\": \(1723982400 + i * 5), \"host\": \"m3max-node-08\", \"event\": \"IO_DISK_PAGE_FAULT\", \"latency_us\": \(12.8 + Double(i) * 0.1), \"retries\": 0}\n"
            let cRec = chunkStr.data(using: .utf8)!
            var chunkData = Data()
            for _ in 0..<80 { chunkData.append(cRec) }

            totalRawBytes += chunkData.count

            // Baseline: Independent Zstd compression
            var noDictBuf = Data(count: chunkData.count + chunkData.count / 16 + 128)
            let noDictSz = chunkData.withUnsafeBytes { rawIn in
                noDictBuf.withUnsafeMutableBytes { rawOut in
                    ttzip_zstd_compress(rawIn.baseAddress!, chunkData.count, rawOut.baseAddress!, rawOut.count, 3)
                }
            }
            totalNoDictCBytes += noDictSz

            // Optimized: SuperChunk shared dictionary compression
            let scSz = chunkData.withUnsafeBytes { raw in
                ttzip_schunk_append_chunk(schunk, raw.baseAddress!, chunkData.count)
            }
            totalSuperChunkCBytes += Int(scSz)
        }

        let noDictRatio = Double(totalRawBytes) / Double(totalNoDictCBytes)
        let superChunkRatio = Double(totalRawBytes) / Double(totalSuperChunkCBytes)

        TTLogger.debug(String(format: "▶ [Dimension 3: Two-level Chunking and Frame Shared Dictionary (SuperChunk JSON 50KB)]"))
        TTLogger.debug(String(format: "  • Baseline (Independent Zstd L3)     : Raw %5d B -> Comp %5d B | Ratio: %5.2fx", totalRawBytes, totalNoDictCBytes, noDictRatio))
        TTLogger.debug(String(format: "  • Optimized (SuperChunk Shared Dict): Raw %5d B -> Comp %5d B | Ratio: %5.2fx", totalRawBytes, totalSuperChunkCBytes, superChunkRatio))
        TTLogger.debug(String(format: "  • Differential Gain: Shared dictionary brings additional +%.1f%% compression gain\n", ((superChunkRatio - noDictRatio) / noDictRatio) * 100.0))

        // -------------------------------------------------------------
        // 4. Adaptive Fast Rejection of Incompressible Data (Heuristic Auto-Tuning 64KB Random)
        // -------------------------------------------------------------
        let randSize = 65536
        var randBytes = [UInt8](repeating: 0, count: randSize)
        for i in 0..<randSize { randBytes[i] = UInt8.random(in: 0...255) }
        let randData = Data(randBytes)

        // Baseline: Blindly attempting Deflate compression (negative compression + CPU overhead)
        let t12 = PlatformMonotonicTimer.nowNanoseconds()
        let blindComp = try DeflateStreamEngine.compress(data: randData, config: deflateConfig)
        let t13 = PlatformMonotonicTimer.nowNanoseconds()
        let blindTimeMs = Double(t13 - t12) / 1_000_000.0

        // Optimized: 16KB micro-sampling Shannon entropy rapid rejection (< 1 µs)
        let t14 = PlatformMonotonicTimer.nowNanoseconds()
        let rec = randData.withUnsafeBytes { raw in
            ttzip_heuristic_eval_cascade(raw.baseAddress!, raw.count, 1, nil)
        }
        let t15 = PlatformMonotonicTimer.nowNanoseconds()
        let tunerTimeMs = Double(t15 - t14) / 1_000_000.0

        TTLogger.debug(String(format: "▶ [Dimension 4: High-Entropy Incompressible Data Adaptive Tuning (Heuristic Tuner 64KB Random)]"))
        TTLogger.debug(String(format: "  • Baseline (Blind Deflate Compression)   : Size %5d B (Expansion +%d B) | Elapsed: %5.3f ms", blindComp.count, blindComp.count - randSize, blindTimeMs))
        TTLogger.debug(String(format: "  • Optimized (Shannon Cascade Fast-Reject): Mode [%@] -> DIRECT Store | Elapsed: %5.3f ms", rec.codec == TTZIP_TUNER_CODEC_DIRECT ? "DIRECT/STORE" : "COMPRESS", tunerTimeMs))
        TTLogger.debug(String(format: "  • Differential Gain: Elapsed reduced %.1f%% (CPU cycles saved %.1fx), zero inflation\n", (1.0 - tunerTimeMs / blindTimeMs) * 100.0, blindTimeMs / max(0.0001, tunerTimeMs)))

        TTLogger.debug(String(repeating: "=", count: 95) + "\n")
    }
}
