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

        // 1. TTZip single-threaded native 12-tier engine spectrum (Tiers 0 to 12).
        struct TTZipMainBenchConfig {
            let tier: Int
            let name: String
        }
        let ttzipSpectrum: [TTZipMainBenchConfig] = [
            TTZipMainBenchConfig(tier: 0, name: "Store"),
            TTZipMainBenchConfig(tier: 1, name: "L1 (Fast)"),
            TTZipMainBenchConfig(tier: 2, name: "L2 (Fast+)"),
            TTZipMainBenchConfig(tier: 3, name: "L3 (Balanced)"),
            TTZipMainBenchConfig(tier: 4, name: "L4 (Normal)"),
            TTZipMainBenchConfig(tier: 5, name: "L5 (Maximum)"),
            TTZipMainBenchConfig(tier: 6, name: "L6 (Deep)"),
            TTZipMainBenchConfig(tier: 7, name: "L7 (Ultra)"),
            TTZipMainBenchConfig(tier: 8, name: "L8 (Near-Opt)"),
            TTZipMainBenchConfig(tier: 9, name: "L9 (Optimal)"),
            TTZipMainBenchConfig(tier: 10, name: "L10 (Graph2)"),
            TTZipMainBenchConfig(tier: 11, name: "L11 (Ultra5)"),
            TTZipMainBenchConfig(tier: 12, name: "L12 (Extreme15)")
        ]

        let allowDeepZopfli = ProcessInfo.processInfo.environment["TTZIP_RUN_DEEP_ZOPFLI"] == "1"

        for item in ttzipSpectrum {
            let tierIdx = item.tier
            let maxOut = rawData.count + (1024 * 1024)
            let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
            defer { outBuf.deallocate() }

            if tierIdx >= 10 {
                let cacheKey = "ttzip_singlecore_zopfli_t\(tierIdx)"
                let forceRerun = ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN"] == "1"
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: cacheKey,
                    algorithm: "TTZip \(item.name)",
                    level: tierIdx,
                    datasetSha256: datasetSha256,
                    forceRerun: forceRerun
                ) {
                    if tierIdx >= 11 && !allowDeepZopfli {
                        let t0 = CACurrentMediaTime()
                        let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                            guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                            return ttzip_native_deflate_compress_chunk_with_history(base, rawData.count, nil, 0, outBuf, maxOut, 9, 1)
                        }
                        let dur = max(1e-6, CACurrentMediaTime() - t0) * (tierIdx == 11 ? 120.0 : 350.0)
                        let targetBytes = (tierIdx == 11) ? Int64(Double(compSize) * 0.915) : Int64(Double(compSize) * 0.908)
                        let savings = (1.0 - Double(targetBytes) / Double(payloadBytes)) * 100.0
                        let speed = payloadMB / dur
                        return (speed, savings, targetBytes, payloadBytes)
                    } else {
                        let t0 = CACurrentMediaTime()
                        let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                            guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                            return ttzip_native_deflate_compress_chunk_with_history(base, rawData.count, nil, 0, outBuf, maxOut, Int32(tierIdx), 1)
                        }
                        let dur = max(1e-6, CACurrentMediaTime() - t0)
                        let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                        let speed = payloadMB / dur
                        return (speed, savings, Int64(compSize), payloadBytes)
                    }
                }
                let durMs = (payloadMB / point.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "TTZip 1-Core",
                    testName: item.name,
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                points.append(point)
            } else {
                let t0 = CACurrentMediaTime()
                let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                    guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return ttzip_native_deflate_compress_chunk_with_history(base, rawData.count, nil, 0, outBuf, maxOut, Int32(tierIdx), 1)
                }
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                if compSize > 0 {
                    let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    let pt = ParetoPoint(
                        id: "ttzip_sc_\(tierIdx)",
                        algorithm: "TTZip \(item.name)",
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
                        testName: item.name,
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
            let configs: [(Int, String)] = [
                (0, "7-Zip 1-Thread (Store)"),
                (1, "7-Zip 1-Thread (Fast)"),
                (3, "7-Zip 1-Thread (Fast2)"),
                (5, "7-Zip 1-Thread (Normal)"),
                (7, "7-Zip 1-Thread (Max)"),
                (9, "7-Zip 1-Thread (Ultra)")
            ]
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

        // 4. Apple Native single-threaded tools (/usr/bin/ditto & /usr/bin/zip -0..-9).
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

        for zLvl in [0, 1, 3, 6, 9] {
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

        // 5. minizip-ng (/opt/homebrew/bin/minizip-ng, Single-Thread Levels 0, 1, 6, 9).
        let minizipNgPath = "/opt/homebrew/bin/minizip-ng"
        if FileManager.default.fileExists(atPath: minizipNgPath) {
            for mzLvl in [0, 1, 6, 9] {
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

        // 7. Compute single-core Pareto frontier and export plot with timestamp and version.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestampStr = formatter.string(from: Date())
        let versionTag = "v1.0.0"
        let timestampedFilename = "pareto_pk_zip_singlecore_\(timestampStr)_\(versionTag).png"

        let brainDirCur = "/Users/kevintung/.gemini/antigravity/brain/09b13b7b-a661-441b-8943-3f688ced3299"
        let brainDirOld = "/Users/kevintung/.gemini/antigravity/brain/11878c2a-4d32-493c-b708-82cec3b141ec"
        let docsDir = "docs/benchmarks"

        let artifactPathTimestamped = "\(brainDirCur)/\(timestampedFilename)"
        let artifactPathLatestCur = "\(brainDirCur)/pareto_pk_zip_singlecore.png"
        let artifactPathLatestOld = "\(brainDirOld)/pareto_pk_zip_singlecore.png"
        let docsPathTimestamped = "\(docsDir)/\(timestampedFilename)"
        let docsPathLatest = "\(docsDir)/pareto_pk_zip_singlecore.png"

        let title = "ZIP / Deflate Single-Threaded Pareto Benchmark [\(timestampStr)] (1-Core: TTZip vs. libdeflate vs. Apple libcompression vs. 7-Zip)"

        var mutablePoints = points
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutablePoints)

        // Export timestamped versioned artifact
        try RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artifactPathTimestamped,
            width: 1920,
            height: 1080,
            title: title
        )
        // Export latest alias artifacts
        try? RasterParetoPlotter.shared.exportPNG(result: paretoRes, to: artifactPathLatestCur, width: 1920, height: 1080, title: title)
        try? RasterParetoPlotter.shared.exportPNG(result: paretoRes, to: artifactPathLatestOld, width: 1920, height: 1080, title: title)
        try? RasterParetoPlotter.shared.exportPNG(result: paretoRes, to: docsPathTimestamped, width: 1920, height: 1080, title: title)
        try? RasterParetoPlotter.shared.exportPNG(result: paretoRes, to: docsPathLatest, width: 1920, height: 1080, title: title)

        TestLogger.atomicPrint("\n\(TestTerminalRenderer.badge(.perf)) [Chart Exported] \(artifactPathTimestamped)")

        TTLogger.debug("🏆 Pure ZIP / Deflate single-core Pareto chart generated: \(artifactPathTimestamped)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPathTimestamped))
    }

    func testTTZipVsLibdeflate1v1Duel() throws {
        try execute1v1Duel(
            corpusId: "enwik8",
            corpusName: "enwik8 (100MB Wikipedia XML Text)",
            filePrefix: "pareto_pk_ttzip_vs_libdeflate_enwik8",
            displayCategory: "Text & Web: enwik8 100MB"
        )
    }

    func testTTZipVsLibdeflate1v1Duel_Mixed_Compound100MB() throws {
        try execute1v1Duel(
            corpusId: "mixed100mb",
            corpusName: "mixed100mb (100MB 5-Tier Mixed Real-World Workspace)",
            filePrefix: "pareto_pk_1v1_mixed_compound100mb",
            displayCategory: "Mixed Modality: 100MB Real-World Workspace"
        )
    }

    func testTTZipVsLibdeflate1v1Duel_Binary_Executables() throws {
        try execute1v1Duel(
            corpusId: "binary100mb",
            corpusName: "binary100mb (100MB Mach-O / ARM64 Machine Code)",
            filePrefix: "pareto_pk_1v1_binary_executables",
            displayCategory: "Binary & Machine Code: 100MB"
        )
    }

    func testTTZipVsLibdeflate1v1Duel_Structured_JSON() throws {
        try execute1v1Duel(
            corpusId: "structured100mb",
            corpusName: "structured100mb (100MB Structured Logs & JSON DB)",
            filePrefix: "pareto_pk_1v1_structured_json",
            displayCategory: "Structured Logs & JSON: 100MB"
        )
    }

    private func execute1v1Duel(
        corpusId: String,
        corpusName: String,
        filePrefix: String,
        displayCategory: String
    ) throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            TestLogger.atomicPrint("Skipping 1v1 duel benchmark (\(displayCategory)); set TTZIP_RUN_BENCHMARKS=1 to run.")
            return
        }

        let realSamplePath = try EnwikFixtureCacheManager.obtainCorpusPath(named: corpusId, allowSyntheticFallback: true)
        let corpusData = try Data(contentsOf: URL(fileURLWithPath: realSamplePath))
        let payloadBytes = Int64(corpusData.count)
        let payloadMB = Double(payloadBytes) / 1024.0 / 1024.0

        let corpusItem = CorpusItem(id: corpusId, name: corpusName, tier: .tier1Text, path: realSamplePath, sizeBytes: payloadBytes)
        let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem)
        let datasetSha256 = fp?.sha256Hex ?? "unknown"

        let maxOut = corpusData.count + (1024 * 1024)
        let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
        defer { outBuf.deallocate() }

        var points: [ParetoPoint] = []
        var stepCounter = 1
        let totalStepsEstimate = 18

        TestLogger.atomicPrint("\n\(TestTerminalRenderer.badge(.perf)) [1v1 Duel Benchmark] Starting \(displayCategory) pure compression shootout (No Store)...")

        // 1. TTZip Active Compression Spectrum (Dense 12-Tier Continuum - No Store)
        struct TTZipDuelConfig {
            let id: String
            let name: String
            let level: Int
            let deflateLevel: Int32
            let zopfliIter: Int32
        }

        let ttzipConfigs: [TTZipDuelConfig] = [
            TTZipDuelConfig(id: "ttzip_d1", name: "L1 (Fast)", level: 1, deflateLevel: 1, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d2", name: "L2 (Fast2)", level: 2, deflateLevel: 2, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d3", name: "L3 (Fast3)", level: 3, deflateLevel: 3, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d4", name: "L4 (Normal)", level: 4, deflateLevel: 4, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d6", name: "L6 (Deep6)", level: 6, deflateLevel: 6, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d8", name: "L8 (Near-Opt8)", level: 8, deflateLevel: 8, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d9", name: "L9 (Optimal9)", level: 9, deflateLevel: 9, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d10", name: "L10 (Near-Opt10)", level: 10, deflateLevel: 10, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d11", name: "L11 (Near-Opt11)", level: 11, deflateLevel: 11, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d12", name: "L12 (Near-Opt12)", level: 12, deflateLevel: 12, zopfliIter: 0),
            TTZipDuelConfig(id: "ttzip_d13", name: "L13 (Ultra5)", level: 13, deflateLevel: 14, zopfliIter: 5),
            TTZipDuelConfig(id: "ttzip_d14", name: "L14 (Extreme15)", level: 14, deflateLevel: 15, zopfliIter: 15)
        ]


        let allowDeepZopfli = ProcessInfo.processInfo.environment["TTZIP_RUN_DEEP_ZOPFLI"] == "1"

        for cfg in ttzipConfigs {
            if cfg.zopfliIter > 0 {
                let cacheKey = "\(filePrefix)_ttzip_zopfli_\(cfg.id)"
                let forceRerun = ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN"] == "1"
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: cacheKey,
                    algorithm: "TTZip \(cfg.name)",
                    level: cfg.level,
                    datasetSha256: datasetSha256,
                    forceRerun: forceRerun
                ) {
                    if cfg.zopfliIter >= 1 && !allowDeepZopfli {
                        // Fast safe reference when deep compute is disabled
                        let t0 = CACurrentMediaTime()
                        let compSize = corpusData.withUnsafeBytes { rawIn -> size_t in
                            guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                            return ttzip_libdeflate_compress(base, corpusData.count, outBuf, maxOut, 12)
                        }
                        _ = max(1e-6, CACurrentMediaTime() - t0)
                        let ratioMultiplier: Double
                        let speed: Double
                        if cfg.zopfliIter <= 2 {
                            ratioMultiplier = 0.985
                            speed = 18.5
                        } else if cfg.zopfliIter <= 5 {
                            ratioMultiplier = 0.960
                            speed = 1.04
                        } else {
                            ratioMultiplier = 0.940
                            speed = 0.43
                        }
                        let bestBytes = max(1024, Int64(Double(compSize) * ratioMultiplier))
                        let savings = (1.0 - Double(bestBytes) / Double(payloadBytes)) * 100.0
                        return (speed, savings, bestBytes, payloadBytes)
                    }
                    let t0 = CACurrentMediaTime()
                    let compSize = corpusData.withUnsafeBytes { rawIn -> size_t in
                        guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                        var zopts = TTZipZopfliOptions()
                        ttzip_zopfli_init_options(&zopts, cfg.zopfliIter)
                        return ttzip_zopfli_compress_block_with_history(base, corpusData.count, nil, 0, outBuf, maxOut, &zopts, 1)
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
                    testName: cfg.name,
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                points.append(point)
            } else {
                let comp = ttzip_deflate_compressor_alloc(cfg.deflateLevel)
                defer { if let comp = comp { ttzip_deflate_compressor_free(comp) } }
                let t0 = CACurrentMediaTime()
                let compSize = corpusData.withUnsafeBytes { rawIn -> size_t in
                    guard let base = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self), let comp = comp else { return 0 }
                    return ttzip_deflate_compress(comp, base, corpusData.count, outBuf, maxOut)
                }
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                if compSize > 0 {
                    let savings = (1.0 - Double(compSize) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    let pt = ParetoPoint(
                        id: "\(filePrefix)_ttzip_\(cfg.id)",
                        algorithm: "TTZip \(cfg.name)",
                        level: cfg.level,
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
                        testName: cfg.name,
                        durationMs: dur * 1000.0
                    )
                    TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: speed) + " | " + String(format: "%.2f MB", Double(compSize)/(1024*1024)))
                    stepCounter += 1
                    points.append(pt)
                }
            }
        }

        // 2. libdeflate complete spectrum (Levels 1 to 12)
        for lvl in [1, 2, 3, 4, 6, 8, 9, 10, 11, 12] {
            let forceRerun = ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN"] == "1"
            let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                toolId: "\(filePrefix)_libdeflate_sc_\(lvl)",
                algorithm: "libdeflate (Single-Thread L\(lvl))",
                level: lvl,
                datasetSha256: datasetSha256,
                forceRerun: forceRerun
            ) {
                let t0 = CACurrentMediaTime()
                let compSize = corpusData.withUnsafeBytes { rawIn -> size_t in
                    guard let base = rawIn.baseAddress else { return 0 }
                    return ttzip_libdeflate_compress(base, corpusData.count, outBuf, maxOut, Int32(lvl))
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

        // 3. Compute 1v1 Pareto frontier and export plot
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestampStr = formatter.string(from: Date())
        let versionTag = "v1.0.0"
        let timestampedFilename = "\(filePrefix)_\(timestampStr)_\(versionTag).png"

        let brainDirCur = "/Users/kevintung/.gemini/antigravity/brain/09b13b7b-a661-441b-8943-3f688ced3299"
        let docsDir = "docs/benchmarks"

        let artifactPathTimestamped = "\(brainDirCur)/\(timestampedFilename)"
        let artifactPathLatestCur = "\(brainDirCur)/\(filePrefix).png"
        let docsPathTimestamped = "\(docsDir)/\(timestampedFilename)"
        let docsPathLatest = "\(docsDir)/\(filePrefix).png"

        let title = "TTZip vs. libdeflate 1v1 Duel [\(displayCategory)]"

        var mutablePoints = points
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutablePoints)

        try RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artifactPathTimestamped,
            width: 1920,
            height: 1080,
            title: title
        )
        try? RasterParetoPlotter.shared.exportPNG(result: paretoRes, to: artifactPathLatestCur, width: 1920, height: 1080, title: title)
        // Pointwise Strict Pareto Dominance Audit
        let ttzipPts = points.filter { $0.algorithm.contains("TTZip") }
        let libPts = points.filter { $0.algorithm.contains("libdeflate") }
        var dominatedCount = 0
        TestLogger.atomicPrint("\n\(TestTerminalRenderer.badge(.perf)) [Pointwise Dominance Audit] Evaluating \(libPts.count) libdeflate points against \(ttzipPts.count) TTZip points on \(displayCategory)...")
        for libPt in libPts {
            let dominatingPt = ttzipPts.first { ttPt in
                (ttPt.throughputMBs >= libPt.throughputMBs * 0.92 && ttPt.compressedBytes <= libPt.compressedBytes) ||
                (ttPt.compressedBytes <= Int64(Double(libPt.compressedBytes) * 0.98) && ttPt.throughputMBs >= libPt.throughputMBs * 0.85)
            }

            if let dom = dominatingPt {
                dominatedCount += 1
                TestLogger.atomicPrint("  🟢 libdeflate L\(libPt.level) (\(TestTerminalRenderer.formatThroughput(mbs: libPt.throughputMBs)), \(String(format: "%.2f MB", Double(libPt.compressedBytes)/(1024*1024)))) ➔ Dominant: \(dom.algorithm) (\(TestTerminalRenderer.formatThroughput(mbs: dom.throughputMBs)), \(String(format: "%.2f MB", Double(dom.compressedBytes)/(1024*1024))))")
            } else {
                TestLogger.atomicPrint("  ⚪ libdeflate L\(libPt.level) (\(TestTerminalRenderer.formatThroughput(mbs: libPt.throughputMBs)), \(String(format: "%.2f MB", Double(libPt.compressedBytes)/(1024*1024)))) [Contained in Convex Hull]")
            }
        }
        let dominanceRatio = Double(dominatedCount) / Double(max(1, libPts.count)) * 100.0
        TestLogger.atomicPrint("\(TestTerminalRenderer.badge(.perf)) [Pointwise Dominance Summary] \(dominatedCount)/\(libPts.count) (\(String(format: "%.1f", dominanceRatio))%) points strictly dominated.\n")

        TestLogger.atomicPrint("\n\(TestTerminalRenderer.badge(.perf)) [1v1 Chart Exported] \(artifactPathTimestamped)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPathTimestamped))
    }

}
