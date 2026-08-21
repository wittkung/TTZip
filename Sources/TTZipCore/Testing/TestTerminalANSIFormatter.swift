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
        
        // High-intensity & Kintsugi Gold
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
        case .perf:
            return "\(ANSI.boldKintsugiGold)[PERF]\(ANSI.reset)"
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
    public static func perfBadge(useColor: Bool = true) -> String { badge(.perf, useColor: useColor) }
    
    // MARK: - Metrics Formatting
    
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
    
    // MARK: - Hex Diff Snippet Formatting
    
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
