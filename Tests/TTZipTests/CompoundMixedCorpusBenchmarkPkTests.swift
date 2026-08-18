// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class CompoundMixedCorpusBenchmarkPkTests: XCTestCase {
    
    func testCompoundMixedCorpusBenchmarkPk() async throws {
        let orchestrator = CorpusOrchestrator.shared
        
        // 1. 构建 250MB 真实复合多模态工程目录
        let workspaceDir = NSTemporaryDirectory() + "compound_project_250mb_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: workspaceDir) }
        
        print("\n========================================================================")
        print("🏗️  正在装载 5-Tier 复合多模态真实工程工作区 (~250MB, 500+ 文件)...")
        let (totalBytes, totalFiles) = try orchestrator.mountCompoundMixedWorkspace(at: workspaceDir)
        let totalMB = Double(totalBytes) / 1024.0 / 1024.0
        print("✅ 装载完成: 真实大小 \(String(format: "%.2f", totalMB)) MB, 共计 \(totalFiles) 个文件/目录")
        print("========================================================================\n")
        
        struct BenchmarkCandidate {
            let name: String
            let level: Int
            let run: () async throws -> (compMBs: Double, ratio: Double, savings: Double, size: Int64)
        }
        
        var candidates: [BenchmarkCandidate] = []
        
        // 1. TTZip Multi-Level (全部 1 到 12 等级)
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            candidates.append(BenchmarkCandidate(name: "TTZip (L\(lvl))", level: lvl) {
                let outZip = NSTemporaryDirectory() + "ttzip_comp_\(lvl)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: levelEnum, inputPaths: [workspaceDir])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // 2. 竞品矩阵 (7-Zip / pigz / Apple Native): 根据配置选择快照加速或现场实测
        if CompetitorBaselineSnapshotManager.shouldRerunCompetitors {
            let sevenZipLevels = [1, 3, 5, 7, 9]
            for mx in sevenZipLevels {
                candidates.append(BenchmarkCandidate(name: "7-Zip 26.02 (mx=\(mx))", level: mx) {
                    let outZip = NSTemporaryDirectory() + "7z_comp_\(mx)_\(UUID().uuidString).zip"
                    defer { try? FileManager.default.removeItem(atPath: outZip) }
                    let start = mach_absolute_time()
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                    p.arguments = ["a", "-tzip", "-mx=\(mx)", "-mmt=on", "-bso0", "-bsp0", outZip, workspaceDir]
                    try p.run()
                    p.waitUntilExit()
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                    let speed = totalMB / max(0.0001, elapsed)
                    let ratio = Double(totalBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            for lvl in 1...9 {
                candidates.append(BenchmarkCandidate(name: "pigz (-\(lvl))", level: lvl) {
                    let outZip = NSTemporaryDirectory() + "pigz_comp_\(lvl)_\(UUID().uuidString).zip"
                    defer { try? FileManager.default.removeItem(atPath: outZip) }
                    let start = mach_absolute_time()
                    
                    let tarProc = Process()
                    tarProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                    tarProc.arguments = ["-cf", "-", "-C", (workspaceDir as NSString).deletingLastPathComponent, (workspaceDir as NSString).lastPathComponent]
                    
                    let pigzProc = Process()
                    pigzProc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                    pigzProc.arguments = ["-\(lvl)", "-K", "-c"]
                    
                    let pipe = Pipe()
                    tarProc.standardOutput = pipe
                    pigzProc.standardInput = pipe
                    
                    let outPipe = Pipe()
                    pigzProc.standardOutput = outPipe
                    
                    try tarProc.run()
                    try pigzProc.run()
                    
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    tarProc.waitUntilExit()
                    pigzProc.waitUntilExit()
                    
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    try data.write(to: URL(fileURLWithPath: outZip))
                    let outSize = Int64(data.count)
                    let speed = totalMB / max(0.0001, elapsed)
                    let ratio = Double(totalBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            for lvl in 1...9 {
                candidates.append(BenchmarkCandidate(name: "Apple Native (zip -\(lvl))", level: lvl) {
                    let outZip = NSTemporaryDirectory() + "apple_zip_\(lvl)_\(UUID().uuidString).zip"
                    defer { try? FileManager.default.removeItem(atPath: outZip) }
                    let start = mach_absolute_time()
                    let p = Process()
                    p.currentDirectoryURL = URL(fileURLWithPath: workspaceDir)
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    p.arguments = ["-\(lvl)", "-r", "-q", outZip, "."]
                    try p.run()
                    p.waitUntilExit()
                    let elapsed = Double(mach_absolute_time() - start) * 1e-9
                    let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                    let speed = totalMB / max(0.0001, elapsed)
                    let ratio = Double(totalBytes) / Double(max(1, outSize))
                    let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                    return (speed, ratio, savings, outSize)
                })
            }
            candidates.append(BenchmarkCandidate(name: "Apple Native (ditto)", level: 6) {
                let outZip = NSTemporaryDirectory() + "apple_ditto_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = ["-c", "-k", "--sequesterRsrc", workspaceDir, outZip]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        print("========================================================================================================================")
        print("🏛️  250MB 真实复合多模态工程打包实测 (Compound Mixed Workspace)")
        print("========================================================================================================================")
        print(String(format: "%-28@ | %-16@ | %-12@ | %-12@ | %-16@", "Algorithm/Software", "Compression MB/s", "Ratio", "Space Sav%", "Archive Size"))
        print("------------------------------------------------------------------------------------------------------------------------")
        
        var plotPoints: [ParetoPoint] = []
        
        for cand in candidates {
            let (speed, ratio, savings, outSize) = try await cand.run()
            let sizeMB = Double(outSize) / 1024.0 / 1024.0
            print(String(
                format: "%-28@ | %13.1f MB/s | %10.2fx | %10.1f%% | %11.2f MB",
                cand.name as NSString,
                speed,
                ratio,
                savings,
                sizeMB
            ))
            
            plotPoints.append(ParetoPoint(
                algorithm: cand.name,
                level: cand.level,
                throughputMBs: speed,
                spaceSavingsPct: savings,
                compressionRatio: ratio,
                compressedBytes: outSize,
                uncompressedBytes: totalBytes
            ))
        }
        
        // 若使用快照，合并竞品实测黄金数据
        if !CompetitorBaselineSnapshotManager.shouldRerunCompetitors {
            for comp in CompetitorBaselineSnapshotManager.compoundMixedWorkspaceCompetitors {
                let sizeMB = Double(comp.archiveSizeBytes) / 1024.0 / 1024.0
                print(String(
                    format: "%-28@ | %13.1f MB/s | %10.2fx | %10.1f%% | %11.2f MB",
                    comp.algorithm as NSString,
                    comp.throughputMBs,
                    comp.compressionRatio,
                    comp.spaceSavingsPct,
                    sizeMB
                ))
                plotPoints.append(ParetoPoint(
                    algorithm: comp.algorithm,
                    level: comp.level,
                    throughputMBs: comp.throughputMBs,
                    spaceSavingsPct: comp.spaceSavingsPct,
                    compressionRatio: comp.compressionRatio,
                    compressedBytes: comp.archiveSizeBytes,
                    uncompressedBytes: totalBytes
                ))
            }
        }
        
        print("========================================================================================================================\n")
        
        // 渲染图表
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_compound_mixed.png"
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
            title: "Compound Real-World Workspace Benchmark (TTZip vs. 7-Zip vs. pigz vs. Apple Native)"
        )
        print("🏆 真实复合工程帕累托图已生成: \(artifactPath)")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
