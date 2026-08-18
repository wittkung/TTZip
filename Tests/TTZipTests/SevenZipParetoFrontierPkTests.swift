// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

/// Isomorphic 7Z (LZMA2) format Pareto benchmark PK test suite (TTZip vs. official 7-Zip ARM64).
final class SevenZipParetoFrontierPkTests: XCTestCase {
    
    /// Evaluates same-format 7Z compression Pareto frontier against official 7-Zip CLI.
    func testSevenZipSameFormatParetoFrontier() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_7z_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let corpusPath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let attrs = try FileManager.default.attributesOfItem(atPath: corpusPath)
        let totalBytes = (attrs[.size] as? Int64) ?? 100_000_000
        let totalMB = Double(totalBytes) / 1024.0 / 1024.0
        
        var points: [ParetoPoint] = []
        let writer = ArchiveWriter()
        
        // 1. TTZip 7Z native engine (Levels 1 to 12).
        for lvl in [1, 3, 5, 7, 9, 12] {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            let outPath = tempDir.appendingPathComponent("ttzip_7z_\(lvl).7z").path
            let t0 = CACurrentMediaTime()
            try await writer.createArchive(outputPath: outPath, format: .sevenZip, level: levelEnum, inputPaths: [corpusPath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - Double(sz) / Double(totalBytes)) * 100.0
                let speed = totalMB / dur
                points.append(ParetoPoint(
                    id: "ttzip_7z_\(lvl)",
                    algorithm: "TTZip (7Z L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: sz,
                    uncompressedBytes: totalBytes
                ))
            }
        }
        
        // 2. Official 7-Zip ARM64 engine (/opt/homebrew/bin/7zz, -t7z -mx=1..9 -mmt=on).
        let sevenZipPath = "/opt/homebrew/bin/7zz"
        if FileManager.default.fileExists(atPath: sevenZipPath) {
            for mx in [1, 3, 5, 7, 9] {
                let outPath = tempDir.appendingPathComponent("official_7z_\(mx).7z").path
                let p = Process()
                p.executableURL = URL(fileURLWithPath: sevenZipPath)
                p.arguments = ["a", "-t7z", "-mx=\(mx)", "-mmt=on", "-bso0", "-bsp0", "-y", outPath, corpusPath]
                let t0 = CACurrentMediaTime()
                try p.run()
                p.waitUntilExit()
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - Double(sz) / Double(totalBytes)) * 100.0
                    let speed = totalMB / dur
                    points.append(ParetoPoint(
                        id: "official_7z_\(mx)",
                        algorithm: "7-Zip 26.02 (7Z mx=\(mx))",
                        level: mx,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: sz,
                        uncompressedBytes: totalBytes
                    ))
                }
            }
        }
        
        // 3. Compute isomorphic 7Z Pareto frontier.
        var mutablePoints = points
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutablePoints)
        
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_7z.png"
        let docsPath = "docs/benchmarks/pareto_pk_7z.png"
        let title = "7Z Format Pareto Benchmark (TTZip 7Z vs. 7-Zip 26.02 ARM64)"
        
        try RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: artifactPath,
            width: 1920,
            height: 1080,
            title: title
        )
        try? RasterParetoPlotter.shared.exportPNG(
            result: paretoRes,
            to: docsPath,
            width: 1920,
            height: 1080,
            title: title
        )
        
        TTLogger.debug("🏆 Isomorphic 7Z Pareto chart generated: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
