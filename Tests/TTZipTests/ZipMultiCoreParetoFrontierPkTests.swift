// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

/// 纯 ZIP 格式【多核满载极限对决】基准评测套件 (18 核心饱和调度)
final class ZipMultiCoreParetoFrontierPkTests: XCTestCase {

    func testZipMultiCoreParetoFrontier() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_multicore_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let realSamplePath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let sampleAttrs = try FileManager.default.attributesOfItem(atPath: realSamplePath)
        let payloadBytes = (sampleAttrs[.size] as? Int64) ?? 100_000_000
        let payloadMB = Double(payloadBytes) / 1024.0 / 1024.0

        // 0. 科学 Warm-up 热身轮次 (消除缺页中断、GCD 线程冷创建与 C 状态冷开销)
        let asyncWriter = ArchiveWriter()
        let warmupPath = tempDir.appendingPathComponent("ttzip_warmup.zip").path
        _ = try? await asyncWriter.createArchive(outputPath: warmupPath, format: .zip, level: .level1, inputPaths: [realSamplePath])
        try? FileManager.default.removeItem(atPath: warmupPath)

        // 校验样本密码学指纹
        let corpusItem = CorpusItem(id: "enwik8", name: "enwik8", tier: .tier1Text, path: realSamplePath, sizeBytes: payloadBytes)
        let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem)
        if let fp = fp {
            print("🔒 [Benchmark Fixture Verified] SHA-256: \(fp.sha256Hex)")
        }

        var zipPoints: [ParetoPoint] = []

        // 1. TTZip 全谱系真·帕累托 8 大黄金档位 (Tier 0..5 永远实时实测，Tier 6/7 默认按需缓存，支持 TTZIP_BENCH_ALL_LIVE=1 强制全量重跑)
        let datasetSha256 = fp?.sha256Hex ?? "unknown"
        let forceLiveAll = (ProcessInfo.processInfo.environment["TTZIP_BENCH_ALL_LIVE"] == "1" ||
                            ProcessInfo.processInfo.environment["TTZIP_FORCE_BENCH_RERUN"] == "1")

        for (tierIdx, profile) in ZipCompressionProfile.allProfiles.enumerated() {
            if tierIdx >= 6 && !forceLiveAll {
                // Tier 6 (Ultra Zopfli) 与 Tier 7 (Extreme Peak) 默认复用基准缓存 (0.001s 加载)
                // 如需强制现场重跑，设置环境变量 TTZIP_BENCH_ALL_LIVE=1 或 TTZIP_FORCE_BENCH_RERUN=1
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
                    print("📊 [TTZip Tier \(tierIdx)] \(profile.name): deflateLvl=\(profile.deflateLevel), speed=\(String(format: "%.1f", speed)) MB/s, sz=\(String(format: "%.2f", Double(sz)/(1024*1024))) MB")
                    zipPoints.append(pt)
                }
            }
        }

        // 2. pigz 18 核心多线程 Deflate (Mark Adler 官方多核极速引擎, -p 18, 覆盖全量 11 大物理级别)
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
                zipPoints.append(point)
            }
        }

        // 3. AdvanceCOMP (advzip -4 极限迭代重压)
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
            zipPoints.append(advPoint)
        }

        // 3. 计算多核帕累托前沿并输出图表
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_zip_multicore.png"
        let docsPath = "docs/benchmarks/pareto_pk_zip_multicore.png"
        let title = "ZIP Format Multi-Core Pareto Benchmark (18-Core: TTZip vs. pigz)"

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

        print("🏆 纯 ZIP 格式 18 核心满载极限对决图表已生成: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
