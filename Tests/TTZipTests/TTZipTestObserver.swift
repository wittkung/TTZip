// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// Industrial-grade in-process test observation and lifecycle telemetry engine.
///
/// Designed after libarchive test harness:
/// - Silent on success (zero console noise, in-memory log capture)
/// - Diagnostic dump on failure (instant context restoration with line numbers)
/// - High-density single-line suite progress reporting
/// - Structured Totals summary dashboard
public final class TTZipTestObserver: NSObject, XCTestObservation, @unchecked Sendable {
    
    public static let shared = TTZipTestObserver()
    nonisolated(unsafe) private static var isRegistered = false
    private static let lock = NSLock()
    
    // Bundle metrics
    nonisolated(unsafe) private var bundleStartTime: DispatchTime = .now()
    nonisolated(unsafe) private var totalSuitesCount: Int = 0
    nonisolated(unsafe) private var totalTestsCount: Int = 0
    nonisolated(unsafe) private var totalPassedCount: Int = 0
    nonisolated(unsafe) private var totalFailedCount: Int = 0
    nonisolated(unsafe) private var totalSkippedCount: Int = 0
    
    // Current suite metrics
    nonisolated(unsafe) private var currentSuiteName: String = ""
    nonisolated(unsafe) private var currentSuiteStartTime: DispatchTime = .now()
    nonisolated(unsafe) private var currentSuiteTotal: Int = 0
    nonisolated(unsafe) private var currentSuitePassed: Int = 0
    nonisolated(unsafe) private var currentSuiteFailed: Int = 0
    nonisolated(unsafe) private var currentSuiteSkipped: Int = 0
    
    // Current test state
    nonisolated(unsafe) private var currentTestHasFailed: Bool = false
    nonisolated(unsafe) private var currentTestFailureMessages: [String] = []
    
