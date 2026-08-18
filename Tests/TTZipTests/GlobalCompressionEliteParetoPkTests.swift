// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

/// 全球顶级压缩引擎全景帕累托大 PK 测试套件 (Global Elite Compression Pareto PK)
///
/// 包含全球最强压缩算法与体系：
/// 1. TTZip (原生 12 级统一智能引擎)
/// 2. Zstandard (Meta, Yann Collet -T0 -1..-19)
/// 3. LZ4 (Yann Collet 极速王者 -1..-12)
/// 4. XZ / LZMA2 (多核高压 -T0 -1..-9)
/// 5. Google Brotli (Web文本压缩比王者 -q 1..-11)
/// 6. 7-Zip ARM64 (Igor Pavlov 26.02 -mx=1..9)
/// 7. pigz (Mark Adler 并发 Deflate -1..-9)
/// 8. Apple Native (macOS Archive Utility ditto & zip)
final class GlobalCompressionEliteParetoPkTests: XCTestCase {
    
    func testGlobalEliteCompressionParetoPk() async throws {
        // 1. 加载标准 100MB Wikipedia (enwik8) 语料库
        let corpusPath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let attrs = try FileManager.default.attributesOfItem(atPath: corpusPath)
        let totalBytes = (attrs[.size] as? Int64) ?? 100_000_000
        let totalMB = Double(totalBytes) / 1024.0 / 1024.0
        
        struct BenchmarkCandidate: Sendable {
            let name: String
            let level: Int
            let run: @Sendable () async throws -> (speedMBs: Double, ratio: Double, savings: Double, outSize: Int64)
        }
        
        var candidates: [BenchmarkCandidate] = []
        
        // --- 1. TTZip 原生统一引擎 (Level 1 到 12) ---
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            candidates.append(BenchmarkCandidate(name: "TTZip (L\(lvl))", level: lvl) {
                let outZip = NSTemporaryDirectory() + "ttzip_elite_\(lvl)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let writer = ArchiveWriter()
                try await writer.createArchive(outputPath: outZip, format: .zip, level: levelEnum, inputPaths: [corpusPath])
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZip)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 2. Zstandard (Meta Yann Collet: -T0 -1, -3, -6, -9, -15, -19) ---
        let zstdLevels = [1, 3, 6, 9, 15, 19]
        for zLvl in zstdLevels {
            candidates.append(BenchmarkCandidate(name: "Zstandard (zstd -\(zLvl))", level: zLvl) {
                let outZst = NSTemporaryDirectory() + "zstd_elite_\(zLvl)_\(UUID().uuidString).zst"
                defer { try? FileManager.default.removeItem(atPath: outZst) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/zstd")
                p.arguments = ["-T0", "-\(zLvl)", "-q", "-f", "-o", outZst, corpusPath]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outZst)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 3. LZ4 (Yann Collet: -1, -3, -6, -9, -12) ---
        let lz4Levels = [1, 3, 6, 9, 12]
        for lLvl in lz4Levels {
            candidates.append(BenchmarkCandidate(name: "LZ4 (lz4 -\(lLvl))", level: lLvl) {
                let outLz4 = NSTemporaryDirectory() + "lz4_elite_\(lLvl)_\(UUID().uuidString).lz4"
                defer { try? FileManager.default.removeItem(atPath: outLz4) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/lz4")
                p.arguments = ["-\(lLvl)", "-q", "-f", corpusPath, outLz4]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outLz4)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 4. Google Brotli (-q 1, -q 4, -q 7, -q 11) ---
        let brotliLevels = [1, 4, 7, 11]
        for bLvl in brotliLevels {
            candidates.append(BenchmarkCandidate(name: "Brotli (brotli -\(bLvl))", level: bLvl) {
                let outBr = NSTemporaryDirectory() + "brotli_elite_\(bLvl)_\(UUID().uuidString).br"
                defer { try? FileManager.default.removeItem(atPath: outBr) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brotli")
                p.arguments = ["-q", "\(bLvl)", "-f", "-o", outBr, corpusPath]
                try p.run()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outBr)[.size] as? Int64) ?? 1
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 5. XZ / LZMA2 (-T0 -1, -3, -6, -9) ---
        let xzLevels = [1, 3, 6, 9]
        for xLvl in xzLevels {
            candidates.append(BenchmarkCandidate(name: "XZ (xz -\(xLvl))", level: xLvl) {
                let outXz = NSTemporaryDirectory() + "xz_elite_\(xLvl)_\(UUID().uuidString).xz"
                defer { try? FileManager.default.removeItem(atPath: outXz) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/xz")
                p.arguments = ["-T0", "-\(xLvl)", "-k", "-f", "-c", corpusPath]
                let pipe = Pipe()
                p.standardOutput = pipe
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                try data.write(to: URL(fileURLWithPath: outXz))
                let outSize = Int64(data.count)
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 6. 7-Zip ARM64 (mx=1, 3, 5, 7, 9) ---
        for mx in [1, 3, 5, 7, 9] {
            candidates.append(BenchmarkCandidate(name: "7-Zip 26.02 (mx=\(mx))", level: mx) {
                let outZip = NSTemporaryDirectory() + "7z_elite_\(mx)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
                p.arguments = ["a", "-tzip", "-mx=\(mx)", "-mmt=on", "-bso0", "-bsp0", outZip, corpusPath]
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
        
        // --- 7. pigz (-1 到 -9) ---
        for lvl in 1...9 {
            candidates.append(BenchmarkCandidate(name: "pigz (-\(lvl))", level: lvl) {
                let outGz = NSTemporaryDirectory() + "pigz_elite_\(lvl)_\(UUID().uuidString).gz"
                defer { try? FileManager.default.removeItem(atPath: outGz) }
                let start = mach_absolute_time()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pigz")
                p.arguments = ["-\(lvl)", "-k", "-c", corpusPath]
                let pipe = Pipe()
                p.standardOutput = pipe
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let elapsed = Double(mach_absolute_time() - start) * 1e-9
                try data.write(to: URL(fileURLWithPath: outGz))
                let outSize = Int64(data.count)
                let speed = totalMB / max(0.0001, elapsed)
                let ratio = Double(totalBytes) / Double(max(1, outSize))
                let savings = (1.0 - Double(outSize) / Double(totalBytes)) * 100.0
                return (speed, ratio, savings, outSize)
            })
        }
        
        // --- 8. Apple Native (zip -1 到 -9, ditto) ---
        for lvl in [1, 6, 9] {
            candidates.append(BenchmarkCandidate(name: "Apple Native (zip -\(lvl))", level: lvl) {
                let outZip = NSTemporaryDirectory() + "apple_elite_\(lvl)_\(UUID().uuidString).zip"
                defer { try? FileManager.default.removeItem(atPath: outZip) }
                let start = mach_absolute_time()
                let p = Process()
                p.currentDirectoryURL = URL(fileURLWithPath: (corpusPath as NSString).deletingLastPathComponent)
                p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                p.arguments = ["-\(lvl)", "-q", outZip, (corpusPath as NSString).lastPathComponent]
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
        print("🌐  全球顶级压缩引擎全景帕累托实测 (Global Elite Compression Pareto PK)")
        print("========================================================================================================================")
        print(String(format: "%-30@ | %-16@ | %-12@ | %-12@ | %-16@", "Algorithm/Software", "Compression MB/s", "Ratio", "Space Sav%", "Archive Size"))
        print("------------------------------------------------------------------------------------------------------------------------")
        
        var plotPoints: [ParetoPoint] = []
        
        for cand in candidates {
            let (speed, ratio, savings, outSize) = try await cand.run()
            let sizeMB = Double(outSize) / 1024.0 / 1024.0
            print(String(
                format: "%-30@ | %13.1f MB/s | %10.2fx | %10.1f%% | %11.2f MB",
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
        
        // 生成帕累托结果
        let pResult = ParetoFrontierResult(
            totalPointsEvaluated: plotPoints.count,
            frontierPoints: plotPoints.filter { $0.isParetoOptimal },
            convexEnvelopePoints: plotPoints,
            allPoints: plotPoints
        )
        
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_global_elite_pk.png"
        try RasterParetoPlotter.shared.exportPNG(
            result: pResult,
            to: artifactPath,
            width: 2560,
            height: 1440,
            title: "Global Elite Compression Pareto PK (TTZip vs. zstd vs. lz4 vs. xz vs. brotli vs. 7-Zip vs. pigz)"
        )
        print("🏆 全球顶级压缩全景帕累托图已生成: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
