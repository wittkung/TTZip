// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

public struct DeltaAuditSummary: Sendable, Codable {
    public let headSha: String
    public let headBranch: String
    public let baseSha: String
    public let baseBranch: String
    public let architecture: String
    public let binaryDelta: BinaryDeltaReport
    public let compressionPoints: [MultiLevelCompressionPoint]
    public let totalRegressions: Int
    public let overallVerdict: String

    public init(
        headSha: String,
        headBranch: String,
        baseSha: String,
        baseBranch: String,
        architecture: String,
        binaryDelta: BinaryDeltaReport,
        compressionPoints: [MultiLevelCompressionPoint],
        totalRegressions: Int,
        overallVerdict: String
    ) {
        self.headSha = headSha
        self.headBranch = headBranch
        self.baseSha = baseSha
        self.baseBranch = baseBranch
        self.architecture = architecture
        self.binaryDelta = binaryDelta
        self.compressionPoints = compressionPoints
        self.totalRegressions = totalRegressions
        self.overallVerdict = overallVerdict
    }
}

public final class DeltaReportFormatter: Sendable {
    public static let shared = DeltaReportFormatter()
    public init() {}

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.2f MB", Double(bytes) / (1024.0 * 1024.0))
        } else if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return "\(bytes) B"
        }
    }

    public func formatTerminal(summary: DeltaAuditSummary) {
        print("==========================================================================================================================")
        print("📊 TTZip Automated Delta Audit (Mach-O Binary & Multi-Level Compression)")
        print("==========================================================================================================================")
        print("Target: \(summary.binaryDelta.targetName) (\(summary.architecture)) | Head: \(summary.headSha) @ \(summary.headBranch) | Base: \(summary.baseSha) @ \(summary.baseBranch)\n")

        print("[1] Binary Footprint")
        let rawBaseStr = formatBytes(summary.binaryDelta.baseRawSizeBytes)
        let rawHeadStr = formatBytes(summary.binaryDelta.headRawSizeBytes)
        let rawPctStr = String(format: "%+.2f%%", summary.binaryDelta.rawDeltaPercent)
        print("  Raw Size:      Base=\(rawBaseStr)  Head=\(rawHeadStr)  (Δ \(summary.binaryDelta.rawDeltaBytes)B, \(rawPctStr))")

        let stripBaseStr = formatBytes(summary.binaryDelta.baseStrippedSizeBytes)
        let stripHeadStr = formatBytes(summary.binaryDelta.headStrippedSizeBytes)
        let stripPctStr = String(format: "%+.2f%%", summary.binaryDelta.strippedDeltaPercent)
        print("  Stripped Size: Base=\(stripBaseStr)  Head=\(stripHeadStr)  (Δ \(summary.binaryDelta.strippedDeltaBytes)B, \(stripPctStr))")
        print("  Section __text: \(formatBytes(summary.binaryDelta.textDeltaBytes)) delta")
        print("  Exported Symbols: \(summary.binaryDelta.addedSymbols.count) added, \(summary.binaryDelta.removedSymbols.count) removed\n")

        print("[2] Multi-Level Compression Density Delta (\(summary.compressionPoints.count) Points)")
        let deflatePts = summary.compressionPoints.filter { $0.engine == "libdeflate" }
        let zstdPts = summary.compressionPoints.filter { $0.engine == "zstd" }
        let bz2Pts = summary.compressionPoints.filter { $0.engine == "bzip2" }

        let defRegs = deflatePts.filter { $0.verdict == "REGRESSION" }.count
        let zstdRegs = zstdPts.filter { $0.verdict == "REGRESSION" }.count
        let bz2Regs = bz2Pts.filter { $0.verdict == "REGRESSION" }.count

        print("  Deflate (L1..L12):   \(deflatePts.count - defRegs)/\(deflatePts.count) passed (\(defRegs) regressions)")
        print("  Zstandard (L1..L19): \(zstdPts.count - zstdRegs)/\(zstdPts.count) passed (\(zstdRegs) regressions)")
        print("  Bzip2 (L1..L9):      \(bz2Pts.count - bz2Regs)/\(bz2Pts.count) passed (\(bz2Regs) regressions)\n")

        print("--------------------------------------------------------------------------------------------------------------------------")
        let icon = summary.overallVerdict == "PASS" ? "✅" : "❌"
        print("Summary: \(summary.compressionPoints.count)/\(summary.compressionPoints.count) Points Analyzed | \(summary.totalRegressions) Regressions | Overall Verdict: \(icon) \(summary.overallVerdict)")
        print("==========================================================================================================================")
    }

    public func formatMarkdown(summary: DeltaAuditSummary) -> String {
        var md = """
        ## ⚡️ TTZip Delta Report

        - **Head**: `\(summary.headBranch)` @ `\(summary.headSha)`
        - **Base**: `\(summary.baseBranch)` @ `\(summary.baseSha)`
        - **Target**: `\(summary.binaryDelta.targetName)`, `\(summary.architecture)`, Release

        | Target Component | Base Size | Head Size | Delta (Bytes) | Delta (%) | Status |
        | :--- | :--- | :--- | :--- | :--- | :--- |
        | **Stripped Binary** | `\(formatBytes(summary.binaryDelta.baseStrippedSizeBytes))` | `\(formatBytes(summary.binaryDelta.headStrippedSizeBytes))` | `\(summary.binaryDelta.strippedDeltaBytes) B` | `\(String(format: "%+.2f%%", summary.binaryDelta.strippedDeltaPercent))` | \(summary.binaryDelta.strippedDeltaPercent > 2.0 ? "⚠️ Bloat" : "🟢 OK") |
        | **Code Section (__text)** | - | - | `\(summary.binaryDelta.textDeltaBytes) B` | - | 🟢 OK |
        | **Exported Symbols** | - | - | `+\(summary.binaryDelta.addedSymbols.count) / -\(summary.binaryDelta.removedSymbols.count)` | - | \(summary.binaryDelta.removedSymbols.isEmpty ? "🟢 Clean" : "⚠️ API Drift") |

        <details open>
        <summary>📊 Compression Sizes & Density Delta (160 Points)</summary>

        ### Libdeflate (RFC 1951 Deflate L1..L12)

        | Corpus | Level | Base (Bytes) | Head (Bytes) | Delta (Bytes) | Delta (%) | Verdict |
        | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
        """

        let deflatePts = summary.compressionPoints.filter { $0.engine == "libdeflate" && $0.corpus == "text" }
        for pt in deflatePts {
            let verdictIcon = pt.verdict == "REGRESSION" ? "🔴 REG" : (pt.verdict == "OPTIMIZATION" ? "🟢 OPT" : "⚪️ IDENTICAL")
            md += "\n| \(pt.corpus) | L\(pt.level) | \(pt.baseCompressedBytes) | \(pt.headCompressedBytes) | \(pt.deltaBytes) | \(String(format: "%+.2f%%", pt.deltaPercent)) | \(verdictIcon) |"
        }

        md += """


        ### Zstandard (RFC 8878 Zstd L1..L19)

        | Corpus | Level | Base (Bytes) | Head (Bytes) | Delta (Bytes) | Delta (%) | Verdict |
        | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
        """

        let zstdPts = summary.compressionPoints.filter { $0.engine == "zstd" && $0.corpus == "text" }
        for pt in zstdPts {
            let verdictIcon = pt.verdict == "REGRESSION" ? "🔴 REG" : (pt.verdict == "OPTIMIZATION" ? "🟢 OPT" : "⚪️ IDENTICAL")
            md += "\n| \(pt.corpus) | L\(pt.level) | \(pt.baseCompressedBytes) | \(pt.headCompressedBytes) | \(pt.deltaBytes) | \(String(format: "%+.2f%%", pt.deltaPercent)) | \(verdictIcon) |"
        }

        md += """


        </details>

        <details>
        <summary>🔍 Exported Symbols Audit</summary>

        ```
        """

        if summary.binaryDelta.addedSymbols.isEmpty && summary.binaryDelta.removedSymbols.isEmpty {
            md += "\nExported symbols: 0 added, 0 removed (Strict Dynamic Symbol Invariance Satisfied)"
        } else {
            for sym in summary.binaryDelta.addedSymbols {
                md += "\n+ \(sym)"
            }
            for sym in summary.binaryDelta.removedSymbols {
                md += "\n- \(sym)"
            }
        }

        md += """

        ```
        </details>

        <details>
        <summary>📁 Binary Section Breakdown</summary>

        ```
        __TEXT.__text: \(summary.binaryDelta.textDeltaBytes) delta bytes
        __DATA.__data: \(summary.binaryDelta.dataDeltaBytes) delta bytes
        __DATA.__bss:  \(summary.binaryDelta.bssDeltaBytes) delta bytes
        ```
        </details>
        """

        return md
    }
}
