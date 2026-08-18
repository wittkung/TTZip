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
        // 1. TTZip (原生架构：Swift 6 + libdeflate + LZMA2 + Apple SIMD)
        // =========================================================================
        // TTZip TAR.ZST L1 & L3
        for lvl in [ArchiveCompressionLevel.level1, ArchiveCompressionLevel.level3] {
            let pth = tempDir.appendingPathComponent("ttzip_real_zst_\(lvl.rawValue).tar.zst").path
            let t0 = CACurrentMediaTime()
            try writer.createArchiveSync(outputPath: pth, format: .tarZst, level: lvl, inputPaths: [realSamplePath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                let speed = payloadMB / dur
                let name = lvl == .level1 ? "TTZip (TAR.ZST L1)" : "TTZip (TAR.ZST L3)"
                softwarePoints.append(ParetoPoint(id: "ttzip_tar_zst_\(lvl.rawValue)", algorithm: name, level: lvl.rawValue, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
            }
        }

        // TTZip ZIP (L1, L3, L6, L9, L12)
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
                softwarePoints.append(ParetoPoint(id: "ttzip_zip_\(lvl.rawValue)", algorithm: lbl, level: lvl.rawValue, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
            }
        }

        // TTZip 7Z L1 & L5
        for (lvl, lbl) in [(ArchiveCompressionLevel.level1, "TTZip (7Z Fast)"), (ArchiveCompressionLevel.level5, "TTZip (7Z Normal)")] {
            let pth = tempDir.appendingPathComponent("ttzip_real_7z_\(lvl.rawValue).7z").path
            let t0 = CACurrentMediaTime()
            try writer.createArchiveSync(outputPath: pth, format: .sevenZip, level: lvl, inputPaths: [realSamplePath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                let speed = payloadMB / dur
                softwarePoints.append(ParetoPoint(id: "ttzip_7z_\(lvl.rawValue)", algorithm: lbl, level: lvl.rawValue, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
            }
        }

        // TTZip LZ4 L1
        let ttLz4Path = tempDir.appendingPathComponent("ttzip_real.lz4").path
        let t0_ttlz4 = CACurrentMediaTime()
        try writer.createArchiveSync(outputPath: ttLz4Path, format: .lz4, level: .level1, inputPaths: [realSamplePath])
        let ttLz4Dur = max(1e-6, CACurrentMediaTime() - t0_ttlz4)
        let ttLz4Sz = (try? FileManager.default.attributesOfItem(atPath: ttLz4Path)[.size] as? Int64) ?? 0
        let ttLz4Savings = (1.0 - (Double(ttLz4Sz) / Double(payloadBytes))) * 100.0
        let ttLz4Speed = payloadMB / ttLz4Dur
        softwarePoints.append(ParetoPoint(id: "ttzip_lz4_l1", algorithm: "TTZip (LZ4 Fast)", level: 1, throughputMBs: ttLz4Speed, spaceSavingsPct: ttLz4Savings, compressedBytes: ttLz4Sz, uncompressedBytes: payloadBytes))

        // =========================================================================
        // 2. 7-Zip 官方 ARM64 发行版 (/opt/homebrew/bin/7zz, -mmt=on 全核满开)
        // =========================================================================
        let sevenZipPath = "/opt/homebrew/bin/7zz"
        if FileManager.default.fileExists(atPath: sevenZipPath) {
            // 7-Zip ZIP (mx=1, 3, 5, 7, 9)
            for (mx, lbl) in [("1", "7-Zip 26.02 (ZIP Fast)"), ("3", "7-Zip 26.02 (ZIP Fast2)"), ("5", "7-Zip 26.02 (ZIP Normal)"), ("7", "7-Zip 26.02 (ZIP Max)"), ("9", "7-Zip 26.02 (ZIP Ultra)")] {
                let pth = tempDir.appendingPathComponent("7zip_real_zip_\(mx).zip").path
                let dur = runProcess(sevenZipPath, ["a", "-tzip", "-mx=\(mx)", "-mmt=on", "-y", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "7zip_zip_\(mx)", algorithm: lbl, level: Int(mx) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }

            // 7-Zip 7Z (mx=1, 5, 9)
            for (mx, lbl) in [("1", "7-Zip 26.02 (7Z Fast)"), ("5", "7-Zip 26.02 (7Z Normal)"), ("9", "7-Zip 26.02 (7Z Ultra)")] {
                let pth = tempDir.appendingPathComponent("7zip_real_7z_\(mx).7z").path
                let dur = runProcess(sevenZipPath, ["a", "-t7z", "-mx=\(mx)", "-mmt=on", "-y", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "7zip_7z_\(mx)", algorithm: lbl, level: Int(mx) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 3. Keka 1.4.x macOS 发行版 (/opt/homebrew/bin/keka 7zz, -mmt=on 全核满开)
        // =========================================================================
        let kekaPath = "/opt/homebrew/bin/keka"
        if FileManager.default.fileExists(atPath: kekaPath) {
            for (mx, lbl) in [("1", "Keka (ZIP Fast)"), ("3", "Keka (ZIP Fast2)"), ("5", "Keka (ZIP Normal)"), ("7", "Keka (ZIP Max)"), ("9", "Keka (ZIP Ultra)")] {
                let pth = tempDir.appendingPathComponent("keka_real_zip_\(mx).zip").path
                let dur = runProcess(kekaPath, ["7zz", "a", "-tzip", "-mx=\(mx)", "-mmt=on", "-y", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "keka_zip_\(mx)", algorithm: lbl, level: Int(mx) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
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
                softwarePoints.append(ParetoPoint(id: "apple_ditto_zip", algorithm: "Apple Native (ditto)", level: 1, throughputMBs: dittoSpeed, spaceSavingsPct: dittoSavings, compressedBytes: dittoSz, uncompressedBytes: payloadBytes))
            }
        }

        let zipPath = "/usr/bin/zip"
        if FileManager.default.fileExists(atPath: zipPath) {
            for (lvl, lbl) in [("1", "Apple Native (zip -1 Fast)"), ("3", "Apple Native (zip -3 Medium)"), ("6", "Apple Native (zip -6 Normal)"), ("9", "Apple Native (zip -9 Ultra)")] {
                let pth = tempDir.appendingPathComponent("apple_real_zip_\(lvl).zip").path
                let dur = runProcess(zipPath, ["-\(lvl)", "-q", "-r", pth, realSamplePath])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "apple_zip_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 5. pigz (Parallel Info-ZIP 多核极速, Mark Adler 官方, -p 18)
        // =========================================================================
        let pigzPath = "/opt/homebrew/bin/pigz"
        if FileManager.default.fileExists(atPath: pigzPath) {
            for (lvl, lbl) in [("1", "pigz (ZIP Fast)"), ("3", "pigz (ZIP Fast2)"), ("6", "pigz (ZIP Normal)"), ("9", "pigz (ZIP Ultra)")] {
                let pth = tempDir.appendingPathComponent("pigz_real_zip_\(lvl).zip").path
                let dur = runProcessRedirect(pigzPath, ["-K", "-\(lvl)", "-p", "18", "-k", "-f", "-c", realSamplePath], outPath: pth)
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "pigz_zip_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // =========================================================================
        // 4. 官方开源 CLI 工具链 (zstd -T0 多核满开, lz4 极速)
        // =========================================================================
        let zstdPath = "/opt/homebrew/bin/zstd"
        if FileManager.default.fileExists(atPath: zstdPath) {
            for (lvl, lbl) in [("1", "zstd CLI L1 (-T0)"), ("3", "zstd CLI L3 (-T0)"), ("19", "zstd CLI L19 (-T0)")] {
                let pth = tempDir.appendingPathComponent("zstd_real_\(lvl).zst").path
                let dur = runProcess(zstdPath, ["-\(lvl)", "-T0", "-f", "-q", realSamplePath, "-o", pth])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "zstd_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        let lz4BinPath = "/opt/homebrew/bin/lz4"
        if FileManager.default.fileExists(atPath: lz4BinPath) {
            for (lvl, lbl) in [("1", "lz4 CLI L1 (Fast)"), ("9", "lz4 CLI L9 (HC)")] {
                let pth = tempDir.appendingPathComponent("lz4_real_\(lvl).lz4").path
                let dur = runProcess(lz4BinPath, ["-\(lvl)", "-f", "-q", realSamplePath, pth])
                let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                    let speed = payloadMB / dur
                    softwarePoints.append(ParetoPoint(id: "lz4_\(lvl)", algorithm: lbl, level: Int(lvl) ?? 1, throughputMBs: speed, spaceSavingsPct: savings, compressedBytes: sz, uncompressedBytes: payloadBytes))
                }
            }
        }

        // 4. 计算 4-Tier 格式矩阵综合效能评分 (Base-1000 GMean Index)
        let compositeReports = FormatMatrixScorer.computeCompositeScore(points: softwarePoints)

        // 5. 按格式独立生成专属帕累托 PK 图表 (One Chart Per Format) 与全景图
        let artifactDir = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f"
        let docsBenchDir = "docs/benchmarks"

        for session in DedicatedFormatSession.allCases {
            var sessionPoints: [ParetoPoint]
            switch session {
            case .zip:
                sessionPoints = softwarePoints.filter {
                    let low = $0.algorithm.lowercased()
                    return (low.contains("zip") || low.contains("ditto")) && !low.contains("7z")
                }
            case .sevenZ:
                sessionPoints = softwarePoints.filter {
                    let low = $0.algorithm.lowercased()
                    return low.contains("7z") || low.contains("lzma")
                }
            case .tarZst:
                sessionPoints = softwarePoints.filter {
                    let low = $0.algorithm.lowercased()
                    return low.contains("zst") || low.contains("zstandard")
                }
            case .lz4:
                sessionPoints = softwarePoints.filter {
                    let low = $0.algorithm.lowercased()
                    return low.contains("lz4")
                }
            case .full:
                sessionPoints = softwarePoints
            }

            guard !sessionPoints.isEmpty else { continue }
            let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &sessionPoints)

            let artPng = "\(artifactDir)/\(session.pngFileName)"
            let localPng = "\(docsBenchDir)/\(session.pngFileName)"
            let localSvg = "\(docsBenchDir)/\(session.svgFileName)"

            try RasterParetoPlotter.shared.exportPNG(
                result: paretoRes,
                to: artPng,
                title: session.chartTitle
            )
            try? RasterParetoPlotter.shared.exportPNG(
                result: paretoRes,
                to: localPng,
                title: session.chartTitle
            )
            try? SVGParetoPlotter.shared.exportSVG(
                result: paretoRes,
                to: localSvg,
                title: session.chartTitle
            )
        }

        print("\n========================================================================")
        print("🏆 真实语料 100MB enwik8 软件级 PK 专属格式图表已全部生成:")
        for s in DedicatedFormatSession.allCases {
            print("   • \(s.rawValue.uppercased()) 图表: \(artifactDir)/\(s.pngFileName)")
        }
        print("------------------------------------------------------------------------")
        for p in softwarePoints {
            print(String(format: "• %-28@ | 压缩速度: %7.1f MB/s | 空间节省: %5.1f%%", p.algorithm, p.throughputMBs, p.spaceSavingsPct))
        }
        print("------------------------------------------------------------------------")
        print("📊 4-Tier 综合效能评分 (Base-1000 加权几何平均指数):")
        for rep in compositeReports {
            print(String(format: "• %-16@ | 综合评分: %6.1f pts | GMean 吞吐: %7.1f MB/s | PEI 指数: %.2f", rep.softwareName, rep.compositeScore, rep.geometricMeanThroughputMBs, rep.paretoEfficiencyIndex))
        }
        print("========================================================================\n")
    }
}
