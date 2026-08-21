// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// High-level terminal test renderer providing streaming progress rows, suite breakdown tables, and execution dashboards.
public enum TestTerminalRenderer: Sendable {
    
    // MARK: - Aliases & Delegations
    
    public typealias ANSI = TestTerminalANSIFormatter.ANSI
    public typealias Badge = TestTerminalANSIFormatter.Badge
    
    @inlinable
    public static func badge(_ type: Badge, useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.badge(type, useColor: useColor)
    }
    
    @inlinable
    public static func passBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.passBadge(useColor: useColor)
    }
    
    @inlinable
    public static func failBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.failBadge(useColor: useColor)
    }
    
    @inlinable
    public static func skipBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.skipBadge(useColor: useColor)
    }
    
    @inlinable
    public static func standardsBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.standardsBadge(useColor: useColor)
    }
    
    @inlinable
    public static func oracleBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.oracleBadge(useColor: useColor)
    }
    
    @inlinable
    public static func fuzzBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.fuzzBadge(useColor: useColor)
    }
    
    @inlinable
    public static func perfBadge(useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.perfBadge(useColor: useColor)
    }
    
    @inlinable
    public static func formatDuration(ms: Double) -> String {
        TestTerminalANSIFormatter.formatDuration(ms: ms)
    }
    
    @inlinable
    public static func formatThroughput(bytes: Int64, durationMs: Double) -> String {
        TestTerminalANSIFormatter.formatThroughput(bytes: bytes, durationMs: durationMs)
    }
    
    @inlinable
    public static func formatThroughput(mbs: Double) -> String {
        TestTerminalANSIFormatter.formatThroughput(mbs: mbs)
    }
    
    @inlinable
    public static func renderHexDiffSnippet(_ snippet: String, useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.renderHexDiffSnippet(snippet, useColor: useColor)
    }
    
    // MARK: - Aligned Streaming Row (zlib-ng & CTest Paradigm)
    
    /// Render aligned streaming test progress row
    public static func renderAlignedRow(
        index: Int,
        total: Int,
        badge badgeType: Badge,
        target: String,
        testName: String,
        durationMs: Double,
        useColor: Bool = TerminalCapabilities.supportsColor
    ) -> String {
        let b = badge(badgeType, useColor: useColor)
        let dur = formatDuration(ms: durationMs)
        let targetPadded = target.padding(toLength: 12, withPad: " ", startingAt: 0)
        let namePadded = testName.count > 42 ? String(testName.prefix(39)) + "..." : testName.padding(toLength: 42, withPad: " ", startingAt: 0)
        let idxStr = String(format: "%3d/%3d", index, total)
        return "  [\(idxStr)] \(b) [\(targetPadded)] \(namePadded) (\(dur))"
    }
    
    // MARK: - Timing Metrics Row
    
    /// Render timing metrics row
    public static func renderTimingMetrics(
        label: String,
        durationMs: Double,
        throughputMBs: Double? = nil,
        useColor: Bool = true
    ) -> String {
        let durStr = formatDuration(ms: durationMs)
        var out = "  ⏱️ \(label): "
        if useColor {
            out += "\(ANSI.boldCyan)\(durStr)\(ANSI.reset)"
        } else {
            out += durStr
        }
        
        if let tp = throughputMBs {
            let tpStr = formatThroughput(mbs: tp)
            out += " | Throughput: "
            if useColor {
                out += "\(ANSI.boldGreen)\(tpStr)\(ANSI.reset)"
            } else {
                out += tpStr
            }
        }
        return out
    }
    
    // MARK: - Banner & Header
    
    /// Render standard session header
    public static func renderHeader(
        sessionID: String,
        tier: String? = nil,
        filter: String? = nil,
        useColor: Bool = true
    ) -> String {
        var s = ""
        s += "==========================================================================================\n"
        if useColor {
            s += "   🧪 \(ANSI.boldCyan)[TTZip Native Test Harness]\(ANSI.reset) Session: \(sessionID)\n"
        } else {
            s += "   [TTZip Native Test Harness] Session: \(sessionID)\n"
        }
        if let tier = tier {
            s += "   🏷️  Tier Filter: \"\(tier)\"\n"
        }
        if let filter = filter {
            s += "   🔍 Pattern Filter: \"\(filter)\"\n"
        }
        s += "=========================================================================================="
        return s
    }
    
    // MARK: - Summary Models & Tables
    
    public struct SuiteSummary: Sendable, Equatable {
        public let suiteName: String
        public let category: String
        public let passed: Int
        public let failed: Int
        public let skipped: Int
        public let durationMs: Double
        
        public init(
            suiteName: String,
            category: String = "Standards",
            passed: Int,
            failed: Int,
            skipped: Int = 0,
            durationMs: Double
        ) {
            self.suiteName = suiteName
            self.category = category
            self.passed = passed
            self.failed = failed
            self.skipped = skipped
            self.durationMs = durationMs
        }
    }
    
    /// Render formatted suite breakdown table
    public static func renderSuiteTable(
        suites: [SuiteSummary],
        useColor: Bool = true
    ) -> String {
        var s = ""
        let sep = "+------------------------------------------+------------+--------+--------+---------+-------------+"
        let header = "| Suite Name                               | Category   | Passed | Failed | Skipped | Duration    |"
        
        s += "\(sep)\n"
        s += "\(header)\n"
        s += "\(sep)\n"
        
        for suite in suites {
            let namePadded = suite.suiteName.padding(toLength: 40, withPad: " ", startingAt: 0)
            let catPadded = suite.category.padding(toLength: 10, withPad: " ", startingAt: 0)
            let passStr = String(format: "%6d", suite.passed)
            let failStr = String(format: "%6d", suite.failed)
            let skipStr = String(format: "%7d", suite.skipped)
            let durStr = formatDuration(ms: suite.durationMs).padding(toLength: 11, withPad: " ", startingAt: 0)
            
            let statusFail = suite.failed > 0
            if useColor && statusFail {
                s += "| \(ANSI.boldRed)\(namePadded)\(ANSI.reset) | \(catPadded) | \(passStr) | \(ANSI.boldRed)\(failStr)\(ANSI.reset) | \(skipStr) | \(durStr) |\n"
            } else if useColor {
                s += "| \(ANSI.boldGreen)\(namePadded)\(ANSI.reset) | \(catPadded) | \(passStr) | \(failStr) | \(skipStr) | \(durStr) |\n"
            } else {
                s += "| \(namePadded) | \(catPadded) | \(passStr) | \(failStr) | \(skipStr) | \(durStr) |\n"
            }
        }
        
        s += "\(sep)"
        return s
    }
    
    /// Render execution summary dashboard
    public static func renderSummaryTable(
        metrics: TestTelemetryEvent.TelemetryMetrics,
        durationMs: Double,
        sessionID: String,
        osVersion: String? = nil,
        arch: String? = nil,
        useColor: Bool = true
    ) -> String {
        var s = ""
        s += "\n==========================================================================================\n"
        
        let durStr = formatDuration(ms: durationMs)
        let passRateStr = String(format: "%.1f%%", metrics.passRate)
        
        if metrics.failedTests == 0 {
            if useColor {
                s += "   \(ANSI.boldGreen)✓ [ALL TESTS PASSED]\(ANSI.reset) "
            } else {
                s += "   [ALL TESTS PASSED] "
            }
        } else {
            if useColor {
                s += "   \(ANSI.boldRed)✗ [TEST FAILURES DETECTED]\(ANSI.reset) "
            } else {
                s += "   [TEST FAILURES DETECTED] "
            }
        }
        
        s += "Total: \(metrics.totalTests) | Passed: \(metrics.passedTests) | Failed: \(metrics.failedTests) | Skipped: \(metrics.skippedTests)\n"
        s += "   📊 Pass Rate: \(passRateStr) | Total Duration: \(durStr) | Session: \(sessionID)\n"
        
        if let os = osVersion, let a = arch {
            s += "   💻 Host: \(os) (\(a))\n"
        }
        
        s += "=========================================================================================="
        return s
    }
    
    /// Render single test case result line
    public static func renderTestCaseRow(
        index: Int,
        badge badgeType: Badge,
        name: String,
        target: String,
        durationMs: Double,
        errorMessage: String? = nil,
        useColor: Bool = true
    ) -> String {
        let b = badge(badgeType, useColor: useColor)
        let dur = formatDuration(ms: durationMs)
        var s = String(format: "  %3d. %@ [%@] %@ (%@)", index, b, target, name, dur)
        if let err = errorMessage {
            if useColor {
                s += "\n       \(ANSI.boldRed)↳ Error:\(ANSI.reset) \(err)"
            } else {
                s += "\n       ↳ Error: \(err)"
            }
        }
        return s
    }
    
    // MARK: - Formatted Hex Diff Rendering
    
    /// Render formatted hex diff between expected and actual data using FastHexDiffEngine
    public static func renderHexDiff(
        expected: Data,
        actual: Data,
        maxWindow: Int = 256,
        useColor: Bool = true
    ) -> String {
        if let diff = FastHexDiffEngine.generateDiff(
            expected: expected,
            actual: actual,
            maxWindow: maxWindow,
            useAnsi: useColor
        ) {
            return diff
        } else {
            return "  ✓ [Hex Match] Buffers are identical (\(expected.count) bytes)\n"
        }
    }
    
    /// Render formatted hex diff between expected and actual buffer pointers
    public static func renderHexDiff(
        expected: UnsafeRawBufferPointer,
        actual: UnsafeRawBufferPointer,
        maxWindow: Int = 256,
        useColor: Bool = true
    ) -> String {
        if let diff = FastHexDiffEngine.generateDiff(
            expected: expected,
            actual: actual,
            maxWindow: maxWindow,
            useAnsi: useColor
        ) {
            return diff
        } else {
            return "  ✓ [Hex Match] Buffers are identical (\(expected.count) bytes)\n"
        }
    }
}
