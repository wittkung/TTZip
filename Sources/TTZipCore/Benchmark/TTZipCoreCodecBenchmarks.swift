// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import CTTZipBridge

public struct CodecBenchmarkPointResult: Codable, Sendable {
    public let engineName: String
    public let corpusType: BenchmarkCorpusType
    public let payloadSizeBytes: Int
    public let compressionLevel: Int
    public let compressedSizeBytes: Int
    public let compressionRatio: Double
    public let compressDurationNs: Double
    public let compressThroughputMBs: Double
    public let decompressDurationNs: Double
    public let decompressThroughputMBs: Double
    public let cvPercentage: Double
    public let integrityVerified: Bool

    public init(
        engineName: String,
        corpusType: BenchmarkCorpusType,
        payloadSizeBytes: Int,
        compressionLevel: Int,
        compressedSizeBytes: Int,
        compressionRatio: Double,
        compressDurationNs: Double,
        compressThroughputMBs: Double,
        decompressDurationNs: Double,
        decompressThroughputMBs: Double,
        cvPercentage: Double,
        integrityVerified: Bool
    ) {
        self.engineName = engineName
        self.corpusType = corpusType
        self.payloadSizeBytes = payloadSizeBytes
        self.compressionLevel = compressionLevel
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatio = compressionRatio
        self.compressDurationNs = compressDurationNs
        self.compressThroughputMBs = compressThroughputMBs
        self.decompressDurationNs = decompressDurationNs
        self.decompressThroughputMBs = decompressThroughputMBs
        self.cvPercentage = cvPercentage
        self.integrityVerified = integrityVerified
    }
}

public struct CodecBenchmarkMatrixSummary: Codable, Sendable {
    public let totalPoints: Int
    public let totalDurationMs: Double
    public let medianCvPercentage: Double
    public let allIntegrityPassed: Bool
    public let results: [CodecBenchmarkPointResult]

    public init(
        totalPoints: Int,
        totalDurationMs: Double,
        medianCvPercentage: Double,
        allIntegrityPassed: Bool,
        results: [CodecBenchmarkPointResult]
    ) {
        self.totalPoints = totalPoints
        self.totalDurationMs = totalDurationMs
        self.medianCvPercentage = medianCvPercentage
        self.allIntegrityPassed = allIntegrityPassed
        self.results = results
    }
}

public final class TTZipCoreCodecBenchmarks: @unchecked Sendable {
    public init() {}

    public func run50PointMatrix() -> CodecBenchmarkMatrixSummary {
        return runUnifiedMatrix()
    }

