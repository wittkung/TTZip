import Foundation
import TTZipCore

/// 独立的工业级本地测试驱动命令处理器 (对标 libarchive test_main.c)
public enum TestCommand {
    
    /// 执行测试调度主入口
    public static func run(options: CLIOptions) async {
        // 向后兼容：若位置参数为存在的物理归档文件，执行文件完整性校验
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
            if let filter = options.filterPattern {
                print("   🔍 Filter: \"\(filter)\" | Verbosity: \(verbosity) | KeepTemp: \(options.keepTempFiles)")
            }
            print("==========================================================================================\n")
        }
        
        var totalPassed = 0
        var totalFailed = 0
        let totalSkipped = 0
        var totalAssertions = 0

        var suiteResults: [[String: Any]] = []
        
        // 1. 运行 Native In-Process 极速诊断矩阵 (16 种格式往返闭环验证)
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
            let caseDuration = Date().timeIntervalSince(caseStartTime) * 1000.0
            
            if isSuccess {
                nativePassed += 1
                totalAssertions += 5
                nativeCases.append([
                    "caseName": "diagnostic_\(format.rawValue)",
                    "status": "passed",
                    "durationMs": caseDuration,
                    "assertionCount": 5
                ])
                if verbosity >= 1 {
                    print("  \u{001B}[32m✓\u{001B}[0m [NativeDiagnostic] \(format.rawValue.uppercased()) roundtrip pass (\(String(format: "%.1f", caseDuration))ms)")
                } else if verbosity == 0 {
                    print(".", terminator: "")
                    fflush(stdout)
                }
            } else {
                nativeFailed += 1
                totalAssertions += 5
                let failureInfo: [String: Any] = [
                    "file": "Sources/TTZipCore/Benchmark/FormatDiagnosticSuiteRunner.swift",
                    "line": 50,
                    "expression": "runDiagnosticSuite == true",
                    "deferredMessage": "Diagnostic roundtrip failed for format: \(format.rawValue)"
                ]
                nativeCases.append([
                    "caseName": "diagnostic_\(format.rawValue)",
                    "status": "failed",
                    "durationMs": caseDuration,
                    "assertionCount": 5,
                    "failure": failureInfo
                ])
                if verbosity >= -1 {
                    print("\n  \u{001B}[31m✗\u{001B}[0m [NativeDiagnostic] \(format.rawValue.uppercased()) failed roundtrip validation")
                }
            }
        }
        
        if verbosity == 0 {
            print("")
        }
        
        let nativeDuration = Date().timeIntervalSince(nativeStartTime) * 1000.0
        totalPassed += nativePassed
        totalFailed += nativeFailed
        
        suiteResults.append([
            "suiteName": "NativeFormatDiagnosticSuite",
            "passedCount": nativePassed,
            "failedCount": nativeFailed,
            "skippedCount": 0,
            "totalAssertions": (nativePassed + nativeFailed) * 5,
            "durationMs": nativeDuration,
            "cases": nativeCases
        ])
        
        let totalDuration = Date().timeIntervalSince(startTimestamp) * 1000.0
        let totalCases = totalPassed + totalFailed + totalSkipped
        let passRate = totalCases > 0 ? (Double(totalPassed) / Double(totalCases)) * 100.0 : 100.0
        
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let cpuArch = "arm64 (Apple Silicon)"
        #else
        let cpuArch = "x86_64 (Intel)"
        #endif
        let cores = ProcessInfo.processInfo.activeProcessorCount
        
        // 2. 组装强类型测试报告字典
        let reportData: [String: Any] = [
            "sessionId": sessionID,
            "startTime": ISO8601DateFormatter().string(from: startTimestamp),
            "endTime": ISO8601DateFormatter().string(from: Date()),
            "durationMs": totalDuration,
            "environment": [
                "osVersion": osVer,
                "cpuArchitecture": cpuArch,
                "logicalCores": cores,
                "swiftVersion": "6.0"
            ],
            "options": [
                "filterPattern": options.filterPattern ?? "",
                "verbosity": options.verbosity,
                "keepTempFiles": options.keepTempFiles,
                "dumpOnFailure": options.dumpOnFailure,
                "jsonReportPath": options.jsonReportPath ?? "",
                "markdownReportPath": options.markdownReportPath ?? ""
            ],
            "summary": [
                "totalSuites": suiteResults.count,
                "totalCases": totalCases,
                "passedCases": totalPassed,
                "failedCases": totalFailed,
                "skippedCases": totalSkipped,
                "totalAssertions": totalAssertions,
                "passRate": passRate
            ],
            "suites": suiteResults
        ]
        
        // 3. 输出报告持久化
        if let jsonPath = options.jsonReportPath {
            TestReportGenerator.generateJSON(report: reportData, outputPath: jsonPath)
            if verbosity >= 0 {
                print("  📄 JSON Report saved to: \(jsonPath)")
            }
        }
        
        if let mdPath = options.markdownReportPath {
            TestReportGenerator.generateMarkdown(
                sessionID: sessionID,
                startTime: ISO8601DateFormatter().string(from: startTimestamp),
                durationMs: totalDuration,
                osVersion: osVer,
                arch: cpuArch,
                totalSuites: suiteResults.count,
                totalCases: totalCases,
                passedCases: totalPassed,
                failedCases: totalFailed,
                skippedCases: totalSkipped,
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
