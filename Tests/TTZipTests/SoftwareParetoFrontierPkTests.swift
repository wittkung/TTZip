// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

final class SoftwareParetoFrontierPkTests: XCTestCase {
    
    func testSoftwareVsSoftwareParetoFrontier() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_real_software_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 定位真实样本：优先使用 100MB enwik8.xml 标准测试语料；若不存在则使用真实源码树打包
        let enwik8Path = "/Users/kevintung/Library/Caches/com.ttzip.tests/fixtures/enwik8.xml"
        let realSamplePath: String
        if FileManager.default.fileExists(atPath: enwik8Path) {
            realSamplePath = enwik8Path
        } else {
            // 使用 TTZip 源码树作为真实多文件样本
            realSamplePath = "/Users/kevintung/Documents/dev/TTZip/Sources"
        }

        let payloadBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: realSamplePath),
           let fileType = attrs[.type] as? FileAttributeType, fileType == .typeRegular {
            payloadBytes = (attrs[.size] as? Int64) ?? 0
        } else {
            payloadBytes = (try? CompetitorBenchmarkRunner.folderSize(realSamplePath)) ?? 10_000_000
        }
        let payloadMB = Double(payloadBytes) / (1024.0 * 1024.0)

        print("📂 真实测试样本: \(realSamplePath) (大小: \(String(format: "%.2f MB", payloadMB)))")

        var softwarePoints: [ParetoPoint] = []

        // Helper: 运行外部 CLI 软件进程
        func runProcess(_ exe: String, _ args: [String]) -> Double {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            let t0 = CACurrentMediaTime()
            do {
                try p.run()
                p.waitUntilExit()
                let t1 = CACurrentMediaTime()
                return max(1e-6, t1 - t0)
            } catch {
                return 999.0
            }
        }

        let writer = ArchiveEngineFactory.makeWriter()

        // =========================================================================
        // 1. TTZip (原生架构：Swift 6 + libdeflate + LZMA2 + Apple SIMD)
        // =========================================================================
        // TTZip TAR.ZST (Direct In-Memory Pipeline)
        let ttZstPath = tempDir.appendingPathComponent("ttzip_real.tar.zst").path
        let t0_ttzst = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: ttZstPath, format: .tarZst, level: .level1, inputPaths: [realSamplePath])
        let ttZstDur = max(1e-6, CACurrentMediaTime() - t0_ttzst)
        let ttZstSz = (try? FileManager.default.attributesOfItem(atPath: ttZstPath)[.size] as? Int64) ?? 0
        let ttZstSavings = (1.0 - (Double(ttZstSz) / Double(payloadBytes))) * 100.0
        let ttZstSpeed = payloadMB / ttZstDur
        softwarePoints.append(ParetoPoint(id: "ttzip_tar_zst", algorithm: "TTZip (TAR.ZST)", level: 1, throughputMBs: ttZstSpeed, spaceSavingsPct: ttZstSavings, compressedBytes: ttZstSz, uncompressedBytes: payloadBytes))

        // TTZip ZIP L1 (Fast libdeflate)
        let ttZipL1Path = tempDir.appendingPathComponent("ttzip_real_l1.zip").path
        let t0_tt1 = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: ttZipL1Path, format: .zip, level: .level1, inputPaths: [realSamplePath])
        let ttZipL1Dur = max(1e-6, CACurrentMediaTime() - t0_tt1)
        let ttZipL1Sz = (try? FileManager.default.attributesOfItem(atPath: ttZipL1Path)[.size] as? Int64) ?? 0
        let ttZipL1Savings = (1.0 - (Double(ttZipL1Sz) / Double(payloadBytes))) * 100.0
        let ttZipL1Speed = payloadMB / ttZipL1Dur
        softwarePoints.append(ParetoPoint(id: "ttzip_zip_l1", algorithm: "TTZip (ZIP Fast)", level: 1, throughputMBs: ttZipL1Speed, spaceSavingsPct: ttZipL1Savings, compressedBytes: ttZipL1Sz, uncompressedBytes: payloadBytes))

        // TTZip ZIP L6 (Standard libdeflate)
        let ttZipL6Path = tempDir.appendingPathComponent("ttzip_real_l6.zip").path
        let t0_tt6 = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: ttZipL6Path, format: .zip, level: .level6, inputPaths: [realSamplePath])
        let ttZipL6Dur = max(1e-6, CACurrentMediaTime() - t0_tt6)
        let ttZipL6Sz = (try? FileManager.default.attributesOfItem(atPath: ttZipL6Path)[.size] as? Int64) ?? 0
        let ttZipL6Savings = (1.0 - (Double(ttZipL6Sz) / Double(payloadBytes))) * 100.0
        let ttZipL6Speed = payloadMB / ttZipL6Dur
        softwarePoints.append(ParetoPoint(id: "ttzip_zip_l6", algorithm: "TTZip (ZIP Normal)", level: 6, throughputMBs: ttZipL6Speed, spaceSavingsPct: ttZipL6Savings, compressedBytes: ttZipL6Sz, uncompressedBytes: payloadBytes))

        // TTZip 7Z L1 (Parallel LZMA2 Fast)
        let tt7zL1Path = tempDir.appendingPathComponent("ttzip_real_l1.7z").path
        let t0_tt7z1 = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: tt7zL1Path, format: .sevenZip, level: .level1, inputPaths: [realSamplePath])
        let tt7z1Dur = max(1e-6, CACurrentMediaTime() - t0_tt7z1)
        let tt7z1Sz = (try? FileManager.default.attributesOfItem(atPath: tt7zL1Path)[.size] as? Int64) ?? 0
        let tt7z1Savings = (1.0 - (Double(tt7z1Sz) / Double(payloadBytes))) * 100.0
        let tt7z1Speed = payloadMB / tt7z1Dur
        softwarePoints.append(ParetoPoint(id: "ttzip_7z_l1", algorithm: "TTZip (7Z Fast)", level: 1, throughputMBs: tt7z1Speed, spaceSavingsPct: tt7z1Savings, compressedBytes: tt7z1Sz, uncompressedBytes: payloadBytes))

        // =========================================================================
        // 2. 7-Zip 官方 ARM64 发行版 (/opt/homebrew/bin/7zz)
        // =========================================================================
        let sevenZipPath = "/opt/homebrew/bin/7zz"
        if FileManager.default.fileExists(atPath: sevenZipPath) {
            // 7-Zip (ZIP Fast -mx=1)
            let szZip1Path = tempDir.appendingPathComponent("7zip_real_l1.zip").path
            let sz1Dur = runProcess(sevenZipPath, ["a", "-tzip", "-mx=1", "-y", szZip1Path, realSamplePath])
            let sz1Sz = (try? FileManager.default.attributesOfItem(atPath: szZip1Path)[.size] as? Int64) ?? 0
            if sz1Sz > 0 {
                let sz1Savings = (1.0 - (Double(sz1Sz) / Double(payloadBytes))) * 100.0
                let sz1Speed = payloadMB / sz1Dur
                softwarePoints.append(ParetoPoint(id: "7zip_zip_l1", algorithm: "7-Zip 26.02 (ZIP Fast)", level: 1, throughputMBs: sz1Speed, spaceSavingsPct: sz1Savings, compressedBytes: sz1Sz, uncompressedBytes: payloadBytes))
            }

            // 7-Zip (ZIP Normal -mx=6)
            let szZip6Path = tempDir.appendingPathComponent("7zip_real_l6.zip").path
            let sz6Dur = runProcess(sevenZipPath, ["a", "-tzip", "-mx=6", "-y", szZip6Path, realSamplePath])
            let sz6Sz = (try? FileManager.default.attributesOfItem(atPath: szZip6Path)[.size] as? Int64) ?? 0
            if sz6Sz > 0 {
                let sz6Savings = (1.0 - (Double(sz6Sz) / Double(payloadBytes))) * 100.0
                let sz6Speed = payloadMB / sz6Dur
                softwarePoints.append(ParetoPoint(id: "7zip_zip_l6", algorithm: "7-Zip 26.02 (ZIP Normal)", level: 6, throughputMBs: sz6Speed, spaceSavingsPct: sz6Savings, compressedBytes: sz6Sz, uncompressedBytes: payloadBytes))
            }

            // 7-Zip (7Z Fast -mx=1)
            let sz7z1Path = tempDir.appendingPathComponent("7zip_real_l1.7z").path
            let sz7z1Dur = runProcess(sevenZipPath, ["a", "-t7z", "-mx=1", "-y", sz7z1Path, realSamplePath])
            let sz7z1Sz = (try? FileManager.default.attributesOfItem(atPath: sz7z1Path)[.size] as? Int64) ?? 0
            if sz7z1Sz > 0 {
                let sz7z1Savings = (1.0 - (Double(sz7z1Sz) / Double(payloadBytes))) * 100.0
                let sz7z1Speed = payloadMB / sz7z1Dur
                softwarePoints.append(ParetoPoint(id: "7zip_7z_l1", algorithm: "7-Zip 26.02 (7Z Fast)", level: 1, throughputMBs: sz7z1Speed, spaceSavingsPct: sz7z1Savings, compressedBytes: sz7z1Sz, uncompressedBytes: payloadBytes))
            }

            // 7-Zip (7Z Ultra -mx=9)
            let sz7z9Path = tempDir.appendingPathComponent("7zip_real_l9.7z").path
            let sz7z9Dur = runProcess(sevenZipPath, ["a", "-t7z", "-mx=9", "-y", sz7z9Path, realSamplePath])
            let sz7z9Sz = (try? FileManager.default.attributesOfItem(atPath: sz7z9Path)[.size] as? Int64) ?? 0
            if sz7z9Sz > 0 {
                let sz7z9Savings = (1.0 - (Double(sz7z9Sz) / Double(payloadBytes))) * 100.0
                let sz7z9Speed = payloadMB / sz7z9Dur
                softwarePoints.append(ParetoPoint(id: "7zip_7z_l9", algorithm: "7-Zip 26.02 (7Z Ultra)", level: 9, throughputMBs: sz7z9Speed, spaceSavingsPct: sz7z9Savings, compressedBytes: sz7z9Sz, uncompressedBytes: payloadBytes))
            }
        }

        // =========================================================================
        // 3. macOS 系统自带归档实用工具核心 (/usr/bin/ditto)
        // =========================================================================
        let dittoPath = "/usr/bin/ditto"
        if FileManager.default.fileExists(atPath: dittoPath) {
            let dittoZipPath = tempDir.appendingPathComponent("apple_real_ditto.zip").path
            let dittoDur = runProcess(dittoPath, ["-c", "-k", "--sequesterRsrc", realSamplePath, dittoZipPath])
            let dittoSz = (try? FileManager.default.attributesOfItem(atPath: dittoZipPath)[.size] as? Int64) ?? 0
            if dittoSz > 0 {
                let dittoSavings = (1.0 - (Double(dittoSz) / Double(payloadBytes))) * 100.0
                let dittoSpeed = payloadMB / dittoDur
                softwarePoints.append(ParetoPoint(id: "apple_ditto_zip", algorithm: "Apple Native (ditto)", level: 1, throughputMBs: dittoSpeed, spaceSavingsPct: dittoSavings, compressedBytes: dittoSz, uncompressedBytes: payloadBytes))
            }
        }

        // TTZip LZ4 (Tier 4: In-Memory / High-IOPS)
        let ttLz4Path = tempDir.appendingPathComponent("ttzip_real.lz4").path
        let t0_ttlz4 = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: ttLz4Path, format: .lz4, level: .level1, inputPaths: [realSamplePath])
        let ttLz4Dur = max(1e-6, CACurrentMediaTime() - t0_ttlz4)
        let ttLz4Sz = (try? FileManager.default.attributesOfItem(atPath: ttLz4Path)[.size] as? Int64) ?? 0
        let ttLz4Savings = (1.0 - (Double(ttLz4Sz) / Double(payloadBytes))) * 100.0
        let ttLz4Speed = payloadMB / ttLz4Dur
        softwarePoints.append(ParetoPoint(id: "ttzip_lz4_l1", algorithm: "TTZip (LZ4 Fast)", level: 1, throughputMBs: ttLz4Speed, spaceSavingsPct: ttLz4Savings, compressedBytes: ttLz4Sz, uncompressedBytes: payloadBytes))

        // 4. 计算软件级帕累托前沿
        var points = softwarePoints
        let paretoResult = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &points)

        // 5. 计算 4-Tier 格式矩阵综合效能评分 (Base-1000 GMean Index)
        let compositeReports = FormatMatrixScorer.computeCompositeScore(points: softwarePoints)

        // 6. 导出真实高清 PNG 图片 (保存到本地工件目录供用户直接查看，不上传 Git)
        let artifactPngPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/software_pareto_pk.png"
        let localPngPath = "docs/benchmarks/software_pareto_pk.png"
        let localSvgPath = "docs/benchmarks/software_pareto_pk.svg"

        let chartTitle = "TTZip vs. 7-Zip vs. Apple Native (4-Tier 格式矩阵软件 PK)"

        try RasterParetoPlotter.shared.exportPNG(
            result: paretoResult,
            to: artifactPngPath,
            title: chartTitle
        )
        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoResult,
            to: localPngPath,
            title: chartTitle
        )
        try? SVGParetoPlotter.shared.exportSVG(
            result: paretoResult,
            to: localSvgPath,
            title: chartTitle
        )

        print("\n========================================================================")
        print("🏆 真实语料 100MB enwik8 软件级 PK 4-Tier 帕累托图表已生成:")
        print("   图片路径: \(artifactPngPath)")
        print("------------------------------------------------------------------------")
        for p in paretoResult.allPoints {
            print(String(format: "• %-26@ | 压缩速度: %7.1f MB/s | 空间节省: %5.1f%% | 状态: %@", p.algorithm, p.throughputMBs, p.spaceSavingsPct, p.isParetoOptimal ? "👑 帕累托前沿最优" : "⚪ 被支配"))
        }
        print("------------------------------------------------------------------------")
        print("📊 4-Tier 综合效能评分 (Base-1000 加权几何平均指数):")
        for rep in compositeReports {
            print(String(format: "• %-16@ | 综合评分: %6.1f pts | GMean 吞吐: %7.1f MB/s | PEI 指数: %.2f", rep.softwareName, rep.compositeScore, rep.geometricMeanThroughputMBs, rep.paretoEfficiencyIndex))
        }
        print("========================================================================\n")
    }
}