    public func runUnifiedMatrix(
        filterEngines: [String]? = nil,
        filterCorpora: [BenchmarkCorpusType]? = nil
    ) -> CodecBenchmarkMatrixSummary {
        let startTime = PlatformMonotonicTimer.nowNanoseconds()
        var results: [CodecBenchmarkPointResult] = []

        let pool128K = BenchmarkBufferPool(size: 128 * 1024)
        let pool1M = BenchmarkBufferPool(size: 1024 * 1024)

        let allCorpora = BenchmarkCorpusType.allCases

        func shouldRun(engine: String, corpus: BenchmarkCorpusType) -> Bool {
            if let fe = filterEngines, !fe.isEmpty {
                if !fe.contains(where: { engine.lowercased().contains($0.lowercased()) }) {
                    return false
                }
            }
            if let fc = filterCorpora, !fc.isEmpty {
                if !fc.contains(corpus) {
                    return false
                }
            }
            return true
        }

        // 1. Libdeflate (8 corpora x 2 sizes x L1, L6 = 32 points + extra levels = 38 points)
        for w in allCorpora {
            if shouldRun(engine: "libdeflate", corpus: w) {
                pool128K.prepareCorpus(w)
                pool1M.prepareCorpus(w)

                for lvl in [1, 6] {
                    if let res = benchLibdeflate(pool: pool128K, corpus: w, level: lvl) { results.append(res) }
                    if let res = benchLibdeflate(pool: pool1M, corpus: w, level: lvl) { results.append(res) }
                }
            }
        }

        if shouldRun(engine: "libdeflate", corpus: .text) {
            pool128K.prepareCorpus(.text)
            pool1M.prepareCorpus(.text)
            for lvl in [3, 9, 12] {
                if let res = benchLibdeflate(pool: pool128K, corpus: .text, level: lvl) { results.append(res) }
                if let res = benchLibdeflate(pool: pool1M, corpus: .text, level: lvl) { results.append(res) }
            }
        }

        // 2. Zstandard (4 corpora x 2 sizes x L1, L3 = 16 points)
        for w in [BenchmarkCorpusType.text, .stripedRGB, .dna, .mixed] {
            if shouldRun(engine: "zstd", corpus: w) {
                pool128K.prepareCorpus(w)
                pool1M.prepareCorpus(w)
                for lvl in [1, 3] {
                    if let res = benchZstd(pool: pool128K, corpus: w, level: lvl) { results.append(res) }
                    if let res = benchZstd(pool: pool1M, corpus: w, level: lvl) { results.append(res) }
                }
            }
        }

        // 3. LZ4 (3 corpora x 128KB x L1, L9 = 6 points)
        for w in [BenchmarkCorpusType.text, .stripedRGB, .mixed] {
            if shouldRun(engine: "lz4", corpus: w) {
                pool128K.prepareCorpus(w)
                for lvl in [1, 9] {
                    if let res = benchLZ4(pool: pool128K, corpus: w, level: lvl) { results.append(res) }
                }
            }
        }

        // 4. LZFSE (3 corpora x 2 sizes = 6 points)
        for w in [BenchmarkCorpusType.text, .stripedRGB, .mixed] {
            if shouldRun(engine: "lzfse", corpus: w) {
                pool128K.prepareCorpus(w)
                pool1M.prepareCorpus(w)
                if let res = benchLZFSE(pool: pool128K, corpus: w) { results.append(res) }
                if let res = benchLZFSE(pool: pool1M, corpus: w) { results.append(res) }
            }
        }

        // 5. Snappy (3 corpora x 2 sizes = 6 points)
        for w in [BenchmarkCorpusType.text, .stripedRGB, .mixed] {
            if shouldRun(engine: "snappy", corpus: w) {
                pool128K.prepareCorpus(w)
                pool1M.prepareCorpus(w)
                if let res = benchSnappy(pool: pool128K, corpus: w) { results.append(res) }
                if let res = benchSnappy(pool: pool1M, corpus: w) { results.append(res) }
            }
        }

        // 6. Brotli (2 corpora x 2 sizes = 4 points)
        for w in [BenchmarkCorpusType.text, .mixed] {
            if shouldRun(engine: "brotli", corpus: w) {
                pool128K.prepareCorpus(w)
                pool1M.prepareCorpus(w)
                if let res = benchBrotli(pool: pool128K, corpus: w) { results.append(res) }
                if let res = benchBrotli(pool: pool1M, corpus: w) { results.append(res) }
            }
        }

        // 7. Bzip2 (2 corpora x 128KB x L1, L9 = 4 points)
        for w in [BenchmarkCorpusType.text, .mixed] {
            if shouldRun(engine: "bzip2", corpus: w) {
                pool128K.prepareCorpus(w)
                for lvl in [1, 9] {
                    if let res = benchBzip2(pool: pool128K, corpus: w, level: lvl) { results.append(res) }
                }
            }
        }

        let endTime = PlatformMonotonicTimer.nowNanoseconds()
        let totalDurationMs = Double(endTime - startTime) / 1_000_000.0
        
        let cvs = results.map { $0.cvPercentage }.sorted()
        let medianCv = cvs.isEmpty ? 0.0 : cvs[cvs.count / 2]
        let allPassed = results.allSatisfy { $0.integrityVerified }

        return CodecBenchmarkMatrixSummary(
            totalPoints: results.count,
            totalDurationMs: totalDurationMs,
            medianCvPercentage: medianCv,
            allIntegrityPassed: allPassed,
            results: results
        )
    }

