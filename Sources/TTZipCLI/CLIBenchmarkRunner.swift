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
        
        do {
            print("\n========================================================================================================================")
            print("📊 Full-Matrix Multidimensional Peak Performance Benchmark (Apple Silicon M-Series Native)")
            print("========================================================================================================================")
            let hDim = "Dimension"
            let hFmt = "Format"
            let hLvl = "Level"
            let hEnc = "Enc"
            let hComp = "Compress MB/s"
            let hDecomp = "Extract MB/s"
            let hTime = "Time (C/D)"
            let hRatio = "Ratio"
            let hSha = "Integrity"
            
            print("\(hDim.padding(toLength: 26, withPad: " ", startingAt: 0)) | \(hFmt.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(hLvl.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(hEnc.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(hComp.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(hDecomp.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(hTime.padding(toLength: 18, withPad: " ", startingAt: 0)) | \(hRatio.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(hSha)")
            print("------------------------------------------------------------------------------------------------------------------------")
            fflush(stdout)

            let _ = try await ExhaustiveBenchmarkRunner.runExhaustiveMatrix(
                selectedFormats: selectedFormats,
                selectedLevels: selectedLevels
            ) { msg in
                if msg.hasPrefix("ROW:") {
                    let rowStr = String(msg.dropFirst(4))
                    print(rowStr)
                    fflush(stdout)
                } else {
                    print(msg)
                    fflush(stdout)
                }
            }
            print("========================================================================================================================\n")
        } catch {
            print("❌ Exhaustive matrix benchmark failed: \(error.localizedDescription)")
        }
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
            print(String(format: "%-15s | %-12s | %-12s | %-10s | %-10s", "Algorithm", "Comp Speed", "Extract Speed", "Ratio", "Speedup"))
            print("=========================================================================================")
            for res in results {
                print(String(format: "%-15s | %-10.1f MB/s | %-10.1f MB/s | %-9.1f %% | %-8.1f x",
                             res.formatName,
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

    public static func padColumn(_ string: String, _ width: Int) -> String {
        var displayWidth = 0
        for char in string {
            if char.isASCII {
                displayWidth += 1
            } else {
                displayWidth += 2
            }
        }
        if displayWidth >= width { return string }
        return string + String(repeating: " ", count: width - displayWidth)
    }

    // MARK: - In-Memory & TurboBench / lzbench Benchmark Suite

    public static func runInMemoryBenchmark(options: CLIOptions) async {
        // 1. 快速场景推荐分支 (--recommend)
        if options.recommend {
            print("🧠 Running Smart Codec Scenario Selector (< 10ms micro-probe)...")
            let scenario = SmartCodecSelector.Scenario.from(string: options.scenario ?? "balanced")
            
            var sampleData: Data
            if let inPath = options.inputPath, let loaded = try? Data(contentsOf: URL(fileURLWithPath: inPath)) {
                sampleData = loaded
            } else {
                sampleData = Data(repeating: 0x41, count: 65536) + Data((0..<65536).map { UInt8($0 & 0xFF) })
            }

            let recommendation = sampleData.withUnsafeBytes { rawPtr -> ScenarioRecommendation in
                guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return SmartCodecSelector.shared.recommend(for: [0], length: 1, scenario: scenario)
                }
                return SmartCodecSelector.shared.recommend(for: base, length: sampleData.count, scenario: scenario)
            }

            print("\n╔═ 🎯 TTZip Smart Codec Scenario Recommendation ═════════════════════════════════════╗")
            let scPadded = recommendation.scenario.padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Scenario:              \(scPadded)║")
            
            let entStr = String(format: "%.3f bits/byte", recommendation.measuredEntropy).padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Shannon Entropy:       \(entStr)║")
            
            let compStr = String(format: "%.1f%% (Trial Ratio: %.3f)", (1.0 - recommendation.trialCompressibilityRatio) * 100.0, recommendation.trialCompressibilityRatio).padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Trial Compressibility: \(compStr)║")
            
            let codecStr = "\(recommendation.recommendedAlgorithm) Level \(recommendation.recommendedLevel)".padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Recommended Codec:     \(codecStr)║")
            
            let speedStr = String(format: "%.1f MB/s (Est. Savings: %.1f%%)", recommendation.projectedThroughputMBs, recommendation.projectedSpaceSavingsPct).padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Projected Speed:       \(speedStr)║")
            
            let timeStr = String(format: "%.3f ms", recommendation.probeDurationMs).padding(toLength: 60, withPad: " ", startingAt: 0)
            print("║ Probe Analysis Time:   \(timeStr)║")
            print("╠════════════════════════════════════════════════════════════════════════════════════╣")
            print("║ 💡 Rationale:                                                                      ║")
            let wrappedRationale = "║  " + recommendation.rationale.padding(toLength: 82, withPad: " ", startingAt: 0) + "║"
            print(wrappedRationale)
            print("╚════════════════════════════════════════════════════════════════════════════════════╝\n")
            return
        }

        print("⚡ Initializing in-memory benchmark engine (TurboBench / lzbench calibrated clock)...")

        let formats: [String]
        if let fmtRaw = options.format, !fmtRaw.isEmpty {
            if fmtRaw.uppercased() == "ALL" {
                formats = ["zip", "7z", "zstd", "lz4"]
            } else {
                formats = fmtRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        } else {
            formats = ["zip", "7z", "zstd", "lz4"]
        }

        let levels: [Int]
        if let lvlRaw = options.level, !lvlRaw.isEmpty {
            levels = lvlRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            levels = [1, 6]
        }

        let bufSize = parseSizeBytes(options.hugeSize ?? "10MB")
        let config = InMemoryBenchmarkConfig(
            selectedFormats: formats,
            selectedLevels: levels.isEmpty ? [1, 6] : levels,
            bufferSizeBytes: bufSize,
            warmupPasses: options.warmupPasses,
            minDurationMs: options.minDurationMs,
            useBinaryUnits: options.binaryUnits,
            turboBenchOutput: options.turboBenchCompat,
            enableThermalGuard: options.thermalGuard,
            customInputPath: options.inputPath
        )

        do {
            let engine = InMemoryBenchmarkEngine.shared
            let report = try await engine.runInMemoryBenchmark(config: config) { msg in
                if msg.hasPrefix("ROW:") {
                    print(String(msg.dropFirst(4)))
                    fflush(stdout)
                } else {
                    print(msg)
                    fflush(stdout)
                }
            }

            print("\n" + engine.generateTurboBenchTable(report: report))

            // 2. 帕累托最优前沿分析与真实图像文件导出 (PNG / SVG)
            let paretoResult = ParetoFrontierCalculator.shared.calculateFrontier(from: report.results)

            if let pngPath = options.pngOutPath {
                try RasterParetoPlotter.shared.exportPNG(result: paretoResult, to: pngPath)
                print("🖼️  High-resolution PNG Pareto chart exported: \(pngPath)")
            }

            if let svgPath = options.svgOutPath {
                try SVGParetoPlotter.shared.exportSVG(result: paretoResult, to: svgPath)
                print("📈 Interactive SVG Pareto chart exported: \(svgPath)")
            }

            if (options.pareto || options.plot) && options.pngOutPath == nil && options.svgOutPath == nil {
                let defaultPng = "docs/benchmarks/pareto_frontier.png"
                let defaultSvg = "docs/benchmarks/pareto_frontier.svg"
                try? RasterParetoPlotter.shared.exportPNG(result: paretoResult, to: defaultPng)
                try? SVGParetoPlotter.shared.exportSVG(result: paretoResult, to: defaultSvg)
                print("🖼️  High-resolution Pareto graphic image generated: \(defaultPng)")
                print("📈 Interactive SVG vector graphic generated: \(defaultSvg)")
            }

            // 3. 物理传输介质端到端耗时投影表
            if options.transferSheet {
                let transferReports = TransferSpeedSheetCalculator.shared.calculateMatrixReports(results: report.results)
                let sheetTable = TransferSpeedSheetCalculator.shared.formatTable(reports: transferReports)
                print("\n" + sheetTable)
            }

            if let jsonPath = options.jsonReportPath {
                try engine.exportJSONReport(report: report, to: jsonPath)
                print("📄 JSON benchmark report exported: \(jsonPath)")
            }
        } catch {
            print("❌ In-memory benchmark failed: \(error.localizedDescription)")
        }
    }
}
