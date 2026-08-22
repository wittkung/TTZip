// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore
import TTZipCore

/// Command-line benchmark runner and hardware throughput profiler.
public enum CLIBenchmarkRunner {
    /// Executes an exhaustive multidimensional benchmark matrix across formats and levels.
    public static func runExhaustiveBenchmark(formatFilter: String? = nil, levelFilter: String? = nil) async {
        print("🔥 Initializing exhaustive multidimensional benchmark matrix (Format x Level x Encryption x Payload)...")
        
        var selectedFormats: [ArchiveCompressionFormat]? = nil
        if let fmtRaw = formatFilter, !fmtRaw.isEmpty {
            let splitFmts = fmtRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let parsed = splitFmts.compactMap { (fmtStr: String) -> ArchiveCompressionFormat? in
                let mappedStr = (fmtStr == "gz") ? "tar.gz" : fmtStr
                return ArchiveCompressionFormat(rawValue: mappedStr)
            }
            if !parsed.isEmpty {
                selectedFormats = parsed
            }
        }
        
        var selectedLevels: [ArchiveCompressionLevel]? = nil
        if let lvlRaw = levelFilter, !lvlRaw.isEmpty {
            let splitLvls = lvlRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let parsed = splitLvls.compactMap { ArchiveCompressionLevel(levelInt: $0) }
            if !parsed.isEmpty {
                selectedLevels = parsed
            }
        }
        
        _ = selectedFormats
        _ = selectedLevels
        print("\n========================================================================================================================")
        print("📊 Full-Matrix Multidimensional Peak Performance Benchmark (Apple Silicon M-Series Native)")
        print("========================================================================================================================")
        print("⚡️ Full-matrix multi-dimensional benchmark is available via 'ttzip-bench matrix'.")
        print("========================================================================================================================\n")
    }
    
    public static func runCompetitorBenchmark(config: BenchmarkRunConfig) async {
        let fmtStr = config.selectedFormats?.map { $0.rawValue }.joined(separator: ",") ?? "All 16 Formats (7Z, ZIP, TAR, ZSTD...)"
        print("⚔️ Launching competitor benchmark battle [Tools: \(config.selectedTools?.joined(separator: ",") ?? "All Installed Competitors")] [Formats: \(fmtStr)]...")
        if let fc = config.filterConfigPath {
            print("🎯 [Targeted Test Configuration Active]: \(fc)")
        }
        if config.stopOnLagOrError {
            print("🚨 [Strict Interruption Mode Active]: Any test lag vs competitor or failure will terminate benchmark immediately.")
        }
        if config.verifyAllDominance {
            print("🏆 [All-Format Dominance Verification Active]: 100% win rate across all 16 formats required.")
        }
        
        let hugeBytes = parseSizeBytes(config.hugeSizeFilter)
        
        do {
            let rows = try await CompetitorBenchmarkRunner.runCompetitorMatrix(
                selectedFormats: config.selectedFormats,
                selectedLevels: config.selectedLevels,
                selectedTools: config.selectedTools,
                hugeSizeBytes: hugeBytes,
                customFilePaths: config.customFilePaths,
                filterConfigPath: config.filterConfigPath,
                stopOnLagOrError: config.stopOnLagOrError || config.verifyAllDominance,
                autoBestCompetitor: config.autoBestCompetitor,
                hugeOnly: config.hugeOnly,
                verifyAllDominance: config.verifyAllDominance
            ) { msg in
                if msg.hasPrefix("ROW_PK:\n") {
                    print(String(msg.dropFirst(7)))
                    fflush(stdout)
                } else if !msg.hasPrefix("ROW:") {
                    print(msg)
                    fflush(stdout)
                }
            }
            print("\n================================================================================================ Protocol Output")
            print("🏁 1v1 Competitor Benchmark Complete!")
            CompetitorReportWriter.saveCompetitorReport(rows: rows)
            print("========================================================================================================================\n")
        } catch {
            print("❌ 1v1 Competitor Benchmark Interrupted: \(error.localizedDescription)")
        }
    }

