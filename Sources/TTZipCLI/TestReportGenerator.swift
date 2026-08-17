// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Test report generation and persistence engine (supports Console ANSI, Markdown, and JSON Schema outputs).
public enum TestReportGenerator {
    
    /// Generate structured JSON string and optionally persist to destination path
    @discardableResult
    public static func generateJSON(
        report: [String: Any],
        outputPath: String? = nil
    ) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        if let path = outputPath {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return jsonString
    }
    
    /// Generate formatted Markdown report and optionally persist to destination path
    @discardableResult
    public static func generateMarkdown(
        sessionID: String,
        startTime: String,
        durationMs: Double,
        osVersion: String,
        arch: String,
        totalSuites: Int,
        totalCases: Int,
        passedCases: Int,
        failedCases: Int,
        skippedCases: Int,
        passRate: Double,
        suites: [[String: Any]],
        outputPath: String? = nil
    ) -> String {
        var md = ""
        md += "# 🧪 TTZip Test Execution & Diagnostic Report\n\n"
        md += "> **Generated**: \(startTime) | **Duration**: \(String(format: "%.2f", durationMs)) ms | **Session**: `\(sessionID)`\n\n"
        md += "---\n\n"
        
        // 1. KPI Executive Summary Dashboard
        md += "## 1. Executive Summary\n\n"
        md += "| Metric | Value | Status |\n"
        md += "| :--- | :--- | :--- |\n"
        md += "| **Total Test Suites** | \(totalSuites) | 📦 |\n"
        md += "| **Total Test Cases** | \(totalCases) | 🧪 |\n"
        md += "| **Passed Cases** | \(passedCases) | 🟢 |\n"
        md += "| **Failed Cases** | \(failedCases) | \(failedCases == 0 ? "🟢 0" : "🔴 \(failedCases)") |\n"
        md += "| **Skipped Cases** | \(skippedCases) | ⚪ \(skippedCases) |\n"
        md += "| **Pass Rate** | \(String(format: "%.1f", passRate))% | \(passRate >= 100.0 ? "🏆 100%" : "⚠️") |\n"
        md += "| **Environment** | \(osVersion) (\(arch)) | 💻 |\n\n"
        
        // 2. Test Suite Breakdown
        md += "## 2. Test Suite Breakdown\n\n"
        md += "| Suite Name | Passed | Failed | Skipped | Duration (ms) |\n"
        md += "| :--- | :--- | :--- | :--- | :--- |\n"
        
        for suite in suites {
            let name = suite["suiteName"] as? String ?? "Unknown"
            let p = suite["passedCount"] as? Int ?? 0
            let f = suite["failedCount"] as? Int ?? 0
            let s = suite["skippedCount"] as? Int ?? 0
            let d = suite["durationMs"] as? Double ?? 0.0
            let statusIcon = f == 0 ? "🟢" : "🔴"
            md += "| \(statusIcon) **\(name)** | \(p) | \(f) | \(s) | \(String(format: "%.2f", d)) |\n"
        }
        md += "\n"
        
        if let path = outputPath {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return md
    }
}
