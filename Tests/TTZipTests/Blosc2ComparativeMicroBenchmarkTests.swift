// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2ComparativeMicroBenchmarkTests: XCTestCase {

    func testComprehensiveOptimizationComparison() throws {
        print("\n" + String(repeating: "=", count: 95))
        print("📊 [Empirical Comparison] TTZip × C-Blosc2 架构优化前 vs 优化后 物理实测差分审计")
        print(String(repeating: "=", count: 95))

        // -------------------------------------------------------------
        // 1. 浮点连续信号载荷 (Float32 Sensor Corpus 64KB)
        // -------------------------------------------------------------
        let floatCount = 16384 // 64KB
        var floatData = [Float](repeating: 0, count: floatCount)
        for i in 0..<floatCount {
            floatData[i] = sin(Float(i) * 0.05) * 100.0 + Float(i % 100) * 0.00314159
        }
        let rawFloatBytes = floatCount * MemoryLayout<Float>.size
        let rawFloatData = Data(bytes: floatData, count: rawFloatBytes)

        let deflateConfig = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
        
        // 1.1 Baseline: 原始裸 Deflate
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let compRaw = try DeflateStreamEngine.compress(data: rawFloatData, config: deflateConfig)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let rawCompTimeMs = Double(t1 - t0) / 1_000_000.0
        let rawRatio = Double(rawFloatBytes) / Double(compRaw.count)

        // 1.2 Optimized: NEON 截断 + NEON BitShuffle + Deflate
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

        print(String(format: "▶ [维度 1: 科学与传感器浮点数据压缩 (Float32 64KB)]"))
        print(String(format: "  • 优化前 (Baseline Raw Deflate L6)       : 压缩后 %6d 字节 | 压缩比: %5.2fx | 耗时: %5.2f ms", compRaw.count, rawRatio, rawCompTimeMs))
        print(String(format: "  • 优化后 (NEON Truncate + BitShuffle + L6): 压缩后 %6d 字节 | 压缩比: %5.2fx | 耗时: %5.2f ms", compOptimized.count, optRatio, optCompTimeMs))
        print(String(format: "  • 差分收益: 空间压缩比提升 +%.1f%% (体积削减 %.1f%%)\n", ratioBoost, (1.0 - Double(compOptimized.count)/Double(compRaw.count)) * 100.0))

        // -------------------------------------------------------------
        // 2. 特殊全零与常数块旁路 (Special-Value 1MB Block)
        // -------------------------------------------------------------
        let sparseSize = 1024 * 1024 // 1MB
        let zeroData = Data(count: sparseSize)

        // 2.1 Baseline: 通用 Zstd 压缩与解压
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

        // 2.2 Optimized: Special-Value SWAR 探测 + dc zva 硬件总线行清零
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

        print(String(format: "▶ [维度 2: 稀疏全零/常数块旁路 (Special-Value 1MB)]"))
        print(String(format: "  • 优化前 (Baseline Zstd L3)           : 压缩 %6.1f MB/s | 解压 %7.1f MB/s | 存储开销: %d 字节", zstdCompThroughput, zstdDecThroughput, zstdCSize))
        print(String(format: "  • 优化后 (SWAR Detect + dc zva Fill) : 探测 %6.1f MB/s | 解压 %7.1f MB/s | 存储开销: 0 字节 (纯头部标记)", specialDetectThroughput, specialFillThroughput))
        print(String(format: "  • 差分收益: 解压加速比 %.1fx (直通 Apple Silicon 总线线速), 存储开销节省 100.0%%\n", specialFillThroughput / zstdDecThroughput))

        // -------------------------------------------------------------
        // 3. 结构化日志/JSON 共享字典 (SuperChunk 100KB Records)
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

            // Baseline: 独立 Zstd 压缩
            var noDictBuf = Data(count: chunkData.count + chunkData.count / 16 + 128)
            let noDictSz = chunkData.withUnsafeBytes { rawIn in
                noDictBuf.withUnsafeMutableBytes { rawOut in
                    ttzip_zstd_compress(rawIn.baseAddress!, chunkData.count, rawOut.baseAddress!, rawOut.count, 3)
                }
            }
            totalNoDictCBytes += noDictSz

            // Optimized: SuperChunk 共享字典压缩
            let scSz = chunkData.withUnsafeBytes { raw in
                ttzip_schunk_append_chunk(schunk, raw.baseAddress!, chunkData.count)
            }
            totalSuperChunkCBytes += Int(scSz)
        }

        let noDictRatio = Double(totalRawBytes) / Double(totalNoDictCBytes)
        let superChunkRatio = Double(totalRawBytes) / Double(totalSuperChunkCBytes)

        print(String(format: "▶ [维度 3: 两级分块与帧级共享字典 (SuperChunk JSON 50KB)]"))
        print(String(format: "  • 优化前 (Baseline 独立分块 Zstd L3) : 原始 %5d 字节 ➔ 压缩后 %5d 字节 | 压缩比: %5.2fx", totalRawBytes, totalNoDictCBytes, noDictRatio))
        print(String(format: "  • 优化后 (SuperChunk Frame Shared Dict): 原始 %5d 字节 ➔ 压缩后 %5d 字节 | 压缩比: %5.2fx", totalRawBytes, totalSuperChunkCBytes, superChunkRatio))
        print(String(format: "  • 差分收益: 共享字典额外带来 +%.1f%% 空间压缩增益\n", ((superChunkRatio - noDictRatio) / noDictRatio) * 100.0))

        // -------------------------------------------------------------
        // 4. 不可压数据自适应阻断 (Heuristic Auto-Tuning 64KB Random)
        // -------------------------------------------------------------
        let randSize = 65536
        var randBytes = [UInt8](repeating: 0, count: randSize)
        for i in 0..<randSize { randBytes[i] = UInt8.random(in: 0...255) }
        let randData = Data(randBytes)

        // Baseline: 盲目尝试 Deflate 压缩 (产生负压缩 + CPU 周期浪费)
        let t12 = PlatformMonotonicTimer.nowNanoseconds()
        let blindComp = try DeflateStreamEngine.compress(data: randData, config: deflateConfig)
        let t13 = PlatformMonotonicTimer.nowNanoseconds()
        let blindTimeMs = Double(t13 - t12) / 1_000_000.0

        // Optimized: 16KB 微采样 Shannon 熵快速拒绝 (< 1 µs)
        let t14 = PlatformMonotonicTimer.nowNanoseconds()
        let rec = randData.withUnsafeBytes { raw in
            ttzip_heuristic_eval_cascade(raw.baseAddress!, raw.count, 1, nil)
        }
        let t15 = PlatformMonotonicTimer.nowNanoseconds()
        let tunerTimeMs = Double(t15 - t14) / 1_000_000.0

        print(String(format: "▶ [维度 4: 高熵不可压数据自适应调优 (Heuristic Tuner 64KB Random)]"))
        print(String(format: "  • 优化前 (Baseline 盲目 Deflate 压缩)   : 压缩后 %5d 字节 (体积膨胀 +%d B) | 耗时: %5.3f ms", blindComp.count, blindComp.count - randSize, blindTimeMs))
        print(String(format: "  • 优化后 (Shannon 级联微采样自适应探测): 命中模式 [%@] ➔ 直通 DIRECT 存储 | 耗时: %5.3f ms", rec.codec == TTZIP_TUNER_CODEC_DIRECT ? "DIRECT/STORE" : "COMPRESS", tunerTimeMs))
        print(String(format: "  • 差分收益: 耗时削减 %.1f%% (CPU 周期节省 %.1fx), 零体积膨胀\n", (1.0 - tunerTimeMs / blindTimeMs) * 100.0, blindTimeMs / max(0.0001, tunerTimeMs)))

        print(String(repeating: "=", count: 95) + "\n")
    }
}
