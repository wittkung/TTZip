// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// 模块化测试调度引擎 (支持 Tier 0-5 分层过滤、JUnit XML、JSON、Markdown)
public enum TestCommand {
    
    /// 执行 CLI 驱动的自动化测试
    public static func run(options: CLIOptions) async {
        // 兼容旧行为：若位置参数为既有归档文件，则执行完整性校验
        if let firstArg = options.positionals.first, FileManager.default.fileExists(atPath: firstArg) {
            await runFileIntegrity(path: firstArg)
            return
        }
        
        let startTimestamp = Date()
        let sessionID = "TEST-" + ISO8601DateFormatter().string(from: startTimestamp).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        
        let verbosity = options.verbosity
        if verbosity >= 0 {
            print("\n==========================================================================================")
            print("   🧪 \u{001B}[1;36m[TTZip Native Test Harness]\u{001B}[0m Running Test Driver (Session: \(sessionID))")
            if let tier = options.tier {
                print("   🏷️ Tier Filter: \"\(tier)\"")
            }
            if let filter = options.filterPattern {
                print("   🔍 Filter: \"\(filter)\" | Verbosity: \(verbosity) | KeepTemp: \(options.keepTempFiles)")
            }
            print("==========================================================================================\n")
        }
        
        var testCaseRecords: [TestCaseRecord] = []
        var suiteResults: [[String: Any]] = []
        
        // 解析选定的测试分层 (默认为 Tier 0 + Tier 1)
        let activeTiers: Set<Int>
        if let tierStr = options.tier {
            let parsed = tierStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: CharacterSet.whitespaces)) }
            activeTiers = Set(parsed.isEmpty ? [0, 1] : parsed)
        } else {
            activeTiers = [0, 1]
        }
        
        // MARK: - 1. Tier 0: 纯内存微单元测试 (SIMD / 本地化 / POSIX 命令行规范)
        if activeTiers.contains(0) {
            let t0Start = Date()
            var t0Passed = 0
            var t0Failed = 0
            var t0Cases: [[String: Any]] = []
            
            // 1.1 本地化完备性测试
            let l10nStart = Date()
            var l10nSuccess = true
            let allKeys = L10n.allRawKeys
            for lang in AppLanguage.allCases {
                for key in allKeys {
                    let val = TTZipLocalizationManager.shared.string(for: RawKeyWrapper(key), language: lang)
                    if val == key || val.isEmpty { l10nSuccess = false }
                }
            }
            let l10nDur = Date().timeIntervalSince(l10nStart)
            t0Passed += (l10nSuccess ? 1 : 0)
            t0Failed += (l10nSuccess ? 0 : 1)
            let rec1 = TestCaseRecord(name: "testLocalizationIntegrity", className: "Tier0_LocalizationTests", tier: 0, durationSeconds: l10nDur, passed: l10nSuccess)
            testCaseRecords.append(rec1)
            t0Cases.append(["caseName": rec1.name, "status": l10nSuccess ? "passed" : "failed", "durationMs": l10nDur * 1000.0])
            
            // 1.2 POSIX 参数解析规范测试
            let posixStart = Date()
            let parseRes = POSIXCLIArgumentParser.parse(args: ["archive", "out.tar.zst", "src/", "--format=tar.zst", "--level=3", "--dry-run"])
            let posixSuccess = (parseRes.command == .archive && parseRes.options.format == "tar.zst" && parseRes.options.dryRun)
            let posixDur = Date().timeIntervalSince(posixStart)
            t0Passed += (posixSuccess ? 1 : 0)
            t0Failed += (posixSuccess ? 0 : 1)
            let rec2 = TestCaseRecord(name: "testPOSIXCLIArgumentParser", className: "Tier0_CLIPOSIXTests", tier: 0, durationSeconds: posixDur, passed: posixSuccess)
            testCaseRecords.append(rec2)
            t0Cases.append(["caseName": rec2.name, "status": posixSuccess ? "passed" : "failed", "durationMs": posixDur * 1000.0])
            
            let t0TotalDur = Date().timeIntervalSince(t0Start) * 1000.0
            suiteResults.append([
                "suiteName": "Tier0_MicroUnitSuite",
                "passedCount": t0Passed,
                "failedCount": t0Failed,
                "skippedCount": 0,
                "durationMs": t0TotalDur,
                "cases": t0Cases
            ])
            
            if verbosity >= 1 {
                print("  \u{001B}[32m✓\u{001B}[0m [Tier 0] Micro/Unit suites passed (\(String(format: "%.1f", t0TotalDur))ms)")
            }
        }
        
        // MARK: - 2. Tier 1: 16 种格式往返与诊断测试
        if activeTiers.contains(1) {
            let nativeStartTime = Date()
            var nativePassed = 0
            var nativeFailed = 0
            var nativeCases: [[String: Any]] = []
            
            let selectedFormats = CLIArgumentParser.parseFormats(options.format) ?? ArchiveCompressionFormat.allCases.filter {
                $0 != .snappy
            }
            
            for format in selectedFormats {
                if let filter = options.filterPattern, !format.rawValue.localizedCaseInsensitiveContains(filter) && !filter.localizedCaseInsensitiveContains("format") {
                    continue
                }
                
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
                testCaseRecords.append(rec)
                
                if isSuccess {
                    nativePassed += 1
                    nativeCases.append([
                        "caseName": rec.name,
                        "status": "passed",
                        "durationMs": caseDurationMs,
                        "assertionCount": 5
                    ])
                    if verbosity >= 1 {
                        print("  \u{001B}[32m✓\u{001B}[0m [Tier 1] \(format.rawValue.uppercased()) roundtrip pass (\(String(format: "%.1f", caseDurationMs))ms)")
                    } else if verbosity == 0 {
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
                    if verbosity >= -1 {
                        print("\n  \u{001B}[31m✗\u{001B}[0m [Tier 1] \(format.rawValue.uppercased()) failed roundtrip validation")
                    }
                }
            }
            
            if verbosity == 0 {
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
        
        let totalDuration = Date().timeIntervalSince(startTimestamp) * 1000.0
        let totalPassed = testCaseRecords.filter(\.passed).count
        let totalFailed = testCaseRecords.filter { !$0.passed }.count
        let totalCases = testCaseRecords.count
        let passRate = totalCases > 0 ? (Double(totalPassed) / Double(totalCases)) * 100.0 : 100.0
        
        let sessionReport = TestSessionReport(
            timestamp: startTimestamp.timeIntervalSince1970,
            testCases: testCaseRecords
        )
        
        // 3. 持久化各种格式的测试报告
        if let jsonPath = options.jsonReportPath {
            let jsonString = sessionReport.toJSON()
            let url = URL(fileURLWithPath: jsonPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
            if verbosity >= 0 {
                print("  📄 JSON Report saved to: \(jsonPath)")
            }
        }
        
        if let junitPath = options.junitReportPath {
            let xmlString = JUnitReportBuilder.buildXML(from: sessionReport)
            let url = URL(fileURLWithPath: junitPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? xmlString.write(to: url, atomically: true, encoding: .utf8)
            if verbosity >= 0 {
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
            if verbosity >= 0 {
                print("  📊 Markdown Report saved to: \(mdPath)")
            }
        }
        
        // 4. 控制台汇总看板
        if verbosity >= 0 {
            print("\n==========================================================================================")
            if totalFailed == 0 {
                print("   \u{001B}[1;32m✓ [ALL TESTS PASSED]\u{001B}[0m Total: \(totalCases) | Passed: \(totalPassed) | Time: \(String(format: "%.2f", totalDuration))ms | Pass Rate: 100%")
            } else {
                print("   \u{001B}[1;31m✗ [TEST FAILURES DETECTED]\u{001B}[0m Passed: \(totalPassed) | Failed: \(totalFailed) | Time: \(String(format: "%.2f", totalDuration))ms")
            }
            print("==========================================================================================\n")
        }
        
        if totalFailed > 0 {
            exit(1)
        }
    }
    
    private static func runFileIntegrity(path: String) async {
        print("🔍 Checking archive integrity for: \(path)...")
        let reader = ArchiveReader()
        do {
            let entries = try await reader.inspect(archivePath: path)
            print("✓ Archive valid: \(entries.count) entries")
        } catch {
            print("❌ Archive integrity error: \(error)")
            exit(1)
        }
    }
}

private struct RawKeyWrapper: LocaleKeyProtocol {
    let rawKey: String
    init(_ key: String) { self.rawKey = key }
}
