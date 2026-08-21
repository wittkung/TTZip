// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension InMemoryBenchmarkEngine {
    
    // MARK: - Benchmark Algorithm Execution

    internal func benchmarkAlgorithm(
        format: String,
        level: Int,
        src: UnsafeMutablePointer<UInt8>,
        srcSize: Int,
        config: InMemoryBenchmarkConfig,
        progressCallback: (@Sendable (String) -> Void)?
    ) -> AlgorithmBenchmarkResult? {
        let maxCompCap = max(srcSize + max(131072, srcSize / 4), ttzip_rust_snappy_max_compressed_length(srcSize) + 65536)
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
                var outLen: Int = 0
                let st = ttzip_rust_deflate_compress(s, sLen, d, dCap, Int32(lvl), &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_deflate_decompress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }

        case "zstd", "tar.zst", "zst":
            algoName = "Zstandard"
            compFunc = { s, sLen, d, dCap, lvl in
                var outLen: Int = 0
                let st = ttzip_rust_zstd_compress_advanced(s, sLen, d, dCap, Int32(lvl), 0, 0, 0, 0, false, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_zstd_decompress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }

        case "7z", "lzma2", "7z-lzma2":
            algoName = "7Z-LZMA2"
            compFunc = { s, sLen, d, dCap, lvl in
                var outLen: Int = 0
                let st = ttzip_rust_fl2_compress(s, sLen, d, dCap, Int32(lvl), 0, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_fl2_decompress(s, sLen, d, dCap, 0, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }

        case "lz4":
            algoName = "LZ4"
            compFunc = { s, sLen, d, dCap, _ in
                var outLen: Int = 0
                let st = ttzip_rust_lz4_compress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_lz4_decompress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }

        case "snappy", "sz":
            algoName = "Google-Snappy"
            compFunc = { s, sLen, d, dCap, _ in
                var outLen: Int = 0
                let st = ttzip_rust_snappy_compress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_snappy_decompress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }

        default:
            algoName = format.uppercased()
            compFunc = { s, sLen, d, dCap, lvl in
                var outLen: Int = 0
                let st = ttzip_rust_deflate_compress(s, sLen, d, dCap, Int32(lvl), &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
            }
            decompFunc = { s, sLen, d, dCap in
                var outLen: Int = 0
                let st = ttzip_rust_deflate_decompress(s, sLen, d, dCap, &outLen)
                return st == TTZIP_STATUS_OK ? outLen : 0
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
}
