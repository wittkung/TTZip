// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore
import TTZipCore

extension CLIBenchmarkRunner {
    
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

    public static func renderScenarioRecommendation(_ recommendation: ScenarioRecommendation) {
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
    }

    // MARK: - In-Memory & TurboBench / lzbench Benchmark Suite

    public static func runInMemoryBenchmark(options: CLIOptions) async {
        // 1. 快速场景推荐分支 (--recommend)
        if options.recommend {
            print("🧠 Running Smart Codec Scenario Selector (< 10ms micro-probe)...")
            let scStr = options.scenario ?? "balanced"
            let lower = scStr.lowercased()
            let scenarioName: String
            let scenarioCode: Int32
            if lower.contains("airdrop") || lower.contains("instant") || lower.contains("lan") || lower.contains("fast") {
                scenarioName = "Instant Transfer (AirDrop/10G LAN)"
                scenarioCode = Int32(TTZIP_SCENARIO_INSTANT_TRANSFER.rawValue)
            } else if lower.contains("cold") || lower.contains("max") || lower.contains("backup") || lower.contains("archive") {
                scenarioName = "Cold Storage / Maximum Ratio"
                scenarioCode = Int32(TTZIP_SCENARIO_COLD_STORAGE.rawValue)
            } else {
                scenarioName = "Balanced Daily Archive"
                scenarioCode = Int32(TTZIP_SCENARIO_BALANCED_DAILY.rawValue)
            }
            
            var sampleData: Data
            if let inPath = options.inputPath, let loaded = try? Data(contentsOf: URL(fileURLWithPath: inPath)) {
                sampleData = loaded
            } else {
                sampleData = Data(repeating: 0x41, count: 65536) + Data((0..<65536).map { UInt8($0 & 0xFF) })
            }

            let recommendation = sampleData.withUnsafeBytes { rawPtr -> ScenarioRecommendation in
                guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return ScenarioRecommendation(
                        scenario: scenarioName,
                        measuredEntropy: 0.0,
                        trialCompressibilityRatio: 1.0,
                        recommendedAlgorithm: "ZIP-Deflate",
                        recommendedLevel: 6,
                        rationale: "Default fallback recommendation.",
                        projectedThroughputMBs: 1200.0,
                        projectedSpaceSavingsPct: 0.0,
                        probeDurationMs: 0.0
                    )
                }
                var rawResult = TTZipRecommendationResult()
                let status = ttzip_rust_recommend_codec(base, sampleData.count, scenarioCode, &rawResult)
                if status == TTZIP_STATUS_OK {
                    let algo = withUnsafeBytes(of: &rawResult.recommended_algorithm) { ptr -> String in
                        guard let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "ZIP-Deflate" }
                        return String(cString: base)
                    }
                    let rationale = withUnsafeBytes(of: &rawResult.rationale) { ptr -> String in
                        guard let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
                        return String(cString: base)
                    }
                    return ScenarioRecommendation(
                        scenario: scenarioName,
                        measuredEntropy: rawResult.measured_entropy,
                        trialCompressibilityRatio: rawResult.trial_compressibility_ratio,
                        recommendedAlgorithm: algo,
                        recommendedLevel: Int(rawResult.recommended_level),
                        rationale: rationale,
                        projectedThroughputMBs: rawResult.projected_throughput_mbs,
                        projectedSpaceSavingsPct: rawResult.projected_space_savings_pct,
                        probeDurationMs: rawResult.probe_duration_ms
                    )
                }
                return ScenarioRecommendation(
                    scenario: scenarioName,
                    measuredEntropy: 0.0,
                    trialCompressibilityRatio: 1.0,
                    recommendedAlgorithm: "ZIP-Deflate",
                    recommendedLevel: 6,
                    rationale: "Default fallback recommendation.",
                    projectedThroughputMBs: 1200.0,
                    projectedSpaceSavingsPct: 0.0,
                    probeDurationMs: 0.0
                )
            }

            renderScenarioRecommendation(recommendation)
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

            // 2. 帕累托最优前沿分析 (绘图已收敛至 ttzip-bench)
            let _ = ParetoFrontierCalculator.shared.calculateFrontier(from: report.results)

            if let pngPath = options.pngOutPath {
                print("🖼️  High-resolution PNG Pareto chart generation is available via 'ttzip-bench plot --png-out \(pngPath)'.")
            }

            if let svgPath = options.svgOutPath {
                print("📈 Interactive SVG Pareto chart generation is available via 'ttzip-bench plot --svg-out \(svgPath)'.")
            }

            if (options.pareto || options.plot) && options.pngOutPath == nil && options.svgOutPath == nil {
                print("📈 Interactive Pareto charts are generated via 'ttzip-bench plot'.")
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
