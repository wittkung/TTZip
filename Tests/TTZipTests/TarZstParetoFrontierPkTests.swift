// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import QuartzCore
@testable import TTZipCore

/// Isomorphic TAR.ZST / Zstandard format Pareto benchmark PK test suite (TTZip vs. Meta zstd CLI).
final class TarZstParetoFrontierPkTests: XCTestCase {
    
    /// Evaluates same-format TAR.ZST compression Pareto frontier against Meta official zstd.
    func testTarZstSameFormatParetoFrontier() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_zst_pk_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let corpusPath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
        let attrs = try FileManager.default.attributesOfItem(atPath: corpusPath)
        let totalBytes = (attrs[.size] as? Int64) ?? 100_000_000
        let totalMB = Double(totalBytes) / 1024.0 / 1024.0
        
        var points: [ParetoPoint] = []
        let writer = ArchiveWriter()
        
        // 1. TTZip TAR.ZST native pipeline (Levels 1 to 12).
        for lvl in 1...12 {
            let levelEnum = ArchiveCompressionLevel(rawValue: lvl) ?? .level1
            let outPath = tempDir.appendingPathComponent("ttzip_zst_\(lvl).tar.zst").path
            let t0 = CACurrentMediaTime()
            try await writer.createArchive(outputPath: outPath, format: .tarZst, level: levelEnum, inputPaths: [corpusPath])
            let dur = max(1e-6, CACurrentMediaTime() - t0)
            let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
            if sz > 0 {
                let savings = (1.0 - Double(sz) / Double(totalBytes)) * 100.0
                let speed = totalMB / dur
                points.append(ParetoPoint(
                    id: "ttzip_zst_\(lvl)",
                    algorithm: "TTZip (TAR.ZST L\(lvl))",
                    level: lvl,
                    throughputMBs: speed,
                    spaceSavingsPct: savings,
                    compressedBytes: sz,
                    uncompressedBytes: totalBytes
                ))
            }
        }
        
        // 2. Meta official Zstandard CLI (zstd -T0 -1, -3, -6, -9, -15, -19).
        if let zstdPath = SystemBinaryResolver.shared.resolve(name: "zstd") {
            for zLvl in [1, 3, 6, 9, 15, 19] {
                let outPath = tempDir.appendingPathComponent("meta_zstd_\(zLvl).zst").path
                let p = Process()
                p.executableURL = URL(fileURLWithPath: zstdPath)
                p.arguments = ["-T0", "-\(zLvl)", "-q", "-f", "-o", outPath, corpusPath]
                let t0 = CACurrentMediaTime()
                try p.run()
                p.waitUntilExit()
                let dur = max(1e-6, CACurrentMediaTime() - t0)
                let sz = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
                if sz > 0 {
                    let savings = (1.0 - Double(sz) / Double(totalBytes)) * 100.0
                    let speed = totalMB / dur
                    points.append(ParetoPoint(
                        id: "meta_zstd_\(zLvl)",
                        algorithm: "Zstandard (zstd -\(zLvl))",
                        level: zLvl,
                        throughputMBs: speed,
                        spaceSavingsPct: savings,
                        compressedBytes: sz,
                        uncompressedBytes: totalBytes
                    ))
                }
            }
        }
        
        // 3. Compute isomorphic TAR.ZST Pareto frontier.
        var mutablePoints = points
        let paretoRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &mutablePoints)
        
        let artifactPath = "/Users/kevintung/.gemini/antigravity/brain/4a4398f6-3d2c-43b1-a2c5-87204e93e91f/pareto_pk_tar_zst.png"
        let docsPath = "docs/benchmarks/pareto_pk_tar_zst.png"
        let title = "TAR.ZST / Zstandard Format Pareto Benchmark (TTZip vs. Meta zstd)"
        
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
        
        TTLogger.debug("🏆 Isomorphic TAR.ZST / Zstandard Pareto chart generated: \(artifactPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactPath))
    }
}
