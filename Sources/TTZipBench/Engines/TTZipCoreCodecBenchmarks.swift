// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore
import CTTZipBridge

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
}