    /// Registers the singleton observer into XCTestObservationCenter if not already registered.
    public static func registerObserverIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRegistered else { return }
        XCTestObservationCenter.shared.addTestObserver(shared)
        isRegistered = true
    }
    
    // MARK: - Bundle Lifecycle
    
    public func testBundleWillStart(_ testBundle: Bundle) {
        Self.lock.lock()
        bundleStartTime = .now()
        totalSuitesCount = 0
        totalTestsCount = 0
        totalPassedCount = 0
        totalFailedCount = 0
        totalSkippedCount = 0
        Self.lock.unlock()
    }
    
    // MARK: - Suite Lifecycle
    
    public func testSuiteWillStart(_ testSuite: XCTestSuite) {
        let name = testSuite.name
        // Filter synthetic wrapper suites
        guard !name.hasSuffix(".xctest"), name != "All tests", name != "Selected tests" else { return }
        
        Self.lock.lock()
        currentSuiteName = name
        currentSuiteStartTime = .now()
        currentSuiteTotal = 0
        currentSuitePassed = 0
        currentSuiteFailed = 0
        currentSuiteSkipped = 0
        Self.lock.unlock()
    }
    
    // MARK: - Case Lifecycle
    
    public func testCaseWillStart(_ testCase: XCTestCase) {
        Self.lock.lock()
        currentTestHasFailed = false
        currentTestFailureMessages.removeAll()
        Self.lock.unlock()
        
        // Silence console and capture logs into 2,000-entry ring buffer
        TTLogger.startTestCapture()
    }
    
    public func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        Self.lock.lock()
        currentTestHasFailed = true
        let loc = issue.sourceCodeContext.location
        let locStr = loc != nil ? " [\(loc!.fileURL.lastPathComponent):\(loc!.lineNumber)]" : ""
        currentTestFailureMessages.append("\(issue.description)\(locStr)")
        Self.lock.unlock()
    }
    
    public func testCaseDidFinish(_ testCase: XCTestCase) {
        Self.lock.lock()
        let run = testCase.testRun
        let isSkipped = run?.hasBeenSkipped ?? false
        let hasFailed = currentTestHasFailed || ((run?.totalFailureCount ?? 0) > 0)
        
        currentSuiteTotal += 1
        totalTestsCount += 1
        
        if isSkipped {
            currentSuiteSkipped += 1
            totalSkippedCount += 1
        } else if hasFailed {
            currentSuiteFailed += 1
            totalFailedCount += 1
        } else {
            currentSuitePassed += 1
            totalPassedCount += 1
        }
        
        let failures = currentTestFailureMessages
        Self.lock.unlock()
        
        if hasFailed {
            // Dump diagnostic logs from memory ring buffer with failure location
            TTLogger.dumpCapturedLogsOnFailure(testName: testCase.name)
            if !failures.isEmpty {
                for f in failures {
                    fputs("    \u{001B}[31m✖ \(f)\u{001B}[0m\n", stderr)
                }
            }
        } else {
            // Test passed cleanly: recycle memory buffer silently
            TTLogger.clearTestCapture()
        }
    }
    
    public func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        let name = testSuite.name
        guard !name.hasSuffix(".xctest"), name != "All tests", name != "Selected tests" else { return }
        
        Self.lock.lock()
        totalSuitesCount += 1
        let elapsedNs = DispatchTime.now().uptimeNanoseconds - currentSuiteStartTime.uptimeNanoseconds
        let elapsedMs = Double(elapsedNs) / 1_000_000.0
        let total = currentSuiteTotal
        let passed = currentSuitePassed
        let failed = currentSuiteFailed
        let skipped = currentSuiteSkipped
        Self.lock.unlock()
        
        guard total > 0 else { return }
        
        let statusIcon = failed > 0 ? "\u{001B}[31m✖\u{001B}[0m" : "\u{001B}[32m✓\u{001B}[0m"
        let durationColor = elapsedMs >= 1000.0 ? "\u{001B}[33m" : "\u{001B}[90m"
        let durationStr = "\(durationColor)\(String(format: "%.1f", elapsedMs))ms\u{001B}[0m"
        
        var summaryDetails = "\(passed) passed"
        if failed > 0 { summaryDetails += ", \u{001B}[31m\(failed) failed\u{001B}[0m" }
        if skipped > 0 { summaryDetails += ", \u{001B}[36m\(skipped) skipped\u{001B}[0m" }
        
        let paddedName = name.padding(toLength: 50, withPad: " ", startingAt: 0)
        let outputLine = "  \(statusIcon) \(paddedName) (\(summaryDetails), \(durationStr))\n"
        fputs(outputLine, stdout)
        fflush(stdout)
    }
    
    // MARK: - Bundle Summary
    
    public func testBundleDidFinish(_ testBundle: Bundle) {
        Self.lock.lock()
        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - bundleStartTime.uptimeNanoseconds) / 1_000_000_000.0
        let suites = totalSuitesCount
        let tests = totalTestsCount
        let passed = totalPassedCount
        let failed = totalFailedCount
        let skipped = totalSkippedCount
        Self.lock.unlock()
        
        guard tests > 0 else { return }
        
        let passRatio = Double(passed) / Double(max(1, tests - skipped)) * 100.0
        let statusTag = failed == 0 ? "\u{001B}[32;1mPASSED (100% OK)\u{001B}[0m" : "\u{001B}[31;1mFAILED (\(failed) ERRORS)\u{001B}[0m"
        
        let banner = """
        
        ================================================================================
        📊 TTZip Test Suite Execution Summary (libarchive Standards)
        ================================================================================
          Status      : \(statusTag)
          Test Suites : \(suites) suites completed
          Total Tests : \(tests) executed (\(passed) passed, \(failed) failed, \(skipped) skipped)
          Pass Rate   : \(String(format: "%.1f%%", passRatio))
          Total Time  : \(String(format: "%.3f", elapsedSec)) seconds
        ================================================================================
        
        """
        fputs(banner, stdout)
        fflush(stdout)
    }
}
