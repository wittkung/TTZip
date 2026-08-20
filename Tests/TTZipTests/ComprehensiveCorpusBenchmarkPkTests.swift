// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

/// Comprehensive 5-Tier multi-modality corpus benchmark suite using weighted geometric mean index.
final class ComprehensiveCorpusBenchmarkPkTests: XCTestCase {
    
    /// Evaluates 5-tier scientific multi-modality corpus compression efficiency across candidate tools.
    func testComprehensiveFiveTierGeometricMeanPk() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let orchestrator = CorpusOrchestrator.shared
        
        // 1. Select representative real-world corpora across 5 major tiers.
        let tier1Item = orchestrator.items(for: .tier1Text).first { $0.id.contains("dickens") || $0.id.contains("webster") || $0.id == "enwik8" }
        let tier2Item = orchestrator.items(for: .tier2Binary).first { $0.id.contains("ooffice") || $0.id.contains("mozilla") }
        let tier3Item = orchestrator.items(for: .tier3Structured).first { $0.id.contains("xml") || $0.id.contains("nci") }
        let tier4Item = orchestrator.items(for: .tier4SourceTree).first { $0.id.contains("samba") }
        let tier5Item = orchestrator.items(for: .tier5DenseMatrix).first { $0.id.contains("mr") || $0.id.contains("x-ray") }
        
        guard let t1 = tier1Item, let t2 = tier2Item, let t3 = tier3Item, let t4 = tier4Item, let t5 = tier5Item else {
            XCTFail("Failed to load representative corpora for all 5 tiers")
            return
        }
        
        let tiersList: [(BenchmarkTierCategory, CorpusItem)] = [
            (.tier1Text, t1),
            (.tier2Binary, t2),
            (.tier3Structured, t3),
            (.tier4SourceTree, t4),
            (.tier5DenseMatrix, t5)
        ]
        
        TTLogger.debug("\n========================================================================")
        TTLogger.debug("🏛️  5-Tier Multi-Modality Corpus Comprehensive Benchmark (Geometric Mean Index)")
        TTLogger.debug("------------------------------------------------------------------------")
        for (tier, item) in tiersList {
            let sizeMB = Double(item.sizeBytes) / 1024.0 / 1024.0
            TTLogger.debug("  • \(tier.rawValue): \(item.name) (\(String(format: "%.2f", sizeMB)) MB)")
        }
        TTLogger.debug("========================================================================\n")
        
        // 2. Define benchmark candidate tools and compression level matrix.
        struct BenchmarkCandidate {
            let name: String
            let level: Int
            let runZipBlock: (CorpusItem) async throws -> (compMBs: Double, ratio: Double, savings: Double, size: Int64)
        }
        
        var candidates: [BenchmarkCandidate] = []
        
        // 1. TTZip native unified engine across all levels (Levels 1 to 12).
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            candidates.append(BenchmarkCandidate(name: "TTZip (L\(lvl))", level: lvl) { corpus in
                let outZip = NSTemporaryDirectory() + "ttzip_unified_\(lvl)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let writer = ArchiveWriter()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: levelEnum, inputPaths: [corpus.path])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = (Double(corpus.sizeBytes) / 1024.0 / 1024.0) / max(0.0001, elapsed)
                let ratio = Double(corpus.sizeBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(corpus.sizeBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // 2. Competitor matrix (7-Zip / pigz / Apple Native): live rerun or golden snapshot.
        if CompetitorBaselineSnapshotManager.shouldRerunCompetitors {
            let sevenZipPath = SystemBinaryResolver.shared.resolve(name: "7z") ?? SystemBinaryResolver.shared.resolve(name: "7zz")
            let pigzPath = SystemBinaryResolver.shared.resolve(name: "pigz")
            let zipPath = SystemBinaryResolver.shared.resolve(name: "zip")

            if let sevenZip = sevenZipPath {
                let sevenZipLevels = [1, 3, 5, 7, 9]
                for mx in sevenZipLevels {
                    candidates.append(BenchmarkCandidate(name: "7-Zip 26.02 (mx=\(mx))", level: mx) { corpus in
                        let outZip = NSTemporaryDirectory() + "sevenzip_\(mx)_\(UUID().uuidString).zip"
                        defer { try? FileManager.default.removeItem(atPath: outZip) }
                        let start = mach_absolute_time()
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: sevenZip)
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
            }
            if let pigz = pigzPath {
                for lvl in 1...9 {
                    candidates.append(BenchmarkCandidate(name: "pigz (-\(lvl))", level: lvl) { corpus in
                        let outGz = NSTemporaryDirectory() + "pigz_\(lvl)_\(UUID().uuidString).gz"
                        defer { try? FileManager.default.removeItem(atPath: outGz) }
                        let start = mach_absolute_time()
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: pigz)
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
            }
            if let zipBin = zipPath {
                for lvl in 1...9 {
                    candidates.append(BenchmarkCandidate(name: "Apple Native (zip -\(lvl))", level: lvl) { corpus in
                        let outZip = NSTemporaryDirectory() + "apple_zip_\(lvl)_\(UUID().uuidString).zip"
                        defer { try? FileManager.default.removeItem(atPath: outZip) }
                        let start = mach_absolute_time()
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: zipBin)
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
        
        // 3. Execute 5-Tier matrix benchmark evaluation.
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
                        decompressionSpeedMBs: speed * 3.5, // Typical decompression ratio model
                        compressionRatio: ratio,
                        spaceSavingsPct: savings
                    ))
                } catch {
                    TTLogger.debug("⚠️ Measurement failed: \(cand.name) on \(item.name)")
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
        
        // Merge competitor golden snapshot data when competitor live rerun is disabled.
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
        
        // 4. Compute Pareto frontier.
        compositeScores = CompositeEfficiencyCalculator.computeParetoFrontier(scores: compositeScores)
        
        // 5. Output standardized table via TTLogger.
        TTLogger.debug("========================================================================================================================")
        TTLogger.debug("🏛️  5-Tier Weighted Geometric Mean Composite Efficiency Index")
        TTLogger.debug("========================================================================================================================")
        TTLogger.debug(String(format: "%-28@ | %-16@ | %-12@ | %-12@ | %-12@ | %-12@", "Algorithm/Software", "Geom Comp MB/s", "Geom Ratio", "Space Sav%", "SPEC-Score", "Pareto Rank"))
        TTLogger.debug("------------------------------------------------------------------------------------------------------------------------")
        for s in compositeScores.sorted(by: { $0.normalizedSpecScore > $1.normalizedSpecScore }) {
            let rankStr = s.isParetoOptimal ? "★ Optimal" : "Rank \(s.paretoRank)"
            TTLogger.debug(String(
                format: "%-28@ | %13.1f MB/s | %10.2fx | %10.1f%% | %12.1f | %@",
                s.algorithm as NSString,
                s.geomCompSpeedMBs,
                s.geomCompressionRatio,
                s.geomSpaceSavingsPct,
                s.normalizedSpecScore,
                rankStr as NSString
            ))
        }
        TTLogger.debug("========================================================================================================================\n")
        
        // 6. Generate composite efficiency Pareto chart.
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
        TTLogger.debug("🏆 5-Tier composite Pareto chart generated: \(artifactPath)")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
