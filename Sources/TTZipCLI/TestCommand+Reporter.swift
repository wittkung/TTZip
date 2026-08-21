// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension TestCommand {
    
    /// Renders the diagnostic runner startup banner.
    static func renderHeaderBanner(options: CLIOptions, sessionID: String) {
        let verbosity = options.verbosity
        if verbosity >= 0 && !options.jsonOutput {
            print("\n" + String(repeating: "=", count: 90))
            print("   🧪 \u{001B}[1;36m[TTZip Native Test Harness]\u{001B}[0m Running Test Driver (Session: \(sessionID))")
            if let std = options.standardFormat {
                print("   📜 Standards Mode: \"\(std)\"")
            }
            if let diff = options.differentialOracle {
                print("   ⚖️ Differential Oracle Mode: \"\(diff)\"")
            }
            if options.fuzz {
                print("   💥 Malformed Stream Mutation Fuzzing Mode")
            }
            if let tier = options.tier {
                print("   🏷️ Tier Filter: \"\(tier)\"")
            }
            if let filter = options.filterPattern {
                print("   🔍 Filter: \"\(filter)\" | Verbosity: \(verbosity) | KeepTemp: \(options.keepTempFiles)")
            }
            print(String(repeating: "=", count: 90) + "\n")
        }
    }
    
    /// Emits structured reports (JSON, JUnit XML, Markdown, Telemetry) and summary dashboard to stdout.
    static func emitReportsAndSummary(
        options: CLIOptions,
        sessionID: String,
        startTimestamp: Date,
        totalDuration: Double,
        testCaseRecords: [TestCaseRecord],
        suiteResults: [[String: Any]],
        totalPassed: Int,
        totalFailed: Int,
        totalCases: Int,
        passRate: Double
    ) {
        let verbosity = options.verbosity
        let sessionReport = TestSessionReport(
            timestamp: startTimestamp.timeIntervalSince1970,
            testCases: testCaseRecords
        )
        
        // 1. Persist test reports to disk if requested
        if let jsonPath = options.jsonReportPath {
            let jsonString = sessionReport.toJSON()
            let url = URL(fileURLWithPath: jsonPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
            if verbosity >= 0 && !options.jsonOutput {
                print("  📄 JSON Report saved to: \(jsonPath)")
            }
        }
        
        if let junitPath = options.junitReportPath {
            let xmlString = JUnitReportBuilder.buildXML(from: sessionReport)
            let url = URL(fileURLWithPath: junitPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? xmlString.write(to: url, atomically: true, encoding: .utf8)
            if verbosity >= 0 && !options.jsonOutput {
                print("  📑 JUnit XML Report saved to: \(junitPath)")
            }
        }
        
        if let mdPath = options.markdownReportPath {
            TestReportGenerator.generateMarkdown(
                sessionID: sessionID,
                startTime: ISO8601DateFormatter().string(from: startTimestamp),
                durationMs: totalDuration,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                arch: "arm64",
                totalSuites: suiteResults.count,
                totalCases: totalCases,
                passedCases: totalPassed,
                failedCases: totalFailed,
                skippedCases: 0,
                passRate: passRate,
                suites: suiteResults,
                outputPath: mdPath
            )
            if verbosity >= 0 && !options.jsonOutput {
                print("  📊 Markdown Report saved to: \(mdPath)")
            }
        }
        
        // 2. Emit completion telemetry event if JSON mode is active
        if options.jsonOutput {
            TestTelemetryStream.emitNDJSON(TestTelemetryEvent.runFinished(
                sessionID: sessionID,
                durationMs: totalDuration,
                metrics: TestTelemetryEvent.TelemetryMetrics(
                    totalTests: totalCases,
                    passedTests: totalPassed,
                    failedTests: totalFailed,
                    skippedTests: 0,
                    passRate: passRate
                )
            ))
        }
        
        // 3. Output summary dashboard
        if verbosity >= 0 && !options.jsonOutput {
            print("\n" + String(repeating: "=", count: 90))
            if totalFailed == 0 {
                print("   \u{001B}[1;32m✓ [ALL TESTS PASSED]\u{001B}[0m Total: \(totalCases) | Passed: \(totalPassed) | Time: \(String(format: "%.2f", totalDuration))ms | Pass Rate: 100%")
            } else {
                print("   \u{001B}[1;31m✗ [TEST FAILURES DETECTED]\u{001B}[0m Passed: \(totalPassed) | Failed: \(totalFailed) | Time: \(String(format: "%.2f", totalDuration))ms")
            }
            print(String(repeating: "=", count: 90) + "\n")
        }
    }
}
