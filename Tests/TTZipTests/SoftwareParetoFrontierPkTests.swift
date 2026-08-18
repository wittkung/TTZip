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
        // 1. TTZip 统一旗舰引擎 (全部 1 到 12 级，内建自适应分流与 18 核多块并发)
        // =========================================================================
        let asyncWriter = ArchiveWriter()
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            let pth = tempDir.appendingPathComponent("ttzip_unified_zip_\(lvl).zip").path
            let t0 = CACurrentMediaTime()
            try await asyncWriter.createArchive(outputPath: pth, format: .zip, level: levelEnum, inputPaths: [realSamplePath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: pth)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - (Double(sz) / Double(payloadBytes))) * 100.0
                let speed = payloadMB / dur
                zipPoints.append(ParetoPoint(
                    id: "ttzip_zip_\(lvl)",
                    algorithm: "TTZip (L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: sz,
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // ==============================================
        // 2. libdeflate 官方 C 原生引擎 (单核 SIMD 极限基准)
        // ==============================================
        let rawData = try Data(contentsOf: URL(fileURLWithPath: realSamplePath))
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
                zipPoints.append(ParetoPoint(
                    id: "libdeflate_\(lvl)",
                    algorithm: "libdeflate (L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: Int64(compSize),
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // ==============================================
        // 3. pigz 多线程 Deflate (Mark Adler 官方多核极速引擎)
        // ==============================================
        let pigzPath = "/opt/homebrew/bin/pigz"
        if FileManager.default.fileExists(atPath: pigzPath) {
            let pigzLevels: [(Int, String)] = [(1, "pigz -1 (Fast)"), (3, "pigz -3 (Fast2)"), (6, "pigz -6 (Normal)"), (9, "pigz -9 (Ultra)")]
            for (pzLvl, label) in pigzLevels {
                let outPath = tempDir.appendingPathComponent("pigz_\(pzLvl).zip").path
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
                        id: "pigz_\(pzLvl)",
                        algorithm: label,
                        level: pzLvl,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: sz,
                        uncompressedBytes: payloadBytes
                    ))
                }
            }

            // ==============================================
            // 4. Google Zopfli (图论最短路径穷举 Deflate 极限, 18-Core Multi-Threaded)
            // ==============================================
            let outPathZopfli = tempDir.appendingPathComponent("zopfli.zip").path
            let pZopfli = Process()
            pZopfli.executableURL = URL(fileURLWithPath: pigzPath)
            pZopfli.arguments = ["-K", "-11", "-p", "18", "-q", "-c", realSamplePath]
            let pipeZ = Pipe()
            pZopfli.standardOutput = pipeZ
            let t0Z = CACurrentMediaTime()
            try pZopfli.run()
            let dataZ = pipeZ.fileHandleForReading.readDataToEndOfFile()
            pZopfli.waitUntilExit()
            let durZ = max(1e-6, CACurrentMediaTime() - t0Z)
            try? dataZ.write(to: URL(fileURLWithPath: outPathZopfli))
            let szZ = Int64(dataZ.count)
            if szZ > 0 {
                let savings = (1.0 - Double(szZ) / Double(payloadBytes)) * 100.0
                let speed = payloadMB / durZ
                zipPoints.append(ParetoPoint(
                    id: "google_zopfli",
                    algorithm: "Google Zopfli (--i15)",
                    level: 11,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: szZ,
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // ==============================================
        // 5. AdvanceCOMP (advzip -4 极限迭代优化)
        // ==============================================
        let advzipPath = "/opt/homebrew/bin/advzip"
        if FileManager.default.fileExists(atPath: advzipPath) {
            let advOut = tempDir.appendingPathComponent("advzip_sample.zip").path
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
                    id: "advzip_zopfli",
                    algorithm: "AdvanceCOMP (advzip -4)",
                    level: 4,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: szAdv,
                    uncompressedBytes: payloadBytes
                ))
            }
        }

        // =========================================================================
        // 6. 生成 100% 纯净的 ZIP 专属帕累托 PK 图表
        // =========================================================================
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_zip.png"
        let docsPath = "docs/benchmarks/pareto_pk_zip.png"
        let title = "ZIP Format Pareto Frontier (TTZip vs. pigz vs. libdeflate vs. Zopfli vs. advzip)"
        
        var mutableZipPoints = zipPoints
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutableZipPoints)

        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artifactPath,
            title: title
        )
        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: docsPath,
            title: title
        )

        print("\n========================================================================")
        print("🏆 100% 纯 ZIP 格式 100MB enwik8 软件级 PK 专属图表已生成:")
        print("   • ZIP 图表: \(artifactPath)")
        print("------------------------------------------------------------------------")
        for p in zipPoints {
            print(String(format: "• %-28@ | 压缩速度: %7.1f MB/s | 空间节省: %5.1f%% | 体积: %7lld 字节", p.algorithm, p.throughputMBs, p.spaceSavingsPct, p.compressedBytes))
        }
        print("========================================================================\n")
    }
}
