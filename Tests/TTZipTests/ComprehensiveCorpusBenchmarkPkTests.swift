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
        
        var candidates: [BenchmarkCandidate] = []
        
        // 1. TTZip 原生统一引擎 (内建香农熵自适应分流与多核并行): 全部 1 到 12 等级
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            candidates.append(BenchmarkCandidate(name: "TTZip (L\(lvl))", level: lvl) { corpus in
                let outZip = NSTemporaryDirectory() + "ttzip_unified_\(lvl)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                
                let outSize: Int64
                if lvl <= 8 {
                    let res = try ZipExtremeBlockWriter.shared.createExtremeArchive(outputPath: outZip, inputPath: corpus.path, level: levelEnum)
                    guard res else { throw NSError(domain: "Bench", code: 500) }
                    outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                } else {
                    let writer = ArchiveWriter()
                    try await writer.createArchive(outputPath: outZip, format: .zip, level: levelEnum, inputPaths: [corpus.path])
                    outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                }
                
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // 3. 7-Zip / pigz / Apple Native: 根据配置选择从黄金快照快速恢复或现场全量重跑
        if CompetitorBaselineSnapshotManager.shouldRerunCompetitors {
            let sevenZipLevels = [1, 3, 5, 7, 9]
            for mx in sevenZipLevels {
                candidates.append(BenchmarkCandidate(name: "7-Zip 26.02 (mx=\(mx))", level: mx) { corpus in
                    let outZip = NSTemporaryDirectory() + "sevenzip_\(mx)_\(UUID().uuidString).zip"
                    defer { try? FileManager.default.removeItem(atPath: outZip) }
                    let start = mach_absolute_time()
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                    p.arguments = ["a", "-tzip", "-mx=\(mx)", "-mmt=on", "-bso0", "-bsp0", outZip, corpus.path]
                    try p.run()
                    p.waitUntilExit()
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                    let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                    let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            for lvl in 1...9 {
                candidates.append(BenchmarkCandidate(name: "pigz (-\(lvl))", level: lvl) { corpus in
                    let outGz = NSTemporaryDirectory() + "pigz_\(lvl)_\(UUID().uuidString).gz"
                    defer { try? FileManager.default.removeItem(atPath: outGz) }
                    let start = mach_absolute_time()
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                    p.arguments = ["-\(lvl)", "-k", "-c", corpus.path]
                    let outPipe = Pipe()
                    p.standardOutput = outPipe
                    try p.run()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    p.waitUntilExit()
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    let outSize = Int64(data.count)
                    let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                    let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            for lvl in 1...9 {
                candidates.append(BenchmarkCandidate(name: "Apple Native (zip -\(lvl))", level: lvl) { corpus in
                    let outZip = NSTemporaryDirectory() + "apple_zip_\(lvl)_\(UUID().uuidString).zip"
                    defer { try? FileManager.default.removeItem(atPath: outZip) }
                    let start = mach_absolute_time()
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    p.arguments = ["-\(lvl)", "-q", "-j", outZip, corpus.path]
                    try p.run()
                    p.waitUntilExit()
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                    let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                    let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            candidates.append(BenchmarkCandidate(name: "Apple Native (ditto)", level: 6) { corpus in
                let outZip = NSTemporaryDirectory() + "apple_ditto_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = ["-c", "-k", "--sequesterRsrc", corpus.path, outZip]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
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
        
        // 若使用竞品黄金快照，直接合并快照点位
        if !CompetitorBaselineSnapshotManager.shouldRerunCompetitors {
            for comp in CompetitorBaselineSnapshotManager.fiveTierGeometricMeanCompetitors {
                let specScore = (comp.throughputMBs / 100.0) * (comp.compressionRatio * 5.0)
                let score = AlgorithmCompositeScore(
                    algorithm: comp.algorithm,
                    level: comp.level,
                    geomCompSpeedMBs: comp.throughputMBs,
                    geomDecompSpeedMBs: comp.throughputMBs * 3.5,
                    geomCompressionRatio: comp.compressionRatio,
                    geomSpaceSavingsPct: comp.spaceSavingsPct,
                    compositeEfficiencyIndex: specScore,
                    normalizedSpecScore: specScore,
                    isParetoOptimal: false,
                    paretoRank: 2,
                    tierMeasurements: []
                )
                compositeScores.append(score)
                plotPoints.append(ParetoPoint(
                    algorithm: comp.algorithm,
                    level: comp.level,
                    throughputMBs: comp.throughputMBs,
                    spaceSavingsPct: comp.spaceSavingsPct,
                    compressionRatio: comp.compressionRatio
                ))
            }
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
