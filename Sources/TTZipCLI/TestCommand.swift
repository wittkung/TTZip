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

/// Modular automated test harness and diagnostics runner.
///
/// Supports multi-tier test execution (Tier 0 through Tier 5), format standards verification,
/// cross-engine differential oracle validation, and malformed stream fuzz mutation testing.
/// Reports can be emitted to stdout, JUnit XML, JSON, or Markdown dashboards.
public enum TestCommand {
    
    /// Main entry point for executing test driver commands.
    /// - Parameter options: Command-line configuration specifying filters, tiers, or reporting paths.
    public static func run(options: CLIOptions) async {
        // Legacy backward compatibility: If positional argument points to an existing file, check its integrity.
        if let firstArg = options.positionals.first, FileManager.default.fileExists(atPath: firstArg) {
            await runFileIntegrity(path: firstArg)
            return
        }
        
        let startTimestamp = Date()
        let sessionID = "TEST-" + ISO8601DateFormatter().string(from: startTimestamp).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        
        // Emit test initiation telemetry event if JSON mode is enabled
        if options.jsonOutput {
            TestTelemetryStream.emitNDJSON(TestTelemetryEvent.runStarted(
                sessionID: sessionID
            ))
        }
        
        configureLogging(verbosity: options.verbosity)
        renderHeaderBanner(options: options, sessionID: sessionID)
        
        var testCaseRecords: [TestCaseRecord] = []
        var suiteResults: [[String: Any]] = []
        
        await runConfiguredSuites(
            options: options,
            sessionID: sessionID,
            records: &testCaseRecords,
            suiteResults: &suiteResults
        )
        
        let totalDuration = Date().timeIntervalSince(startTimestamp) * 1000.0
        let totalPassed = testCaseRecords.filter(\.passed).count
        let totalFailed = testCaseRecords.filter { !$0.passed }.count
        let totalCases = testCaseRecords.count
        let passRate = totalCases > 0 ? (Double(totalPassed) / Double(totalCases)) * 100.0 : 100.0
        
        emitReportsAndSummary(
            options: options,
            sessionID: sessionID,
            startTimestamp: startTimestamp,
            totalDuration: totalDuration,
            testCaseRecords: testCaseRecords,
            suiteResults: suiteResults,
            totalPassed: totalPassed,
            totalFailed: totalFailed,
            totalCases: totalCases,
            passRate: passRate
        )
        
        if totalFailed > 0 {
            exit(EXIT_FAILURE)
        }
    }
    
    private static func configureLogging(verbosity: Int) {
        if verbosity <= 1 {
            TTLogger.shared.level = .warning
        } else if verbosity == 2 {
            TTLogger.shared.level = .info
        } else if verbosity >= 3 {
            TTLogger.shared.level = .debug
        }
    }
    
    private static func runFileIntegrity(path: String) async {
        print("🔍 Checking archive integrity for: \(path)...")
        let reader = ArchiveReader()
        do {
            let entries = try await reader.inspect(archivePath: path)
            print("✓ Archive valid: \(entries.count) entries")
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: archive integrity check failed: \(error)")
            exit(EXIT_FAILURE)
        }
    }
}
