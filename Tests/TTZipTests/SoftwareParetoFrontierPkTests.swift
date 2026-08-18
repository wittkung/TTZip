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
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_real_zip_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 定位真实样本：使用 100MB enwik8.xml 标准测试语料；若不存在则回退至源码树
        let enwik8Path = "/Users/kevintung/Library/Caches/com.ttzip.tests/fixtures/enwik8.xml"
        let realSamplePath: String
        if FileManager.default.fileExists(atPath: enwik8Path) {
            realSamplePath = enwik8Path
        } else {
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

        print("📂 纯 ZIP 格式基准评测真实样本: \(realSamplePath) (大小: \(String(format: "%.2f MB", payloadMB)))")

        var zipPoints: [ParetoPoint] = []

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

        // Helper: 运行外部 CLI 软件进程 (支持标准输出重定向写入文件)
        func runProcessRedirect(_ exe: String, _ args: [String], outPath: String) -> Double {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            FileManager.default.createFile(atPath: outPath, contents: nil)
            guard let fileHandle = FileHandle(forWritingAtPath: outPath) else { return 999.0 }
            p.standardOutput = fileHandle
            let t0 = CACurrentMediaTime()
            do {
                try p.run()
                p.waitUntilExit()
                try? fileHandle.close()
                let t1 = CACurrentMediaTime()
                return max(1e-6, t1 - t0)
            } catch {
                try? fileHandle.close()
                return 999.0
            }
        }

        let writer = ArchiveEngineFactory.makeWriter()

        // =========================================================================
        // 1. TTZip (原生架构：Swift 6 + libdeflate + 多核并发 + Apple NEON SIMD)
        // =========================================================================
        for (lvl, lbl) in [
            (ArchiveCompressionLevel.level1, "TTZip (ZIP Fast)"),
            (ArchiveCompressionLevel.level3, "TTZip (ZIP Fast2)"),
            (ArchiveCompressionLevel.level6, "TTZip (ZIP Normal)"),
            (ArchiveCompressionLevel.level9, "TTZip (ZIP Max)"),
            (ArchiveCompressionLevel.level12, "TTZip (ZIP Ultra)")
        ] {
            let pth = tempDir.appendingPathComponent("ttzip_real_zip_\(lvl.rawValue).zip").path
            let t0 = CACurrentMediaTime()
            try writer.createArchiveSync(outputPath: pth, format: .zip, level: lvl, inputPaths: [realSamplePath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                let speed = payloadMB / dur
                zipPoints.append(ParetoPoint(id: "ttzip_zip_\(lvl.rawValue)", algorithm: lbl, level: lvl.rawValue, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
            }
        }

        // =========================================================================
        // 2. 7-Zip 官方 ARM64 发行版 (/opt/homebrew/bin/7zz, -tzip -mmt=on 全核满开)
        // =========================================================================
        let sevenZipPath = "/opt/homebrew/bin/7zz"
        if FileManager.default.fileExists(atPath: sevenZipPath) {
            for (mx, lbl) in [
                ("1", "7-Zip 26.02 (ZIP Fast)"),
                ("3", "7-Zip 26.02 (ZIP Fast2)"),
                ("5", "7-Zip 26.02 (ZIP Normal)"),
                ("7", "7-Zip 26.02 (ZIP Max)"),
                ("9", "7-Zip 26.02 (ZIP Ultra)")
            ] {
                let pth = tempDir.appendingPathComponent("7zip_real_zip_\(mx).zip").path
                let dur = runProcess(sevenZipPath, ["a", "-tzip", "-mx=\(mx)", "-mmt=on", "-y", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    zipPoints.append(ParetoPoint(id: "7zip_zip_\(mx)", algorithm: lbl, level: Int(mx) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 3. pigz (Parallel Info-ZIP 多核极速, Mark Adler 官方, -p 18)
        // =========================================================================
        let pigzPath = "/opt/homebrew/bin/pigz"
        if FileManager.default.fileExists(atPath: pigzPath) {
            for (lvl, lbl) in [
                ("1", "pigz (ZIP Fast)"),
                ("3", "pigz (ZIP Fast2)"),
                ("6", "pigz (ZIP Normal)"),
                ("9", "pigz (ZIP Ultra)")
            ] {
                let pth = tempDir.appendingPathComponent("pigz_real_zip_\(lvl).zip").path
                let dur = runProcessRedirect(pigzPath, ["-K", "-\(lvl)", "-p", "18", "-k", "-f", "-c", realSamplePath], outPath: pth)
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    zipPoints.append(ParetoPoint(id: "pigz_zip_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 4. macOS 系统自带归档工具链 (/usr/bin/ditto, /usr/bin/zip -1, -3, -6, -9)
        // =========================================================================
        let dittoPath = "/usr/bin/ditto"
        if FileManager.default.fileExists(atPath: dittoPath) {
            let dittoZipPath = tempDir.appendingPathComponent("apple_real_ditto.zip").path
            let dittoDur = runProcess(dittoPath, ["-c", "-k", "--sequesterRsrc", realSamplePath, dittoZipPath])
            let dittoSz = (try? FileManager.default.attributesOfItem(atPath: dittoZipPath)[.size] as? Int64) ?? 0
            if dittoSz > 0 {
                let dittoSavings = (1.0 - (Double(dittoSz) / Double(payloadBytes))) * 100.0
                let dittoSpeed = payloadMB / dittoDur
                zipPoints.append(ParetoPoint(id: "apple_ditto_zip", algorithm: "Apple Native (ditto)", level: 1, throughputMBs: dittoSpeed, spaceSavingsPct: dittoSavings, compressedBytes: dittoSz, uncompressedBytes: payloadBytes))
            }
        }

        let zipPath = "/usr/bin/zip"
        if FileManager.default.fileExists(atPath: zipPath) {
            for (lvl, lbl) in [
                ("1", "Apple Native (zip -1 Fast)"),
                ("3", "Apple Native (zip -3 Medium)"),
                ("6", "Apple Native (zip -6 Normal)"),
                ("9", "Apple Native (zip -9 Ultra)")
            ] {
                let pth = tempDir.appendingPathComponent("apple_real_zip_\(lvl).zip").path
                let dur = runProcess(zipPath, ["-\(lvl)", "-q", "-r", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    zipPoints.append(ParetoPoint(id: "apple_zip_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 5. 生成 100% 纯净的 ZIP 专属帕累托 PK 图表
        // =========================================================================
        let artifactDir = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f"
        let docsBenchDir = "docs/benchmarks"
        let chartTitle = "ZIP Format Pareto Benchmark (TTZip vs. 7-Zip vs. pigz vs. Apple Native)"

        var mutableZipPoints = zipPoints
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutableZipPoints)

        let artPng = "\(artifactDir)/pareto_pk_zip.png"
        let localPng = "\(docsBenchDir)/pareto_pk_zip.png"
        let localSvg = "\(docsBenchDir)/pareto_pk_zip.svg"

        try RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artPng,
            title: chartTitle
        )
        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: localPng,
            title: chartTitle
        )
        try? SVGParetoPlotter.shared.exportSVG(
            result: paretoRes,
            to: localSvg,
            title: chartTitle
        )

        print("\n========================================================================")
        print("🏆 100% 纯 ZIP 格式 100MB enwik8 软件级 PK 专属图表已生成:")
        print("   • ZIP 图表: \(artPng)")
        print("------------------------------------------------------------------------")
        for p in zipPoints {
            print(String(format: "• %-28@ | 压缩速度: %7.1f MB/s | 空间节省: %5.1f%% | 体积: %7lld 字节", p.algorithm, p.throughputMBs, p.spaceSavingsPct, p.compressedBytes))
        }
        print("========================================================================\n")
    }
}
