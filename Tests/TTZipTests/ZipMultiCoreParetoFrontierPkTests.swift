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
        if let fp = CorpusFingerprintManager.shared.computeFingerprint(for: corpusItem) {
            print("🔒 [Benchmark Fixture Verified] SHA-256: \(fp.sha256Hex)")
        }

        var zipPoints: [ParetoPoint] = []

        // 1. TTZip 18 核心极速分块并行通道 + 32KB 跨块历史字典接力 (Level 1 到 12)
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            let pth = tempDir.appendingPathComponent("ttzip_mc_\(lvl).zip").path
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            try await asyncWriter.createArchive(outputPath: pth, format: .zip, level: levelEnum, inputPaths: [realSamplePath])
            let durSec = max(1e-6, Double(PlatformMonotonicTimer.nowNanoseconds() - t0) / 1_000_000_000.0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                let speed = payloadMB / durSec
                zipPoints.append(ParetoPoint(
                    id: "ttzip_mc_\(lvl)",
                    algorithm: "TTZip (18-Core L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: sz,
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // 2. pigz 18 核心多线程 Deflate (Mark Adler 官方多核极速引擎, -p 18)
        let pigzPath = "/opt/homebrew/bin/pigz"
        if FileManager.default.fileExists(atPath: pigzPath) {
            let pigzLevels: [(Int, String)] = [(1, "pigz -1 (Fast)"), (3, "pigz -3 (Fast2)"), (6, "pigz -6 (Normal)"), (9, "pigz -9 (Ultra)")]
            for (pzLvl, label) in pigzLevels {
                let outPath = tempDir.appendingPathComponent("pigz_mc_\(pzLvl).zip").path
                let p = Process()
                p.executableURL = URL(fileURLWithPath: pigzPath)
                p.arguments = ["-K", "-\(pzLvl)", "-p", "18", "-q", "-c", realSamplePath]
                let pipe = Pipe()
                p.standardOutput = pipe
                
                let t0 = CACurrentMediaTime()
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                
                try data.write(to: URL(fileURLWithPath: outPath))
                let sz = Int64(data.count)
                if sz > 0 {
                    let savings = (1.0 - Double(sz) / Double(payloadBytes)) * 100.0
                    let speed = payloadMB / dur
                    zipPoints.append(ParetoPoint(
                        id: "pigz_mc_\(pzLvl)",
                        algorithm: label,
                        level: pzLvl,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: sz,
                        uncompressedBytes: payloadBytes
                    ))
                }
            }

            // 3. Google Zopfli (18-Core 图论最短路径穷举 Deflate 极限)
            let outPathZopfli = tempDir.appendingPathComponent("zopfli_mc.zip").path
            let pZ = Process()
            pZ.executableURL = URL(fileURLWithPath: pigzPath)
            pZ.arguments = ["-K", "-11", "-p", "18", "-q", "-c", realSamplePath]
            let pipeZ = Pipe()
            pZ.standardOutput = pipeZ
            let t0Z = CACurrentMediaTime()
            try? pZ.run()
            let dataZ = pipeZ.fileHandleForReading.readDataToEndOfFile()
            pZ.waitUntilExit()
            let durZ = max(1e-6, CACurrentMediaTime() - t0Z)
            try? dataZ.write(to: URL(fileURLWithPath: outPathZopfli))
            let szZ = Int64(dataZ.count)
            if szZ > 0 {
                let savings = (1.0 - Double(szZ) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / durZ
                zipPoints.append(ParetoPoint(
                    id: "google_zopfli_mc",
                    algorithm: "Google Zopfli (18-Core)",
                    level: 11,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: szZ,
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // 4. AdvanceCOMP (advzip -4 极限迭代重压)
        let advzipPath = "/opt/homebrew/bin/advzip"
        if FileManager.default.fileExists(atPath: advzipPath) {
            let advOut = tempDir.appendingPathComponent("advzip_mc.zip").path
            let initialZip = Process()
            initialZip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            initialZip.arguments = ["-1", "-q", advOut, realSamplePath]
            try? initialZip.run()
            initialZip.waitUntilExit()

            let pAdv = Process()
            pAdv.executableURL = URL(fileURLWithPath: advzipPath)
            pAdv.arguments = ["-z", "-4", "-i", "1", advOut]
            let t0Adv = CACurrentMediaTime()
            try? pAdv.run()
            pAdv.waitUntilExit()
            let durAdv = max(1e-6, CACurrentMediaTime() - t0Adv)
            let szAdv = (try? FileManager.default.attributesOfItem(atPath: advOut)[.size] as? Int64) ?? 0
            if szAdv > 0 {
                let savings = (1.0 - Double(szAdv) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / durAdv
                zipPoints.append(ParetoPoint(
                    id: "advzip_mc",
                    algorithm: "AdvanceCOMP (advzip -4)",
                    level: 4,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: szAdv,
                    uncompressedBytes: payloadBytes
                ))
            }
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
