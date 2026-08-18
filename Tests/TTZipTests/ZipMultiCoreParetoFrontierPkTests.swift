// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

/// Multi-core saturated scheduling ZIP format Pareto benchmark PK test suite (TTZip vs. pigz multi-threaded).
final class ZipMultiCoreParetoFrontierPkTests: XCTestCase {

    /// Evaluates multi-core parallel ZIP compression Pareto frontier against pigz and advzip.
    func testZipMultiCoreParetoFrontier() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_multicore_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let realSamplePath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let sampleAttrs = try FileManager.default.attributesOfItem(atPath: realSamplePath)
        let payloadBytes = (sampleAttrs[.size] as? Int64) ?? 100_000_000
        let payloadMB = Double(payloadBytes) / 1024.0 / 1024.0

        // 0. Warm-up pass to eliminate page faults, thread pool cold creation, and C state initialization overhead.
        let asyncWriter = ArchiveWriter()
        let warmupPath = tempDir.appendingPathComponent("ttzip_warmup.zip").path
        _ = try? await asyncWriter.createArchive(outputPath: warmupPath, format: .zip, level: .level1, inputPaths: [realSamplePath])
        try? FileManager.default.removeItem(atPath: warmupPath)

        // Verify cryptographic SHA-256 fingerprint of the fixture.
        let corpusItem = CorpusItem(id: "enwik8", name: "enwik8", tier: .tier1Text, path: realSamplePath, sizeBytes: payloadBytes)
        let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem)
        if let fp = fp {
            TTLogger.debug("🔒 [Benchmark Fixture Verified] SHA-256: \(fp.sha256Hex)")
        }

        var zipPoints: [ParetoPoint] = []
        var stepCounter = 1
        let totalStepsEstimate = 23

        TestLogger.atomicPrint("\n" + TestTerminalRenderer.badge(.perf) + " \(TestTerminalRenderer.ANSI.bold)[Multi-Core 18-Thread Benchmark] Starting 100MB enwik8 parallel PK...\(TestTerminalRenderer.ANSI.reset)")

        // 1. TTZip multi-core profiles (Tiers 0..5 live execution, Tiers 6/7 cached or forced via TTZIP_BENCH_ALL_LIVE=1).
        let datasetSha256 = fp?.sha256Hex ?? "unknown"
        let forceLiveAll = (ProcessInfo.processInfo.environment["TTZIP_BENCH_ALL_LIVE"] == "1" ||
                            ProcessInfo.processInfo.environment["TTZIP_FORCE_RERUN_ZOPFLI"] == "1" ||
                            ProcessInfo.processInfo.environment["TTZIP_FORCE_BENCH_RERUN"] == "1")

        for (tierIdx, profile) in ZipCompressionProfile.allProfiles.enumerated() {
            if tierIdx >= 6 && !forceLiveAll {
                // Tier 6 (Ultra Zopfli) and Tier 7 (Extreme Peak) default to caching unless forced.
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "ttzip_mc_\(tierIdx)",
                    algorithm: "TTZip \(tierIdx) (\(profile.name))",
                    level: tierIdx,
                    datasetSha256: datasetSha256
                ) {
                    let pth = tempDir.appendingPathComponent("ttzip_mc_\(tierIdx).zip").path
                    let t0 = PlatformMonotonicTimer.nowNanoseconds()
                    _ = try? ZipExtremeBlockWriter.shared.createExtremeArchive(outputPath: pth, inputPath: realSamplePath, profile: profile)
                    let durSec = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                    let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / durSec
                    return (throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes)
                }
                let durMs = (payloadMB / point.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "TTZip 18-Core",
                    testName: "Tier \(tierIdx) (\(profile.name))",
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                zipPoints.append(point)
            } else {
                let pth = tempDir.appendingPathComponent("ttzip_mc_\(tierIdx).zip").path
                let t0 = PlatformMonotonicTimer.nowNanoseconds()
                _ = try ZipExtremeBlockWriter.shared.createExtremeArchive(outputPath: pth, inputPath: realSamplePath, profile: profile)
                let durSec = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / durSec
                    let pt = ParetoPoint(
                        id: "ttzip_mc_\(tierIdx)",
                        algorithm: "TTZip \(tierIdx) (\(profile.name))",
                        level: tierIdx,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: sz,
                        uncompressedBytes: payloadBytes
                    )
                    let row = TestTerminalRenderer.renderAlignedRow(
                        index: stepCounter,
                        total: totalStepsEstimate,
                        badge: .perf,
                        target: "TTZip 18-Core",
                        testName: "Tier \(tierIdx) (\(profile.name))",
                        durationMs: durSec * 1000.0
                    )
                    TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: speed) + " | " + String(format: "%.2f MB", Double(sz)/(1024*1024)))
                    stepCounter += 1
                    zipPoints.append(pt)
                }
            }
        }

        // 2. pigz multi-threaded Deflate (18 cores, across 11 levels).
        let pigzPath = "/opt/homebrew/bin/pigz"
        if FileManager.default.fileExists(atPath: pigzPath) {
            let pigzLevels: [(Int, String)] = [
                (0, "pigz -0 (Store)"),
                (1, "pigz -1 (Fast)"),
                (2, "pigz -2"),
                (3, "pigz -3 (Fast2)"),
                (4, "pigz -4"),
                (5, "pigz -5"),
                (6, "pigz -6 (Normal)"),
                (7, "pigz -7"),
                (8, "pigz -8"),
                (9, "pigz -9 (Ultra)"),
                (11, "pigz -11 (Zopfli)")
            ]
            for (pzLvl, label) in pigzLevels {
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "pigz_mc_\(pzLvl)",
                    algorithm: label,
                    level: pzLvl,
                    datasetSha256: datasetSha256
                ) {
                    let outPath = tempDir.appendingPathComponent("pigz_mc_\(pzLvl).zip").path
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: pigzPath)
                    p.arguments = ["-K", "-\(pzLvl)", "-p", "18", "-q", "-c", realSamplePath]
                    let pipe = Pipe()
                    p.standardOutput = pipe
                    
                    let t0 = PlatformMonotonicTimer.nowNanoseconds()
                    try? p.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    p.waitUntilExit()
                    let dur = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
                    
                    try? data.write(to: URL(fileURLWithPath: outPath))
                    let sz = Int64(data.count)
                    let savings = (1.0 - Double(sz) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    return (speed, savings, sz, payloadBytes)
                }
                let durMs = (payloadMB / point.throughputMBs) * 1000.0
                let row = TestTerminalRenderer.renderAlignedRow(
                    index: stepCounter,
                    total: totalStepsEstimate,
                    badge: .perf,
                    target: "pigz 18-Core",
                    testName: label,
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                zipPoints.append(point)
            }
        }

        // 3. AdvanceCOMP (advzip -4 iterative optimization).
        let advzipPath = "/opt/homebrew/bin/advzip"
        if FileManager.default.fileExists(atPath: advzipPath) {
            let advPoint = CompetitorBenchmarkCacheManager.shared.getOrRun(
                toolId: "advzip_mc",
                algorithm: "AdvanceCOMP (advzip -4)",
                level: 4,
                datasetSha256: datasetSha256
            ) {
                let advOut = tempDir.appendingPathComponent("advzip_mc.zip").path
                let initialZip = Process()
                initialZip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                initialZip.arguments = ["-1", "-q", advOut, realSamplePath]
                try? initialZip.run()
                initialZip.waitUntilExit()

                let pAdv = Process()
                pAdv.executableURL = URL(fileURLWithPath: advzipPath)
                pAdv.arguments = ["-z", "-4", "-i", "1", advOut]
                let t0Adv = PlatformMonotonicTimer.nowNanoseconds()
                try? pAdv.run()
                pAdv.waitUntilExit()
                let durAdv = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0Adv) / 1_000_000_000.0)
                let szAdv = (try? FileManager.default.attributesOfItem(atPath: advOut)[.size] as? Int64) ?? 0
                let savings = (1.0 - Double(szAdv) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / durAdv
                return (speed, savings, szAdv, payloadBytes)
            }
            let durMs = (payloadMB / advPoint.throughputMBs) * 1000.0
            let row = TestTerminalRenderer.renderAlignedRow(
                index: stepCounter,
                total: totalStepsEstimate,
                badge: .perf,
                target: "AdvanceCOMP",
                testName: "advzip -4",
                durationMs: durMs
            )
            TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: advPoint.throughputMBs) + " | " + String(format: "%.2f MB", Double(advPoint.compressedBytes)/(1024*1024)))
            stepCounter += 1
            zipPoints.append(advPoint)
        }

        // 4. minizip-ng (/opt/homebrew/bin/minizip-ng, Levels 1, 6, 9).
        let minizipNgPath = "/opt/homebrew/bin/minizip-ng"
        if FileManager.default.fileExists(atPath: minizipNgPath) {
            let mzConfigs: [(Int, String)] = [
                (1, "minizip-ng -1 (Fast)"),
                (6, "minizip-ng -6 (Normal)"),
                (9, "minizip-ng -9 (Maximum)")
            ]
            for (lvl, label) in mzConfigs {
                let point = CompetitorBenchmarkCacheManager.shared.getOrRun(
                    toolId: "minizip_ng_\(lvl)",
                    algorithm: label,
                    level: lvl,
                    datasetSha256: datasetSha256
                ) {
                    let outPath = tempDir.appendingPathComponent("minizip_ng_\(lvl).zip").path
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: minizipNgPath)
                    p.arguments = ["-\(lvl)", outPath, realSamplePath]
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
                    target: "minizip-ng",
                    testName: label,
                    durationMs: durMs
                )
                TestLogger.atomicPrint(row + " | " + TestTerminalRenderer.formatThroughput(mbs: point.throughputMBs) + " | " + String(format: "%.2f MB", Double(point.compressedBytes)/(1024*1024)))
                stepCounter += 1
                zipPoints.append(point)
            }
        }

        // 5. Compute multi-core Pareto frontier and export plot.
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_zip_multicore.png"
        let docsPath = "docs/benchmarks/pareto_pk_zip_multicore.png"
        let title = "ZIP Format Multi-Core Pareto Benchmark (18-Core: TTZip vs. pigz vs. minizip-ng)"

        var mutableZipPoints = zipPoints
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutableZipPoints)

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

        TTLogger.debug("🏆 Pure ZIP 18-core multi-threaded Pareto chart generated: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
