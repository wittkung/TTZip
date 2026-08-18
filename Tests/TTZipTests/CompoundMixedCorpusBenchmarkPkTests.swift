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
        
        let candidates: [BenchmarkCandidate] = [
            // TTZip (Fast - libdeflate level 1 + 18-Core concurrency)
            BenchmarkCandidate(name: "TTZip (ZIP Fast)", level: 1) {
                let outZip = NSTemporaryDirectory() + "ttzip_comp_f_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .fastest, inputPaths: [workspaceDir])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // TTZip (Normal - libdeflate level 6 + 18-Core concurrency)
            BenchmarkCandidate(name: "TTZip (ZIP Normal)", level: 6) {
                let outZip = NSTemporaryDirectory() + "ttzip_comp_n_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .normal, inputPaths: [workspaceDir])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // TTZip (Ultra - libdeflate level 12 + 18-Core concurrency)
            BenchmarkCandidate(name: "TTZip (ZIP Ultra)", level: 12) {
                let outZip = NSTemporaryDirectory() + "ttzip_comp_u_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let writer = ArchiveWriter()
                let start = mach_absolute_time()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: .ultra, inputPaths: [workspaceDir])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // 7-Zip ARM64 (Fast)
            BenchmarkCandidate(name: "7-Zip 26.02 (ZIP Fast)", level: 1) {
                let outZip = NSTemporaryDirectory() + "7z_comp_1_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=1", "-mmt=on", "-bso0", "-bsp0", outZip, workspaceDir]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // 7-Zip ARM64 (Normal)
            BenchmarkCandidate(name: "7-Zip 26.02 (ZIP Normal)", level: 5) {
                let outZip = NSTemporaryDirectory() + "7z_comp_5_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=5", "-mmt=on", "-bso0", "-bsp0", outZip, workspaceDir]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // 7-Zip ARM64 (Ultra)
            BenchmarkCandidate(name: "7-Zip 26.02 (ZIP Ultra)", level: 9) {
                let outZip = NSTemporaryDirectory() + "7z_comp_9_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=9", "-mmt=on", "-bso0", "-bsp0", outZip, workspaceDir]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // pigz (Fast -1 multi-core)
            BenchmarkCandidate(name: "pigz (ZIP Fast)", level: 1) {
                let outZip = NSTemporaryDirectory() + "pigz_comp_1_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                
                let tarProc = Process()
                tarProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                tarProc.arguments = ["-cf", "-", "-C", (workspaceDir as NSString).deletingLastPathComponent, (workspaceDir as NSString).lastPathComponent]
                
                let pigzProc = Process()
                pigzProc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                pigzProc.arguments = ["-1", "-K", "-c"]
                
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
            },
            // pigz (Normal -6 multi-core)
            BenchmarkCandidate(name: "pigz (ZIP Normal)", level: 6) {
                let outZip = NSTemporaryDirectory() + "pigz_comp_6_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                
                let tarProc = Process()
                tarProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                tarProc.arguments = ["-cf", "-", "-C", (workspaceDir as NSString).deletingLastPathComponent, (workspaceDir as NSString).lastPathComponent]
                
                let pigzProc = Process()
                pigzProc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                pigzProc.arguments = ["-6", "-K", "-c"]
                
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
            },
            // Apple Native (ditto - Archive Utility default)
            BenchmarkCandidate(name: "Apple Native (ditto)", level: 6) {
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
            },
            // Apple Native (zip -1 Fast)
            BenchmarkCandidate(name: "Apple Native (zip -1)", level: 1) {
                let outZip = NSTemporaryDirectory() + "apple_zip_1_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.currentDirectoryURL = URL(fileURLWithPath: workspaceDir)
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-1", "-r", "-q", outZip, "."]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            },
            // Apple Native (zip -6 Normal)
            BenchmarkCandidate(name: "Apple Native (zip -6)", level: 6) {
                let outZip = NSTemporaryDirectory() + "apple_zip_6_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.currentDirectoryURL = URL(fileURLWithPath: workspaceDir)
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-6", "-r", "-q", outZip, "."]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            }
        ]
        
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
