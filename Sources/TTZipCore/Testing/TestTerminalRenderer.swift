// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Terminal renderer providing ANSI colored badges, summary tables, formatted hex diffs, and timing metrics
public enum TestTerminalRenderer: Sendable {
    
    // MARK: - ANSI Color Constants
    
    public enum ANSI {
        public static let reset = "\u{001B}[0m"
        public static let bold = "\u{001B}[1m"
        public static let dim = "\u{001B}[2m"
        
        // Standard colors
        public static let red = "\u{001B}[31m"
        public static let green = "\u{001B}[32m"
        public static let yellow = "\u{001B}[33m"
        public static let blue = "\u{001B}[34m"
        public static let magenta = "\u{001B}[35m"
        public static let cyan = "\u{001B}[36m"
        public static let white = "\u{001B}[37m"
        
        // Bold colors
        public static let boldRed = "\u{001B}[1;31m"
        public static let boldGreen = "\u{001B}[1;32m"
        public static let boldYellow = "\u{001B}[1;33m"
        public static let boldBlue = "\u{001B}[1;34m"
        public static let boldMagenta = "\u{001B}[1;35m"
        public static let boldCyan = "\u{001B}[1;36m"
        public static let boldWhite = "\u{001B}[1;37m"
        
        // High-intensity
        public static let brightYellow = "\u{001B}[1;93m"
        public static let brightCyan = "\u{001B}[1;96m"
    }
    
    // MARK: - Badges
    
    public enum Badge: String, Sendable, CaseIterable {
        case pass = "PASS"
        case fail = "FAIL"
        case skip = "SKIP"
        case standards = "STANDARDS"
        case oracle = "ORACLE"
        case fuzz = "FUZZ"
        case running = "RUN"
        case info = "INFO"
    }
    
    /// Render a colored badge with brackets
    public static func badge(_ type: Badge, useColor: Bool = true) -> String {
        guard useColor else {
            return "[\(type.rawValue)]"
        }
        
        switch type {
        case .pass:
            return "\(ANSI.boldGreen)[PASS]\(ANSI.reset)"
        case .fail:
            return "\(ANSI.boldRed)[FAIL]\(ANSI.reset)"
        case .skip:
            return "\(ANSI.boldYellow)[SKIP]\(ANSI.reset)"
        case .standards:
            return "\(ANSI.boldCyan)[STANDARDS]\(ANSI.reset)"
        case .oracle:
            return "\(ANSI.boldMagenta)[ORACLE]\(ANSI.reset)"
        case .fuzz:
            return "\(ANSI.brightYellow)[FUZZ]\(ANSI.reset)"
        case .running:
            return "\(ANSI.boldBlue)[RUN]\(ANSI.reset)"
        case .info:
            return "\(ANSI.boldWhite)[INFO]\(ANSI.reset)"
        }
    }
    
    public static func passBadge(useColor: Bool = true) -> String { badge(.pass, useColor: useColor) }
    public static func failBadge(useColor: Bool = true) -> String { badge(.fail, useColor: useColor) }
    public static func skipBadge(useColor: Bool = true) -> String { badge(.skip, useColor: useColor) }
    public static func standardsBadge(useColor: Bool = true) -> String { badge(.standards, useColor: useColor) }
    public static func oracleBadge(useColor: Bool = true) -> String { badge(.oracle, useColor: useColor) }
    public static func fuzzBadge(useColor: Bool = true) -> String { badge(.fuzz, useColor: useColor) }
    
    // MARK: - Timing Metrics
    
    /// Format millisecond duration with optimal unit (µs, ms, s)
    public static func formatDuration(ms: Double) -> String {
        if ms < 0.001 {
            return "< 1 µs"
        } else if ms < 1.0 {
            let us = ms * 1000.0
            return String(format: "%.1f µs", us)
        } else if ms < 1000.0 {
            return String(format: "%.2f ms", ms)
        } else {
            return String(format: "%.3f s", ms / 1000.0)
        }
    }
    
    /// Format throughput in MB/s or GB/s
    public static func formatThroughput(bytes: Int64, durationMs: Double) -> String {
        guard durationMs > 0 else { return "N/A" }
        let durationSec = durationMs / 1000.0
        let mbs = Double(bytes) / (1024.0 * 1024.0) / durationSec
        return formatThroughput(mbs: mbs)
    }
    
    /// Format throughput given MB/s
    public static func formatThroughput(mbs: Double) -> String {
        if mbs >= 1000.0 {
            return String(format: "%.2f GB/s", mbs / 1024.0)
        } else {
            return String(format: "%.1f MB/s", mbs)
        }
    }
    
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
    
    /// Format a pre-existing hex diff snippet with borders and ANSI highlight
    public static func renderHexDiffSnippet(
        _ snippet: String,
        useColor: Bool = true
    ) -> String {
        guard !snippet.isEmpty else { return "" }
        var s = ""
        if useColor {
            s += "\(ANSI.boldRed)┌── [Hex Difference Diagnostic] ──────────────────────────────────────────────────\(ANSI.reset)\n"
            s += snippet
            if !snippet.hasSuffix("\n") { s += "\n" }
            s += "\(ANSI.boldRed)└─────────────────────────────────────────────────────────────────────────────────\(ANSI.reset)\n"
        } else {
            s += "+-- [Hex Difference Diagnostic] --------------------------------------------------\n"
            s += snippet
            if !snippet.hasSuffix("\n") { s += "\n" }
            s += "+---------------------------------------------------------------------------------\n"
        }
        return s
    }
}
