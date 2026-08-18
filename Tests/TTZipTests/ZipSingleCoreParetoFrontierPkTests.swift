// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
import Compression
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

        let corpusItem = CorpusItem(id: "enwik8", name: "enwik8", tier: .tier1Text, path: realSamplePath, sizeBytes: payloadBytes)
        let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem)
        let datasetSha256 = fp?.sha256Hex ?? "unknown"

        var points: [ParetoPoint] = []
        var stepCounter = 1
        let totalStepsEstimate = 22

        TestLogger.atomicPrint("\n" + TestTerminalRenderer.badge(.perf) + " \(TestTerminalRenderer.ANSI.bold)[Single-Core Benchmark] Starting 100MB enwik8 pure 1-thread PK...\(TestTerminalRenderer.ANSI.reset)")

        // 1. TTZip single-threaded engine across the 8 standard Tiers (Tiers 0 to 7).
        for (tierIdx, profile) in ZipCompressionProfile.allProfiles.enumerated() {
            let maxOut = rawData.count + 512
            let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
            defer { outBuf.deallocate() }

            if tierIdx >= 5 {
                let forceRerunHigh = ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN_ZOPFLI"] == "1" || ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN_TTZIP_HIGH"] == "1"
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "ttzip_sc_\(tierIdx)",
                    algorithm: "TTZip \(tierIdx) (\(profile.name))",
                    level: tierIdx,
                    datasetSha256: datasetSha256,
                    forceRerun: forceRerunHigh
                ) {
                    let t0 = CACurrentMediaTime()
                    let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                        guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                        var zopts = TTZipZopfliOptions(
                            compression_level: profile.deflateLevel,
                            num_iterations: profile.zopfliIterations,
                            block_splitting: profile.blockSplitting ? 1 : 0,
                            max_block_splits: profile.maxBlockSplits,
                            early_exit_threshold: profile.earlyExitThreshold
                        )
                        return ttzip_zopfli_compress_block_with_history(base, rawData.count, nil, 0, outBuf, maxOut, &zopts, 1)
                    }
                    let dur = max(1e-6, CACurrentMediaTime() - t0)
                    let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    return (speed, savings, Int64(compSize), payloadBytes)
                }
                let durMs = (payloadMB / point.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "TTZip 1-Core",
                    testName: "Tier \(tierIdx) (\(profile.name))",
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                points.append(point)
            } else {
                let t0 = CACurrentMediaTime()
                let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                    guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    if profile.level == .store {
                        memcpy(outBuf, base, rawData.count)
                        return rawData.count
                    } else {
                        guard let comp = ttzip_deflate_compressor_alloc(Int32(profile.deflateLevel)) else { return 0 }
                        defer { ttzip_deflate_compressor_free(comp) }
                        return ttzip_deflate_compress(comp, base, rawData.count, outBuf, maxOut)
                    }
                }
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                if compSize > 0 {
                    let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    let pt = ParetoPoint(
                        id: "ttzip_sc_\(tierIdx)",
                        algorithm: "TTZip \(tierIdx) (\(profile.name))",
                        level: tierIdx,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: Int64(compSize),
                        uncompressedBytes: payloadBytes
                    )
                    let row = TestTerminalRenderer.renderAlignedRow(
                        index: stepCounter,
                        total: totalStepsEstimate,
                        badge: .perf,
                        target: "TTZip 1-Core",
                        testName: "Tier \(tierIdx) (\(profile.name))",
                        durationMs: dur * 1000.0
                    )
                    TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: speed) + " | " + String(format: "%.2f MB", Double(compSize)/(1024*1024)))
                    stepCounter += 1
                    points.append(pt)
                }
            }
        }

        // 2. libdeflate single-core C baseline (Levels 1 to 12).
        for lvl in [1, 3, 6, 9, 12] {
            let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                toolId: "libdeflate_sc_\(lvl)",
                algorithm: "libdeflate (Single-Thread L\(lvl))",
                level: lvl,
                datasetSha256: datasetSha256
            ) {
                let maxOut = rawData.count + 512
                let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
                defer { outBuf.deallocate() }
                
                let t0 = CACurrentMediaTime()
                let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                    guard let base = rawIn.baseAddress else { return 0 }
                    return ttzip_libdeflate_compress(base, rawData.count, outBuf, maxOut, Int32(lvl))
                }
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / dur
                return (speed, savings, Int64(compSize), payloadBytes)
            }
            let durMs = (payloadMB / point.throughputMBs) * 1000.0
            let row = TestTerminalRenderer.renderAlignedRow(
                index: stepCounter,
                total: totalStepsEstimate,
                badge: .perf,
                target: "libdeflate",
                testName: "Level \(lvl)",
                durationMs: durMs
            )
            TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
            stepCounter += 1
            points.append(point)
        }

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
                let durMs = (payloadMB / point.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "7-Zip 1-Core",
                    testName: label,
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
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
        let durMsDitto = (payloadMB / dittoPoint.throughputMBs) * 1000.0
        let rowDitto = TestTerminalRenderer.renderAlignedRow(
            index: stepCounter,
            total: totalStepsEstimate,
            badge: .perf,
            target: "Apple Native",
            testName: "ditto",
            durationMs: durMsDitto
        )
        TestLogger.atomicPrint(rowDitto + " | " + TestTerminalRenderer.formatThroughput(mbs: dittoPoint.throughputMBs) + " | " + String(format: "%.2f MB", Double(dittoPoint.compressedBytes)/(1024*1024)))
        stepCounter += 1
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
            let durMs = (payloadMB / zipPoint.throughputMBs) * 1000.0
            let row = TestTerminalRenderer.renderAlignedRow(
                index: stepCounter,
                total: totalStepsEstimate,
                badge: .perf,
                target: "Apple Native",
                testName: "zip -\(zLvl)",
                durationMs: durMs
            )
            TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: zipPoint.throughputMBs) + " | " + String(format: "%.2f MB", Double(zipPoint.compressedBytes)/(1024*1024)))
            stepCounter += 1
            points.append(zipPoint)
        }

        // 5. minizip-ng (/opt/homebrew/bin/minizip-ng, Single-Thread Levels 1, 6, 9).
        let minizipNgPath = "/opt/homebrew/bin/minizip-ng"
        if FileManager.default.fileExists(atPath: minizipNgPath) {
            for mzLvl in [1, 6, 9] {
                let mzPoint = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "minizip_ng_sc_\(mzLvl)",
                    algorithm: "minizip-ng (Single-Thread L\(mzLvl))",
                    level: mzLvl,
                    datasetSha256: datasetSha256
                ) {
                    let outPath = tempDir.appendingPathComponent("minizip_ng_sc_\(mzLvl).zip").path
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: minizipNgPath)
                    p.arguments = ["-\(mzLvl)", outPath, realSamplePath]
                    let t0 = PlatformMonotonicTimer.nowNanoseconds()
                    try? p.run()
                    p.waitUntilExit()
                    let dur = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                    let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
                    let savings = (1.0 - Double(sz) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    return (speed, savings, sz, payloadBytes)
                }
                let durMs = (payloadMB / mzPoint.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "minizip-ng",
                    testName: "Level \(mzLvl)",
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: mzPoint.throughputMBs) + " | " + String(format: "%.2f MB", Double(mzPoint.compressedBytes)/(1024*1024)))
                stepCounter += 1
                points.append(mzPoint)
            }
        }

        // 6. Apple libcompression (COMPRESSION_ZLIB / Deflate hardware accelerated).
        let libcompPoint = CompetitorBenchmarkCacheManager.shared.getOrRun(
            toolId: "apple_libcompression_zlib",
            algorithm: "Apple libcompression (COMPRESSION_ZLIB)",
            level: 5,
            datasetSha256: datasetSha256
        ) {
            let maxOut = rawData.count + 512
            let libcompOut = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
            defer { libcompOut.deallocate() }
            let t0Libcomp = CACurrentMediaTime()
            let compSizeLibcomp = rawData.withUnsafeBytes { rawIn -> size_t in
                guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_encode_buffer(libcompOut, maxOut, base, rawData.count, nil, COMPRESSION_ZLIB)
            }
            let durLibcomp = max(1e-6, CACurrentMediaTime() - t0Libcomp)
            let savings = (1.0 - Double(compSizeLibcomp) / Double(payloadBytes)) * 100.0
            let speed = payloadMB / durLibcomp
            return (speed, savings, Int64(compSizeLibcomp), payloadBytes)
        }
        let durMsLibcomp = (payloadMB / libcompPoint.throughputMBs) * 1000.0
        let rowLibcomp = TestTerminalRenderer.renderAlignedRow(
            index: stepCounter,
            total: totalStepsEstimate,
            badge: .perf,
            target: "Apple libcomp",
            testName: "COMPRESSION_ZLIB",
            durationMs: durMsLibcomp
        )
        TestLogger.atomicPrint(rowLibcomp + " | " + TestTerminalRenderer.formatThroughput(mbs: libcompPoint.throughputMBs) + " | " + String(format: "%.2f MB", Double(libcompPoint.compressedBytes)/(1024*1024)))
        stepCounter += 1
        points.append(libcompPoint)

        // 7. Compute single-core Pareto frontier and export plot.
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/11878c2a-4d32-493c-b708-82cec3b141ec/pareto_pk_zip_singlecore.png"
        let docsPath = "docs/benchmarks/pareto_pk_zip_singlecore.png"
        let title = "ZIP / Deflate Single-Threaded Pareto Benchmark (1-Core: TTZip vs. libdeflate vs. Apple libcompression vs. 7-Zip)"

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
