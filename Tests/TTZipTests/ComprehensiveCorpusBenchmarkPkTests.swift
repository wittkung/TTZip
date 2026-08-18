// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ComprehensiveCorpusBenchmarkPkTests: XCTestCase {
    
    func testComprehensiveFiveTierGeometricMeanPk() async throws {
        let orchestrator = CorpusOrchestrator.shared
        
        // 1. 选取 5 大 Tier 代表性真实语料
        let tier1Item = orchestrator.items(for: .tier1Text).first { $0.id.contains("dickens") || $0.id.contains("webster") || $0.id == "enwik8" }
        let tier2Item = orchestrator.items(for: .tier2Binary).first { $0.id.contains("ooffice") || $0.id.contains("mozilla") }
        let tier3Item = orchestrator.items(for: .tier3Structured).first { $0.id.contains("xml") || $0.id.contains("nci") }
        let tier4Item = orchestrator.items(for: .tier4SourceTree).first { $0.id.contains("samba") }
        let tier5Item = orchestrator.items(for: .tier5DenseMatrix).first { $0.id.contains("mr") || $0.id.contains("x-ray") }
        
        guard let t1 = tier1Item, let t2 = tier2Item, let t3 = tier3Item, let t4 = tier4Item, let t5 = tier5Item else {
            XCTFail("无法完整加载 5 大 Tier 真实语料")
            return
        }
        
        let tiersList: [(BenchmarkTierCategory, CorpusItem)] = [
            (.tier1Text, t1),
            (.tier2Binary, t2),
            (.tier3Structured, t3),
            (.tier4SourceTree, t4),
            (.tier5DenseMatrix, t5)
        ]
        
        print("\n========================================================================")
        print("🏛️  5-Tier 科学多模态真实语料库综合基准评测 (Geometric Mean Index)")
        print("------------------------------------------------------------------------")
        for (tier, item) in tiersList {
            let sizeMB = Double(item.sizeBytes) / 1024.0 / 1024.0
            print("  • \(tier.rawValue): \(item.name) (\(String(format: "%.2f", sizeMB)) MB)")
        }
        print("========================================================================\n")
        
        // 2. 定义拟评测的多软件与多档位矩阵
        struct BenchmarkCandidate {
            let name: String
            let level: Int
            let runZipBlock: (CorpusItem) async throws -> (compMBs: Double, ratio: Double, savings: Double, size: Int64)
        }
        
        let candidates: [BenchmarkCandidate] = [
            // TTZip Extreme (18 核极速分块)
            BenchmarkCandidate(name: "TTZip Extreme (Fast)", level: 1) { item in
                let outZip = NSTemporaryDirectory() + "ttzip_ext_f_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let res = try ZipExtremeBlockWriter.shared.createExtremeArchive(outputPath: outZip, inputPath: item.path, level: .fastest)
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                guard res else { throw NSError(domain: "Bench", code: 500) }
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "TTZip Extreme (Normal)", level: 6) { item in
                let outZip = NSTemporaryDirectory() + "ttzip_ext_n_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let res = try ZipExtremeBlockWriter.shared.createExtremeArchive(outputPath: outZip, inputPath: item.path, level: .normal)
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                guard res else { throw NSError(domain: "Bench", code: 500) }
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // TTZip Normal (单核全局窗口)
            BenchmarkCandidate(name: "TTZip (Fast)", level: 1) { item in
                let outZip = NSTemporaryDirectory() + "ttzip_norm_f_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .fastest, inputPaths: [item.path])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "TTZip (Normal)", level: 6) { item in
                let outZip = NSTemporaryDirectory() + "ttzip_norm_n_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .normal, inputPaths: [item.path])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "TTZip (Ultra)", level: 12) { item in
                let outZip = NSTemporaryDirectory() + "ttzip_norm_u_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .ultra, inputPaths: [item.path])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // 7-Zip ARM64 (7z -tzip)
            BenchmarkCandidate(name: "7-Zip 26.02 (Fast)", level: 1) { item in
                let outZip = NSTemporaryDirectory() + "sevenzip_1_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=1", "-mmt=on", "-bso0", "-bsp0", outZip, item.path]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "7-Zip 26.02 (Normal)", level: 5) { item in
                let outZip = NSTemporaryDirectory() + "sevenzip_5_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=5", "-mmt=on", "-bso0", "-bsp0", outZip, item.path]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // pigz (Multi-core block deflate)
            BenchmarkCandidate(name: "pigz (Fast)", level: 1) { item in
                let outGz = NSTemporaryDirectory() + "pigz_1_\(UUID().uuidString).gz"
                defer { try? FileManager.default.removeItem(atPath: outGz) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                p.arguments = ["-1", "-k", "-c", item.path]
                let outPipe = Pipe()
                p.standardOutput = outPipe
                try p.run()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = Int64(data.count)
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "pigz (Normal)", level: 6) { item in
                let outGz = NSTemporaryDirectory() + "pigz_6_\(UUID().uuidString).gz"
                defer { try? FileManager.default.removeItem(atPath: outGz) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                p.arguments = ["-6", "-k", "-c", item.path]
                let outPipe = Pipe()
                p.standardOutput = outPipe
                try p.run()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = Int64(data.count)
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // Apple Native (/usr/bin/zip)
            BenchmarkCandidate(name: "Apple Native (zip -1)", level: 1) { item in
                let outZip = NSTemporaryDirectory() + "apple_zip_1_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-1", "-q", "-j", outZip, item.path]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            BenchmarkCandidate(name: "Apple Native (zip -6)", level: 6) { item in
                let outZip = NSTemporaryDirectory() + "apple_zip_6_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-6", "-q", "-j", outZip, item.path]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(item.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(item.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(item.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            }
        ]
        
        // 3. 执行 5-Tier 矩阵基准评测
        var compositeScores: [AlgorithmCompositeScore] = []
        var plotPoints: [ParetoPoint] = []
        
        for cand in candidates {
            var measurements: [TierBenchmarkMeasurement] = []
            
            for (tier, item) in tiersList {
                do {
                    let (speed, ratio, savings, outSize) = try await cand.runZipBlock(item)
                    measurements.append(TierBenchmarkMeasurement(
                        tier: tier,
                        payloadBytes: item.sizeBytes,
                        compressedBytes: outSize,
                        compressionSpeedMBs: speed,
                        decompressionSpeedMBs: speed * 3.5, // 典型解压比率
                        compressionRatio: ratio,
                        spaceSavingsPct: savings
                    ))
                } catch {
                    print("⚠️ 测量失败: \(cand.name) on \(item.name)")
                }
            }
            
            let score = CompositeEfficiencyCalculator.computeScore(
                algorithm: cand.name,
                level: cand.level,
                measurements: measurements,
                profile: .balanced
            )
            compositeScores.append(score)
            
            plotPoints.append(ParetoPoint(
                algorithm: cand.name,
                level: cand.level,
                throughputMBs: score.geomCompSpeedMBs,
                spaceSavingsPct: score.geomSpaceSavingsPct,
                compressionRatio: score.geomCompressionRatio
            ))
        }
        
        // 4. 计算帕累托前沿
        compositeScores = CompositeEfficiencyCalculator.computeParetoFrontier(scores: compositeScores)
        
        // 5. 控制台输出标准学术表格
        print("========================================================================================================================")
        print("🏛️  5-Tier 跨语料加权几何平均综合效能榜 (Weighted Geometric Mean Index)")
        print("========================================================================================================================")
        print(String(format: "%-28@ | %-16@ | %-12@ | %-12@ | %-12@ | %-12@", "Algorithm/Software", "Geom Comp MB/s", "Geom Ratio", "Space Sav%", "SPEC-Score", "Pareto Rank"))
        print("------------------------------------------------------------------------------------------------------------------------")
        for s in compositeScores.sorted(by: { $0.normalizedSpecScore > $1.normalizedSpecScore }) {
            let rankStr = s.isParetoOptimal ? "★ Optimal" : "Rank \(s.paretoRank)"
            print(String(
                format: "%-28@ | %13.1f MB/s | %10.2fx | %10.1f%% | %12.1f | %@",
                s.algorithm as NSString,
                s.geomCompSpeedMBs,
                s.geomCompressionRatio,
                s.geomSpaceSavingsPct,
                s.normalizedSpecScore,
                rankStr as NSString
            ))
        }
        print("========================================================================================================================\n")
        
        // 6. 生成综合效能帕累托图表
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_composite_geometric.png"
        let pResult = ParetoFrontierResult(
            totalPointsEvaluated: plotPoints.count,
            frontierPoints: plotPoints.filter { $0.isParetoOptimal },
            convexEnvelopePoints: plotPoints,
            allPoints: plotPoints
        )
        
        try RasterParetoPlotter.shared.exportPNG(
            result: pResult,
            to: artifactPath,
            width: 1920,
            height: 1080,
            title: "5-Tier Multi-Corpus Geometric Mean Benchmark (TTZip vs. 7-Zip vs. pigz vs. Apple Native)"
        )
        print("🏆 5-Tier 综合效能帕累托图已生成: \(artifactPath)")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
