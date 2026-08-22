// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore
import CTTZipBridge

extension TTZipCoreCodecBenchmarks {
    
    func benchLibdeflate(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compSize: Int = 0
        let status = ttzip_rust_deflate_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level), &compSize)
        guard status == TTZIP_STATUS_OK, compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var cSize: Int = 0
            _ = ttzip_rust_deflate_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level), &cSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var dSize: Int = 0
            let dStatus = ttzip_rust_deflate_decompress(dstPtr, compSize, decompPtr, inSize, &dSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dStatus == TTZIP_STATUS_OK && dSize == inSize else { return nil }
            decompTimes.append(Double(t1 - t0))
        }

        guard decompTimes.count == 3 else { return nil }
        decompTimes.sort()
        let medianDecompNs = decompTimes[1]
        let decompThroughput = (Double(inSize) / (medianDecompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        let isMatch = memcmp(pool.inputBuffer, pool.decompressedBuffer, inSize) == 0

        let mean = (compTimes[0] + compTimes[1] + compTimes[2]) / 3.0
        let variance = ((compTimes[0] - mean) * (compTimes[0] - mean) + (compTimes[1] - mean) * (compTimes[1] - mean) + (compTimes[2] - mean) * (compTimes[2] - mean)) / 3.0
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0

        return CodecBenchmarkPointResult(
            engineName: "libdeflate",
            corpusType: corpus,
            payloadSizeBytes: inSize,
            compressionLevel: level,
            compressedSizeBytes: compSize,
            compressionRatio: Double(compSize) / Double(inSize),
            compressDurationNs: medianCompNs,
            compressThroughputMBs: compThroughput,
            decompressDurationNs: medianDecompNs,
            decompressThroughputMBs: decompThroughput,
            cvPercentage: cv,
            integrityVerified: isMatch
        )
    }

    func benchZstd(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compSize: Int = 0
        let status = ttzip_rust_zstd_compress_advanced(srcPtr, inSize, dstPtr, maxComp, Int32(level), 0, 0, 0, 0, false, &compSize)
        guard status == TTZIP_STATUS_OK, compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var cSize: Int = 0
            _ = ttzip_rust_zstd_compress_advanced(srcPtr, inSize, dstPtr, maxComp, Int32(level), 0, 0, 0, 0, false, &cSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var dSize: Int = 0
            let dStatus = ttzip_rust_zstd_decompress(dstPtr, compSize, decompPtr, inSize, &dSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dStatus == TTZIP_STATUS_OK && dSize == inSize else { return nil }
            decompTimes.append(Double(t1 - t0))
        }

        guard decompTimes.count == 3 else { return nil }
        decompTimes.sort()
        let medianDecompNs = decompTimes[1]
        let decompThroughput = (Double(inSize) / (medianDecompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        let isMatch = memcmp(pool.inputBuffer, pool.decompressedBuffer, inSize) == 0

        let mean = (compTimes[0] + compTimes[1] + compTimes[2]) / 3.0
        let variance = ((compTimes[0] - mean) * (compTimes[0] - mean) + (compTimes[1] - mean) * (compTimes[1] - mean) + (compTimes[2] - mean) * (compTimes[2] - mean)) / 3.0
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0

        return CodecBenchmarkPointResult(
            engineName: "zstd",
            corpusType: corpus,
            payloadSizeBytes: inSize,
            compressionLevel: level,
            compressedSizeBytes: compSize,
            compressionRatio: Double(compSize) / Double(inSize),
            compressDurationNs: medianCompNs,
            compressThroughputMBs: compThroughput,
            decompressDurationNs: medianDecompNs,
            decompressThroughputMBs: decompThroughput,
            cvPercentage: cv,
            integrityVerified: isMatch
        )
    }

    func benchLZ4(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compSize: Int = 0
        let status = ttzip_rust_lz4_compress(srcPtr, inSize, dstPtr, maxComp, &compSize)
        guard status == TTZIP_STATUS_OK, compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var cSize: Int = 0
            _ = ttzip_rust_lz4_compress(srcPtr, inSize, dstPtr, maxComp, &cSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var dSize: Int = 0
            let dStatus = ttzip_rust_lz4_decompress(dstPtr, compSize, decompPtr, inSize, &dSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dStatus == TTZIP_STATUS_OK && dSize == inSize else { return nil }
            decompTimes.append(Double(t1 - t0))
        }

        guard decompTimes.count == 3 else { return nil }
        decompTimes.sort()
        let medianDecompNs = decompTimes[1]
        let decompThroughput = (Double(inSize) / (medianDecompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        let isMatch = memcmp(srcPtr, decompPtr, inSize) == 0

        let mean = (compTimes[0] + compTimes[1] + compTimes[2]) / 3.0
        let variance = ((compTimes[0] - mean) * (compTimes[0] - mean) + (compTimes[1] - mean) * (compTimes[1] - mean) + (compTimes[2] - mean) * (compTimes[2] - mean)) / 3.0
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0

        return CodecBenchmarkPointResult(
            engineName: "lz4",
            corpusType: corpus,
            payloadSizeBytes: inSize,
            compressionLevel: level,
            compressedSizeBytes: compSize,
            compressionRatio: Double(compSize) / Double(inSize),
            compressDurationNs: medianCompNs,
            compressThroughputMBs: compThroughput,
            decompressDurationNs: medianDecompNs,
            decompressThroughputMBs: decompThroughput,
            cvPercentage: cv,
            integrityVerified: isMatch
        )
    }

    func benchLZFSE(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compSize: Int = 0
        let status = ttzip_rust_lzfse_compress(srcPtr, inSize, dstPtr, maxComp, &compSize)
        guard status == TTZIP_STATUS_OK, compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var cSize: Int = 0
            _ = ttzip_rust_lzfse_compress(srcPtr, inSize, dstPtr, maxComp, &cSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            var dSize: Int = 0
            let dStatus = ttzip_rust_lzfse_decompress(dstPtr, compSize, decompPtr, inSize, &dSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dStatus == TTZIP_STATUS_OK && dSize == inSize else { return nil }
            decompTimes.append(Double(t1 - t0))
        }

        guard decompTimes.count == 3 else { return nil }
        decompTimes.sort()
        let medianDecompNs = decompTimes[1]
        let decompThroughput = (Double(inSize) / (medianDecompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        let isMatch = memcmp(srcPtr, decompPtr, inSize) == 0

        let mean = (compTimes[0] + compTimes[1] + compTimes[2]) / 3.0
        let variance = ((compTimes[0] - mean) * (compTimes[0] - mean) + (compTimes[1] - mean) * (compTimes[1] - mean) + (compTimes[2] - mean) * (compTimes[2] - mean)) / 3.0
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0

        return CodecBenchmarkPointResult(
            engineName: "lzfse",
            corpusType: corpus,
            payloadSizeBytes: inSize,
            compressionLevel: 0,
            compressedSizeBytes: compSize,
            compressionRatio: Double(compSize) / Double(inSize),
            compressDurationNs: medianCompNs,
            compressThroughputMBs: compThroughput,
            decompressDurationNs: medianDecompNs,
            decompressThroughputMBs: decompThroughput,
            cvPercentage: cv,
            integrityVerified: isMatch
        )
    }

    func benchSnappy(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compLen: Int = 0
        let ret = ttzip_rust_snappy_compress(srcPtr, inSize, dstPtr, maxComp, &compLen)
        guard ret == TTZIP_STATUS_OK, compLen > 0 else { return nil }
        let compSize = compLen

        var compTimes: [Double] = []
        for _ in 0..<3 {
            var cLen = 0
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_rust_snappy_compress(srcPtr, inSize, dstPtr, maxComp, &cLen)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            var dLen = 0
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            let dRet = ttzip_rust_snappy_decompress(dstPtr, compSize, decompPtr, inSize, &dLen)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dRet == TTZIP_STATUS_OK, dLen == inSize else { return nil }
            decompTimes.append(Double(t1 - t0))
        }

        guard decompTimes.count == 3 else { return nil }
        decompTimes.sort()
        let medianDecompNs = decompTimes[1]
        let decompThroughput = (Double(inSize) / (medianDecompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        let isMatch = memcmp(srcPtr, decompPtr, inSize) == 0

        let mean = (compTimes[0] + compTimes[1] + compTimes[2]) / 3.0
        let variance = ((compTimes[0] - mean) * (compTimes[0] - mean) + (compTimes[1] - mean) * (compTimes[1] - mean) + (compTimes[2] - mean) * (compTimes[2] - mean)) / 3.0
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0

        return CodecBenchmarkPointResult(
            engineName: "snappy",
            corpusType: corpus,
            payloadSizeBytes: inSize,
            compressionLevel: 0,
            compressedSizeBytes: compSize,
            compressionRatio: Double(compSize) / Double(inSize),
            compressDurationNs: medianCompNs,
            compressThroughputMBs: compThroughput,
            decompressDurationNs: medianDecompNs,
            decompressThroughputMBs: decompThroughput,
            cvPercentage: cv,
            integrityVerified: isMatch
        )
    }

    func benchBrotli(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        return nil
    }

    func benchBzip2(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        return nil
    }
}
