// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore
import CTTZipBridge

public struct DiffRow {
    public let engine: String
    public let corpus: String
    public let sizeBytes: Int
    public let level: Int
    public let baseCompSpeed: Double
    public let candCompSpeed: Double
    public let compDeltaPct: Double
    public let baseDecompSpeed: Double
    public let candDecompSpeed: Double
    public let decompDeltaPct: Double
    public let ratioDeltaPct: Double
    public let verdict: String
}

public enum BenchCommandRunner {
    
    // MARK: - String Formatting Utilities
    
    public static func padLeft(_ s: String, _ length: Int) -> String {
        if s.count >= length { return s }
        return String(repeating: " ", count: length - s.count) + s
    }

    public static func padRight(_ s: String, _ length: Int) -> String {
        if s.count >= length { return s }
        return s + String(repeating: " ", count: length - s.count)
    }

    public static func formatDuration(_ durationNs: Double) -> String {
        let micros = durationNs / 1000.0
        if micros >= 1000.0 {
            return String(format: "%.2f ms", micros / 1000.0)
        } else {
            return String(format: "%.1f µs", micros)
        }
    }

    public static func formatThroughput(_ mbPerSec: Double) -> String {
        if mbPerSec >= 10000.0 {
            return String(format: "%.1f GB/s", mbPerSec / 1024.0)
        } else {
            return String(format: "%.1f MB/s", mbPerSec)
        }
    }

    // MARK: - Subcommand Execution
    
    public static func runMatrix(args: [String]) {
        var jsonOutputPath: String? = nil
        var svgOutputPath: String? = nil
        var htmlOutputPath: String? = nil
        var idx = 1
        while idx < args.count {
            if args[idx] == "--json-out", idx + 1 < args.count {
                jsonOutputPath = args[idx + 1]
                idx += 2
            } else if args[idx] == "--svg-out", idx + 1 < args.count {
                svgOutputPath = args[idx + 1]
                idx += 2
            } else if args[idx] == "--html-out", idx + 1 < args.count {
                htmlOutputPath = args[idx + 1]
                idx += 2
            } else {
                idx += 1
            }
        }

        let summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
        printMatrixTable(summary: summary)

        if let jsonPath = jsonOutputPath {
            let report = serializeMatrixReport(summary: summary)
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: jsonPath))
                print("📄 Telemetry JSON report exported to: \(jsonPath)")
            }
        }

        if let svgPath = svgOutputPath {
            let paretoPoints: [ParetoPoint] = summary.results.map { pt in
                let savings = max(0.0, (1.0 - pt.compressionRatio) * 100.0)
                return ParetoPoint(
                    id: "\(pt.engineName)_\(pt.corpusType.rawValue)_\(pt.payloadSizeBytes)_\(pt.compressionLevel)",
                    algorithm: "\(pt.engineName.uppercased()) [\(pt.corpusType.rawValue)]",
                    level: pt.compressionLevel,
                    throughputMBs: pt.compressThroughputMBs,
                    spaceSavingsPct: savings,
                    compressedBytes: Int64(pt.compressedSizeBytes),
                    uncompressedBytes: Int64(pt.payloadSizeBytes)
                )
            }
            let frontier = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: paretoPoints)
            let svg = SVGParetoPlotter.shared.generateSVG(result: frontier)
            try? svg.data(using: .utf8)?.write(to: URL(fileURLWithPath: svgPath))
            print("📈 Interactive SVG chart exported to: \(svgPath)")
        }

        if let htmlPath = htmlOutputPath {
            let html = HTMLParetoDashboardGenerator.shared.generateHTML(summary: summary)
            try? html.data(using: .utf8)?.write(to: URL(fileURLWithPath: htmlPath))
            print("🌐 Self-contained Zen UI HTML Dashboard exported to: \(htmlPath)")
        }
    }

    public static func runGate(args: [String]) {
        print("⚡️ Running TTZip Automated Benchmark Gate...")
        let summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
        printMatrixTable(summary: summary)

        let passedCount = summary.results.filter { $0.integrityVerified }.count
        let allPassed = passedCount == summary.totalPoints

        if allPassed {
            print("\n✅ GATE PASSED: \(passedCount)/\(summary.totalPoints) points OK | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%")
            exit(0)
        } else {
            print("\n❌ GATE FAILED: Passed: \(passedCount)/\(summary.totalPoints) | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%")
            exit(70) // EX_SOFTWARE
        }
    }

    public static func runPlot(args: [String]) {
        var svgOutputPath: String? = nil
        var htmlOutputPath: String? = nil
        var jsonInputPath: String? = nil
        var idx = 1
        while idx < args.count {
            if args[idx] == "--svg-out", idx + 1 < args.count {
                svgOutputPath = args[idx + 1]
                idx += 2
            } else if args[idx] == "--html-out", idx + 1 < args.count {
                htmlOutputPath = args[idx + 1]
                idx += 2
            } else if args[idx] == "--json-in", idx + 1 < args.count {
                jsonInputPath = args[idx + 1]
                idx += 2
            } else {
                idx += 1
            }
        }

        let summary: CodecBenchmarkMatrixSummary
        if let jsonPath = jsonInputPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
           let decoded = try? JSONDecoder().decode(CodecBenchmarkMatrixSummary.self, from: data) {
            summary = decoded
        } else {
            summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
        }
        if let svgPath = svgOutputPath {
            let paretoPoints: [ParetoPoint] = summary.results.map { pt in
                let savings = max(0.0, (1.0 - pt.compressionRatio) * 100.0)
                return ParetoPoint(
                    id: "\(pt.engineName)_\(pt.corpusType.rawValue)_\(pt.payloadSizeBytes)_\(pt.compressionLevel)",
                    algorithm: "\(pt.engineName.uppercased()) [\(pt.corpusType.rawValue)]",
                    level: pt.compressionLevel,
                    throughputMBs: pt.compressThroughputMBs,
                    spaceSavingsPct: savings,
                    compressedBytes: Int64(pt.compressedSizeBytes),
                    uncompressedBytes: Int64(pt.payloadSizeBytes)
                )
            }
            let frontier = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: paretoPoints)
            let svg = SVGParetoPlotter.shared.generateSVG(result: frontier)
            try? svg.data(using: .utf8)?.write(to: URL(fileURLWithPath: svgPath))
            print("📈 Interactive SVG chart exported to: \(svgPath)")
        }

        if let htmlPath = htmlOutputPath {
            let html = HTMLParetoDashboardGenerator.shared.generateHTML(summary: summary)
            try? html.data(using: .utf8)?.write(to: URL(fileURLWithPath: htmlPath))
            print("🌐 Self-contained Zen UI HTML Dashboard exported to: \(htmlPath)")
        }
    }
}