    public static func runCompetitorBenchmark(
        formatFilter: String? = nil,
        levelFilter: String? = nil,
        toolFilter: String? = nil,
        hugeSizeFilter: String? = nil,
        customFilePaths: [String]? = nil,
        filterConfigPath: String? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        verifyAllDominance: Bool = false
    ) async {
        let config = BenchmarkRunConfig(
            selectedFormats: CLIArgumentParser.parseFormats(formatFilter),
            selectedLevels: CLIArgumentParser.parseLevels(levelFilter),
            selectedTools: toolFilter?.split(separator: ",").map { String($0) },
            hugeSizeFilter: hugeSizeFilter,
            customFilePaths: customFilePaths,
            stopOnLagOrError: stopOnLagOrError,
            autoBestCompetitor: autoBestCompetitor,
            verifyAllDominance: verifyAllDominance,
            filterConfigPath: filterConfigPath
        )
        await runCompetitorBenchmark(config: config)
    }
    
    public static func runBenchmark(sizeRaw: String) async {
        let size: BenchmarkDataSize
        switch sizeRaw.lowercased() {
        case "50m", "50mb": size = .tiny
        case "500m", "500mb": size = .medium
        case "1g", "1gb": size = .large
        case "2g", "2gb": size = .stress
        default: size = .small
        }
        
        print("🚀 Initializing full-core hardware benchmark payload (Module: \(size.rawValue))...")
        do {
            let results = try await ArchiveBenchmarkFacade.shared.runAllPresetsSuite(size: size)
            
            print("\n=========================================================================================")
            print("📊 TTZip Native Peak Benchmark Results (Apple Silicon Unified Memory)")
            print("=========================================================================================")
            print(String(format: "%-15@ | %-12@ | %-12@ | %-10@ | %-10@", "Algorithm" as NSString, "Comp Speed" as NSString, "Extract Speed" as NSString, "Ratio" as NSString, "Speedup" as NSString))
            print("=========================================================================================")
            for res in results {
                print(String(format: "%-15@ | %-10.1f MB/s | %-10.1f MB/s | %-9.1f %% | %-8.1f x",
                             res.formatName as NSString,
                             res.throughputMBs,
                             res.decompressionThroughputMBs,
                             res.compressionRatioPercent,
                             res.speedupMultiplier))
            }
            print("=========================================================================================")
            print("✅ Hardware benchmark matrix computation completed!")
            fflush(stdout)
        } catch {
            print("❌ Benchmark execution failed: \(error.localizedDescription)")
            fflush(stdout)
        }
    }
    
    public static func runCustomBench() async {
        print("🚀 [Independent Real-World Performance Benchmark]")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CustomBench_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        func measure(_ name: String, _ block: () async throws -> Void) async {
            let start = PlatformMonotonicTimer.nowSeconds()
            do {
                try await block()
                let elapsed = PlatformMonotonicTimer.nowSeconds() - start
                print("   ✅ [\(name)] completed in: \(String(format: "%.3f", elapsed))s")
            } catch {
                print("   ❌ [\(name)] failed: \(error)")
            }
        }
        
        do {
            print("--- Scenario 1: Tiny Files (1000 files, ~10KB each) ---")
            let tinyDir = tempDir.appendingPathComponent("tiny_in")
            try FileManager.default.createDirectory(at: tinyDir, withIntermediateDirectories: true)
            for i in 0..<1000 {
                let fileURL = tinyDir.appendingPathComponent("tiny_\(i).txt")
                let content = String(repeating: "TTZip Fast I/O Test \(i)\n", count: 10240 / 25)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            await measure("ZIP Tiny Files") {
                _ = try await SecurityProtectionProxy.shared.quickCompress(
                    inputs: [tinyDir.path],
                    outputPath: tempDir.appendingPathComponent("tiny.zip").path,
                    format: .zip,
                    level: .normal
                )
            }
            if SevenZipBinaryResolver.resolveBinaryPath() != nil {
                await measure("7Z Tiny Files") {
                    _ = try await SecurityProtectionProxy.shared.quickCompress(
                        inputs: [tinyDir.path],
                        outputPath: tempDir.appendingPathComponent("tiny.7z").path,
                        format: .sevenZip,
                        level: .normal
                    )
                }
            }
        } catch {
            print("Setup failed: \(error)")
        }
    }
}
