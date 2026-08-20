// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import CTTZipBridge

public struct MultiLevelCompressionPoint: Sendable, Codable {
    public let engine: String
    public let corpus: String
    public let level: Int
    public let uncompressedBytes: Int
    public let baseCompressedBytes: Int
    public let headCompressedBytes: Int
    public let deltaBytes: Int
    public let deltaPercent: Double
    public let verdict: String

    public init(
        engine: String,
        corpus: String,
        level: Int,
        uncompressedBytes: Int,
        baseCompressedBytes: Int,
        headCompressedBytes: Int,
        deltaBytes: Int,
        deltaPercent: Double,
        verdict: String
    ) {
        self.engine = engine
        self.corpus = corpus
        self.level = level
        self.uncompressedBytes = uncompressedBytes
        self.baseCompressedBytes = baseCompressedBytes
        self.headCompressedBytes = headCompressedBytes
        self.deltaBytes = deltaBytes
        self.deltaPercent = deltaPercent
        self.verdict = verdict
    }
}

public final class CompressionDeltaEngine: Sendable {
    public static let shared = CompressionDeltaEngine()
    public init() {}

    public func runCompressionSweep(
        corpora: [BenchmarkCorpusType] = [.text, .mixed, .stripedRGB, .dna],
        baselineMap: [String: Int]? = nil
    ) -> [MultiLevelCompressionPoint] {
        let pool = BenchmarkBufferPool(size: 1024 * 1024)
        let inSize = pool.size
        let maxComp = inSize * 2
        let srcPtr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = pool.compressedBuffer.assumingMemoryBound(to: UInt8.self)

        var points: [MultiLevelCompressionPoint] = []

        for corpus in corpora {
            pool.prepareCorpus(corpus)

            // 1. Deflate (libdeflate) L1..L12
            for lvl in 1...12 {
                let compSize = ttzip_libdeflate_compress(srcPtr, inSize, dstPtr, maxComp, Int32(lvl))
                guard compSize > 0 else { continue }

                let key = "libdeflate_\(corpus.rawValue)_\(lvl)"
                let baseSize = baselineMap?[key] ?? compSize
                let delta = compSize - baseSize
                let pct = baseSize > 0 ? (Double(delta) / Double(baseSize)) * 100.0 : 0.0

                let verdict: String
                if pct < -0.01 { verdict = "OPTIMIZATION" }
                else if pct > 0.10 { verdict = "REGRESSION" }
                else if pct > 0.01 { verdict = "DRIFT" }
                else { verdict = "IDENTICAL" }

                points.append(MultiLevelCompressionPoint(
                    engine: "libdeflate",
                    corpus: corpus.rawValue,
                    level: lvl,
                    uncompressedBytes: inSize,
                    baseCompressedBytes: baseSize,
                    headCompressedBytes: compSize,
                    deltaBytes: delta,
                    deltaPercent: pct,
                    verdict: verdict
                ))
            }

            // 2. Zstandard L1..L19
            for lvl in 1...19 {
                let compSize = ttzip_zstd_compress(srcPtr, inSize, dstPtr, maxComp, Int32(lvl))
                guard compSize > 0 else { continue }

                let key = "zstd_\(corpus.rawValue)_\(lvl)"
                let baseSize = baselineMap?[key] ?? compSize
                let delta = compSize - baseSize
                let pct = baseSize > 0 ? (Double(delta) / Double(baseSize)) * 100.0 : 0.0

                let verdict: String
                if pct < -0.01 { verdict = "OPTIMIZATION" }
                else if pct > 0.10 { verdict = "REGRESSION" }
                else if pct > 0.01 { verdict = "DRIFT" }
                else { verdict = "IDENTICAL" }

                points.append(MultiLevelCompressionPoint(
                    engine: "zstd",
                    corpus: corpus.rawValue,
                    level: lvl,
                    uncompressedBytes: inSize,
                    baseCompressedBytes: baseSize,
                    headCompressedBytes: compSize,
                    deltaBytes: delta,
                    deltaPercent: pct,
                    verdict: verdict
                ))
            }

            // 3. Bzip2 L1..L9
            for lvl in 1...9 {
                let compSize = ttzip_bzip2_compress(srcPtr, inSize, dstPtr, maxComp, Int32(lvl))
                guard compSize > 0 else { continue }

                let key = "bzip2_\(corpus.rawValue)_\(lvl)"
                let baseSize = baselineMap?[key] ?? compSize
                let delta = compSize - baseSize
                let pct = baseSize > 0 ? (Double(delta) / Double(baseSize)) * 100.0 : 0.0

                let verdict: String
                if pct < -0.01 { verdict = "OPTIMIZATION" }
                else if pct > 0.10 { verdict = "REGRESSION" }
                else if pct > 0.01 { verdict = "DRIFT" }
                else { verdict = "IDENTICAL" }

                points.append(MultiLevelCompressionPoint(
                    engine: "bzip2",
                    corpus: corpus.rawValue,
                    level: lvl,
                    uncompressedBytes: inSize,
                    baseCompressedBytes: baseSize,
                    headCompressedBytes: compSize,
                    deltaBytes: delta,
                    deltaPercent: pct,
                    verdict: verdict
                ))
            }
        }

        return points
    }
}