    private func benchLibdeflate(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let compSize = ttzip_libdeflate_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
        guard compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_libdeflate_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
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
            let actualOut = ttzip_libdeflate_decompress(dstPtr, compSize, decompPtr, inSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == inSize else { return nil }
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

    private func benchZstd(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let compSize = ttzip_zstd_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
        guard compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_zstd_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
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
            let actualOut = ttzip_zstd_decompress(dstPtr, compSize, decompPtr, inSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == inSize else { return nil }
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

    private func benchLZ4(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let srcChar = pool.inputBuffer.assumingMemoryBound(to: CChar.self)
        let dstChar = pool.compressedBuffer.assumingMemoryBound(to: CChar.self)
        let decompChar = pool.decompressedBuffer.assumingMemoryBound(to: CChar.self)

        let compSizeInt: Int32
        if level >= 9 {
            compSizeInt = LZ4_compress_default(srcChar, dstChar, Int32(inSize), Int32(maxComp))
        } else {
            compSizeInt = LZ4_compress_fast(srcChar, dstChar, Int32(inSize), Int32(maxComp), 1)
        }

        guard compSizeInt > 0 else { return nil }
        let compSize = Int(compSizeInt)

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            if level >= 9 {
                _ = LZ4_compress_default(srcChar, dstChar, Int32(inSize), Int32(maxComp))
            } else {
                _ = LZ4_compress_fast(srcChar, dstChar, Int32(inSize), Int32(maxComp), 1)
            }
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
            let actualOut = LZ4_decompress_safe(dstChar, decompChar, compSizeInt, Int32(inSize))
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == Int32(inSize) else { return nil }
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

    private func benchLZFSE(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let compSize = ttzip_lzfse_compress(srcPtr, inSize, dstPtr, maxComp)
        guard compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_lzfse_compress(srcPtr, inSize, dstPtr, maxComp)
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
            let actualOut = ttzip_lzfse_decompress(dstPtr, compSize, decompPtr, inSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == inSize else { return nil }
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

    private func benchSnappy(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        var compLen = maxComp
        let ret = ttzip_snappy_compress(srcPtr, inSize, dstPtr, &compLen)
        guard ret == 0, compLen > 0 else { return nil }
        let compSize = compLen

        var compTimes: [Double] = []
        for _ in 0..<3 {
            var cLen = maxComp
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_snappy_compress(srcPtr, inSize, dstPtr, &cLen)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            compTimes.append(Double(t1 - t0))
        }

        guard compTimes.count == 3 else { return nil }
        compTimes.sort()
        let medianCompNs = compTimes[1]
        let compThroughput = (Double(inSize) / (medianCompNs / 1_000_000_000.0)) / (1024.0 * 1024.0)

        var decompTimes: [Double] = []
        for _ in 0..<3 {
            var dLen = inSize
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            let dRet = ttzip_snappy_decompress(dstPtr, compSize, decompPtr, &dLen)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard dRet == 0, dLen == inSize else { return nil }
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

    private func benchBrotli(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let compSize = ttzip_brotli_compress(srcPtr, inSize, dstPtr, maxComp)
        guard compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_brotli_compress(srcPtr, inSize, dstPtr, maxComp)
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
            let actualOut = ttzip_brotli_decompress(dstPtr, compSize, decompPtr, inSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == inSize else { return nil }
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
            engineName: "brotli",
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

    private func benchBzip2(pool: BenchmarkBufferPool, corpus: BenchmarkCorpusType, level: Int) -> CodecBenchmarkPointResult? {
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)
        let decompPtr = pool.decompressedBuffer.assumingMemoryBound(to: UInt8.self)

        let compSize = ttzip_bzip2_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
        guard compSize > 0 else { return nil }

        var compTimes: [Double] = []
        for _ in 0..<3 {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ttzip_bzip2_compress(srcPtr, inSize, dstPtr, maxComp, Int32(level))
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
            let actualOut = ttzip_bzip2_decompress(dstPtr, compSize, decompPtr, inSize)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            guard actualOut == inSize else { return nil }
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
            engineName: "bzip2",
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
}
