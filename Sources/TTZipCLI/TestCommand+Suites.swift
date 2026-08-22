// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension TestCommand {
    
    /// Executes the configured test suites based on the provided CLI options.
    static func runConfiguredSuites(
        options: CLIOptions,
        sessionID: String,
        records: inout [TestCaseRecord],
        suiteResults: inout [[String: Any]]
    ) async {
        // MARK: - Special Mode A: Standards Compliance Validation (--standard <format>)
        if let stdFormatStr = options.standardFormat {
            await runStandardsSuite(formatStr: stdFormatStr, sessionID: sessionID, options: options, records: &records, suiteResults: &suiteResults)
        }
        
        // MARK: - Special Mode B: Differential Oracle Comparison (--differential <oracle>)
        if let diffOracleStr = options.differentialOracle {
            await runDifferentialSuite(oracleStr: diffOracleStr, sessionID: sessionID, options: options, records: &records, suiteResults: &suiteResults)
        }
        
        // MARK: - Special Mode C: Malformed Stream Mutation Fuzzing (--fuzz)
        if options.fuzz {
            await runFuzzSuite(sessionID: sessionID, options: options, records: &records, suiteResults: &suiteResults)
        }
        
        // MARK: - Standard Tier Suites (Default when no special mode is specified)
        if options.standardFormat == nil && options.differentialOracle == nil && !options.fuzz {
            let activeTiers: Set<Int>
            if let tierStr = options.tier {
                let parsed = tierStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: CharacterSet.whitespaces)) }
                activeTiers = Set(parsed.isEmpty ? [0, 1] : parsed)
            } else {
                activeTiers = [0, 1]
            }
            
            // 1. Tier 0: In-memory micro unit tests (SIMD / POSIX CLI argument validation)
            if activeTiers.contains(0) {
                runTier0Suite(options: options, records: &records, suiteResults: &suiteResults)
            }
            
            // 2. Tier 1: 16 format round-trip diagnostic suites
            if activeTiers.contains(1) {
                runTier1Suite(options: options, records: &records, suiteResults: &suiteResults)
            }
        }
    }
    
    // MARK: - Tier 0 Suite Runner
    private static func runTier0Suite(options: CLIOptions, records: inout [TestCaseRecord], suiteResults: inout [[String: Any]]) {
        let t0Start = Date()
        var t0Passed = 0
        var t0Failed = 0
        var t0Cases: [[String: Any]] = []
        
        // POSIX CLI argument parser compliance verification
        let posixStart = Date()
        let parseRes = POSIXCLIArgumentParser.parse(args: ["archive", "out.tar.zst", "src/", "--format=tar.zst", "--level=3", "--dry-run"])
        let posixSuccess = (parseRes.command == .archive && parseRes.options.format == "tar.zst" && parseRes.options.dryRun)
        let posixDur = Date().timeIntervalSince(posixStart)
        t0Passed += (posixSuccess ? 1 : 0)
        t0Failed += (posixSuccess ? 0 : 1)
        let rec = TestCaseRecord(name: "testPOSIXCLIArgumentParser", className: "Tier0_CLIPOSIXTests", tier: 0, durationSeconds: posixDur, passed: posixSuccess)
        records.append(rec)
        t0Cases.append(["caseName": rec.name, "status": posixSuccess ? "passed" : "failed", "durationMs": posixDur * 1000.0])
        
        let t0TotalDur = Date().timeIntervalSince(t0Start) * 1000.0
        suiteResults.append([
            "suiteName": "Tier0_MicroUnitSuite",
            "passedCount": t0Passed,
            "failedCount": t0Failed,
            "skippedCount": 0,
            "durationMs": t0TotalDur,
            "cases": t0Cases
        ])
        
        if options.verbosity >= 1 && !options.jsonOutput {
            print(TestTerminalRenderer.renderAlignedRow(
                index: 1,
                total: 1,
                badge: .standards,
                target: "Tier 0",
                testName: "testPOSIXCLIArgumentParser",
                durationMs: t0TotalDur
            ))
        }
    }
    
    // MARK: - Tier 1 Suite Runner
    private static func runTier1Suite(options: CLIOptions, records: inout [TestCaseRecord], suiteResults: inout [[String: Any]]) {
        let nativeStartTime = Date()
        var nativePassed = 0
        var nativeFailed = 0
        var nativeCases: [[String: Any]] = []
        
        let selectedFormats = CLIArgumentParser.parseFormats(options.format) ?? ArchiveCompressionFormat.allCases.filter {
            $0 != .snappy
        }
        
        var formatIdx = 0
        let totalFormats = selectedFormats.count
        let verbosity = options.verbosity
        for format in selectedFormats {
            if let filter = options.filterPattern, !format.rawValue.localizedCaseInsensitiveContains(filter) && !filter.localizedCaseInsensitiveContains("format") {
                continue
            }
            formatIdx += 1
            let caseStartTime = Date()
            let config = FormatDiagnosticConfig(
                format: format,
                levelsToTest: [.store, .level1],
                testPasswordEncryption: false,
                sampleFileCount: 20,
                lineRepeatCount: 500
            )
            
            let isSuccess = (try? FormatDiagnosticSuiteRunner.shared.runDiagnosticSuite(config: config)) ?? false
            let caseDurationSec = Date().timeIntervalSince(caseStartTime)
            let caseDurationMs = caseDurationSec * 1000.0
            
            let rec = TestCaseRecord(
                name: "testDiagnostic_\(format.rawValue)",
                className: "Tier1_FormatRoundtripTests",
                tier: 1,
                durationSeconds: caseDurationSec,
                passed: isSuccess,
                failureMessage: isSuccess ? nil : "Diagnostic roundtrip failed for format: \(format.rawValue)"
            )
            records.append(rec)
            
            if isSuccess {
                nativePassed += 1
                nativeCases.append([
                    "caseName": rec.name,
                    "status": "passed",
                    "durationMs": caseDurationMs,
                    "assertionCount": 5
                ])
                if verbosity >= 1 && !options.jsonOutput {
                    print(TestTerminalRenderer.renderAlignedRow(
                        index: formatIdx,
                        total: totalFormats,
                        badge: .pass,
                        target: format.rawValue,
                        testName: rec.name,
                        durationMs: caseDurationMs
                    ))
                } else if verbosity == 0 && !options.jsonOutput {
                    print(".", terminator: "")
                    fflush(stdout)
                }
            } else {
                nativeFailed += 1
                nativeCases.append([
                    "caseName": rec.name,
                    "status": "failed",
                    "durationMs": caseDurationMs,
                    "assertionCount": 5
                ])
                if verbosity >= -1 && !options.jsonOutput {
                    print(TestTerminalRenderer.renderAlignedRow(
                        index: formatIdx,
                        total: totalFormats,
                        badge: .fail,
                        target: format.rawValue,
                        testName: rec.name,
                        durationMs: caseDurationMs
                    ))
                }
            }
        }
        
        if verbosity == 0 && !options.jsonOutput {
            print("")
        }
        
        let nativeDuration = Date().timeIntervalSince(nativeStartTime) * 1000.0
        suiteResults.append([
            "suiteName": "Tier1_FormatRoundtripSuite",
            "passedCount": nativePassed,
            "failedCount": nativeFailed,
            "skippedCount": 0,
            "durationMs": nativeDuration,
            "cases": nativeCases
        ])
    }
}
