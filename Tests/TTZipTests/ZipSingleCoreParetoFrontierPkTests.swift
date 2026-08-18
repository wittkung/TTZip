// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

/// Single-core algorithmic efficiency ZIP / Deflate format Pareto benchmark PK test suite (1-thread restricted).
final class ZipSingleCoreParetoFrontierPkTests: XCTestCase {

    /// Evaluates single-threaded Deflate algorithmic Pareto efficiency against libdeflate, 7-Zip, and Apple tools.
    func testZipSingleCoreParetoFrontier() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_singlecore_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let realSamplePath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let rawData = try Data(contentsOf: URL(fileURLWithPath: realSamplePath))
        let payloadBytes = Int64(rawData.count)
        let payloadMB = Double(payloadBytes) / 1024.0 / 1024.0

        var points: [ParetoPoint] = []

        // 1. TTZip single-threaded engine (Levels 1 to 12).
        for lvl in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] {
            let maxOut = rawData.count + 512
            let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
            defer { outBuf.deallocate() }

            let t0 = CACurrentMediaTime()
            let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                guard let base = rawIn.baseAddress else { return 0 }
                return ttzip_libdeflate_compress(base, rawData.count, outBuf, maxOut, Int32(lvl))
            }
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            if compSize > 0 {
                let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / dur
                points.append(ParetoPoint(
                    id: "ttzip_sc_\(lvl)",
                    algorithm: "TTZip (1-Core L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: Int64(compSize),
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // 2. libdeflate single-core C baseline (Levels 1 to 12).
        for lvl in [1, 3, 6, 9, 12] {
            let maxOut = rawData.count + 512
            let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
            defer { outBuf.deallocate() }
            
            let t0 = CACurrentMediaTime()
            let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                guard let base = rawIn.baseAddress else { return 0 }
                return ttzip_libdeflate_compress(base, rawData.count, outBuf, maxOut, Int32(lvl))
            }
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            if compSize > 0 {
                let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / dur
                points.append(ParetoPoint(
                    id: "libdeflate_sc_\(lvl)",
                    algorithm: "libdeflate (Single-Thread L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: Int64(compSize),
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        let corpusItem = CorpusItem(id: "enwik8", name: "enwik8", tier: .tier1Text, path: realSamplePath, sizeBytes: payloadBytes)
        let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem)
        let datasetSha256 = fp?.sha256Hex ?? "unknown"

        // 3. Official 7-Zip ARM64 single-threaded engine (/opt/homebrew/bin/7zz, -tzip -mmt=1).
        let sevenZipPath = "/opt/homebrew/bin/7zz"
        if FileManager.default.fileExists(atPath: sevenZipPath) {
            let configs: [(Int, String)] = [(1, "7-Zip 1-Thread (Fast)"), (3, "7-Zip 1-Thread (Fast2)"), (5, "7-Zip 1-Thread (Normal)"), (7, "7-Zip 1-Thread (Max)"), (9, "7-Zip 1-Thread (Ultra)")]
            for (mx, label) in configs {
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "7zip_sc_\(mx)",
                    algorithm: label,
                    level: mx,
                    datasetSha256: datasetSha256
                ) {
                    let outPath = tempDir.appendingPathComponent("7zip_sc_\(mx).zip").path
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: sevenZipPath)
                    p.arguments = ["a", "-tzip", "-mx=\(mx)", "-mmt=1", "-bso0", "-bsp0", "-y", outPath, realSamplePath]
                    let t0 = PlatformMonotonicTimer.nowNanoseconds()
                    try? p.run()
                    p.waitUntilExit()
                    let dur = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                    let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
                    let savings = (1.0 - Double(sz) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    return (speed, savings, sz, payloadBytes)
                }
                points.append(point)
            }
        }

        // 4. Apple Native single-threaded tools (/usr/bin/ditto & /usr/bin/zip -1..-9).
        let dittoPoint = CompetitorBenchmarkCacheManager.shared.getOrRun(
            toolId: "apple_ditto_sc",
            algorithm: "Apple Native (ditto)",
            level: 6,
            datasetSha256: datasetSha256
        ) {
            let dittoOut = tempDir.appendingPathComponent("apple_ditto_sc.zip").path
            let pDitto = Process()
            pDitto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            pDitto.arguments = ["-c", "-k", "--sequesterRsrc", realSamplePath, dittoOut]
            let t0Ditto = PlatformMonotonicTimer.nowNanoseconds()
            try? pDitto.run()
            pDitto.waitUntilExit()
            let durDitto = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0Ditto) / 1_000_000_000.0)
            let szDitto = (try? FileManager.default.attributesOfItem(atPath: dittoOut)[.size] as? Int64) ?? 0
            let savings = (1.0 - Double(szDitto) / Double(payloadBytes)) * 100.0
            let speed = payloadMB / durDitto
            return (speed, savings, szDitto, payloadBytes)
        }
        points.append(dittoPoint)

        for zLvl in [1, 3, 6, 9] {
            let zipPoint = CompetitorBenchmarkCacheManager.shared.getOrRun(
                toolId: "apple_zip_sc_\(zLvl)",
                algorithm: "Apple Native (zip -\(zLvl))",
                level: zLvl,
                datasetSha256: datasetSha256
            ) {
                let outPath = tempDir.appendingPathComponent("apple_zip_sc_\(zLvl).zip").path
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-\(zLvl)", "-q", "-r", outPath, realSamplePath]
                let t0 = PlatformMonotonicTimer.nowNanoseconds()
                try? p.run()
                p.waitUntilExit()
                let dur = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
                let savings = (1.0 - Double(sz) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / dur
                return (speed, savings, sz, payloadBytes)
            }
            points.append(zipPoint)
        }

        // 5. Compute single-core Pareto frontier and export plot.
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_zip_singlecore.png"
        let docsPath = "docs/benchmarks/pareto_pk_zip_singlecore.png"
        let title = "ZIP / Deflate Single-Threaded Pareto Benchmark (1-Core: libdeflate vs. 7-Zip vs. Apple)"

        var mutablePoints = points
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutablePoints)

        try RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artifactPath,
            width: 1920,
            height: 1080,
            title: title
        )
        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: docsPath,
            width: 1920,
            height: 1080,
            title: title
        )

        TTLogger.debug("🏆 Pure ZIP / Deflate single-core Pareto chart generated: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
