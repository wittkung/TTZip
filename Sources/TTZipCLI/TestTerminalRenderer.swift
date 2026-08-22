// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Low-level ANSI styling, color constants, badges, and diagnostic formatting for terminal test reporting.
public enum TestTerminalANSIFormatter: Sendable {
    
    // MARK: - ANSI Color Constants
    public enum ANSI {
        public static let reset = "\u{001B}[0m"
        public static let bold = "\u{001B}[1m"
        public static let dim = "\u{001B}[2m"
        
        public static let red = "\u{001B}[31m"
        public static let green = "\u{001B}[32m"
        public static let yellow = "\u{001B}[33m"
        public static let blue = "\u{001B}[34m"
        public static let magenta = "\u{001B}[35m"
        public static let cyan = "\u{001B}[36m"
        public static let white = "\u{001B}[37m"
        
        public static let boldRed = "\u{001B}[1;31m"
        public static let boldGreen = "\u{001B}[1;32m"
        public static let boldYellow = "\u{001B}[1;33m"
        public static let boldBlue = "\u{001B}[1;34m"
        public static let boldMagenta = "\u{001B}[1;35m"
        public static let boldCyan = "\u{001B}[1;36m"
        public static let boldWhite = "\u{001B}[1;37m"
        
        public static let brightYellow = "\u{001B}[1;93m"
        public static let brightCyan = "\u{001B}[1;96m"
        public static let kintsugiGold = "\u{001B}[38;5;220m"
        public static let boldKintsugiGold = "\u{001B}[1;38;5;220m"
    }
    
    // MARK: - Badges
    public enum Badge: String, Sendable, CaseIterable {
        case pass = "PASS"
        case fail = "FAIL"
        case skip = "SKIP"
        case standards = "STANDARDS"
        case oracle = "ORACLE"
        case fuzz = "FUZZ"
        case perf = "PERF"
        case running = "RUN"
        case info = "INFO"
    }
    
    public static func badge(_ type: Badge, useColor: Bool = true) -> String {
        guard useColor else { return "[\(type.rawValue)]" }
        switch type {
        case .pass: return "\(ANSI.boldGreen)[PASS]\(ANSI.reset)"
        case .fail: return "\(ANSI.boldRed)[FAIL]\(ANSI.reset)"
        case .skip: return "\(ANSI.boldYellow)[SKIP]\(ANSI.reset)"
        case .standards: return "\(ANSI.boldCyan)[STANDARDS]\(ANSI.reset)"
        case .oracle: return "\(ANSI.boldMagenta)[ORACLE]\(ANSI.reset)"
        case .fuzz: return "\(ANSI.brightYellow)[FUZZ]\(ANSI.reset)"
        case .perf: return "\(ANSI.boldKintsugiGold)[PERF]\(ANSI.reset)"
        case .running: return "\(ANSI.boldBlue)[RUN]\(ANSI.reset)"
        case .info: return "\(ANSI.boldWhite)[INFO]\(ANSI.reset)"
        }
    }
    
    public static func formatDuration(ms: Double) -> String {
        if ms < 0.001 { return "< 1 µs" }
        if ms < 1.0 { return String(format: "%.1f µs", ms * 1000.0) }
        if ms < 1000.0 { return String(format: "%.2f ms", ms) }
        return String(format: "%.2f s", ms / 1000.0)
    }
}

/// High-level terminal test renderer providing streaming progress rows, suite breakdown tables, and execution dashboards.
public enum TestTerminalRenderer: Sendable {
    public typealias ANSI = TestTerminalANSIFormatter.ANSI
    public typealias Badge = TestTerminalANSIFormatter.Badge
    
    @inlinable
    public static func badge(_ type: Badge, useColor: Bool = true) -> String {
        TestTerminalANSIFormatter.badge(type, useColor: useColor)
    }
    
    @inlinable
    public static func formatDuration(ms: Double) -> String {
        TestTerminalANSIFormatter.formatDuration(ms: ms)
    }
    
    /// Render aligned streaming test progress row
    public static func renderAlignedRow(
        index: Int,
        total: Int,
        badge badgeType: Badge,
        target: String,
        testName: String,
        durationMs: Double,
        useColor: Bool = true
    ) -> String {
        let b = badge(badgeType, useColor: useColor)
        let dur = formatDuration(ms: durationMs)
        let targetPadded = target.padding(toLength: 12, withPad: " ", startingAt: 0)
        let namePadded = testName.count > 42 ? String(testName.prefix(39)) + "..." : testName.padding(toLength: 42, withPad: " ", startingAt: 0)
        let idxStr = String(format: "%3d/%3d", index, total)
        return "  [\(idxStr)] \(b) [\(targetPadded)] \(namePadded) (\(dur))"
    }
}
