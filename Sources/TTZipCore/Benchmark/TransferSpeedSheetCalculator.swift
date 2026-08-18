// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 物理传输介质端到端耗时投影计算器 (10G/1G/NVMe/Cloud WAN)
public final class TransferSpeedSheetCalculator: @unchecked Sendable {
    public static let shared = TransferSpeedSheetCalculator()
    private init() {}

    /// 标准物理介质带宽定义 (MB/s)
    public struct MediaSpec: Sendable {
        public let name: String
        public let bandwidthMBs: Double

        public static let defaultSpecs: [MediaSpec] = [
            MediaSpec(name: "Cloud WAN (200Mbps)", bandwidthMBs: 25.0),
            MediaSpec(name: "1Gbps LAN / 5G", bandwidthMBs: 125.0),
            MediaSpec(name: "10Gbps LAN", bandwidthMBs: 1250.0),
            MediaSpec(name: "NVMe SSD (APFS)", bandwidthMBs: 3000.0)
        ]
    }

    /// 对单个算法结果计算多介质传输矩阵
    public func calculateReport(
        for result: AlgorithmBenchmarkResult,
        mediaSpecs: [MediaSpec] = MediaSpec.defaultSpecs
    ) -> TransferSpeedReport {
        let rawBytes = result.uncompressedBytes
        let compBytes = result.compressedBytes
        let rawMB = Double(rawBytes) / 1_000_000.0
        let compMB = Double(compBytes) / 1_000_000.0

        let compSpeed = max(1.0, result.compressionSpeedMBs)
        let decompSpeed = max(1.0, result.decompressionSpeedMBs)

        let tComp = rawMB / compSpeed
        let tDecomp = rawMB / decompSpeed

        var tiers: [TransferSpeedTier] = []

        for spec in mediaSpecs {
            let tTransfer = compMB / spec.bandwidthMBs
            let tTotal = tComp + tTransfer + tDecomp
            let tUncompressed = rawMB / spec.bandwidthMBs
            let speedup = (tTotal > 0) ? (tUncompressed / tTotal) : 1.0

            let tier = TransferSpeedTier(
                tierName: spec.name,
                bandwidthMBs: spec.bandwidthMBs,
                rawTransferSeconds: tUncompressed,
                compressionSeconds: tComp,
                compressedTransferSeconds: tTransfer,
                decompressionSeconds: tDecomp,
                totalTurnaroundSeconds: tTotal,
                speedupRatio: speedup,
                isParetoWinner: false
            )
            tiers.append(tier)
        }

        return TransferSpeedReport(
            sourceSizeBytes: rawBytes,
            algorithm: result.algorithm,
            level: result.level,
            tiers: tiers
        )
    }

    /// 对全矩阵对比并标记各介质的 Pareto Winner
    public func calculateMatrixReports(
        results: [AlgorithmBenchmarkResult],
        mediaSpecs: [MediaSpec] = MediaSpec.defaultSpecs
    ) -> [TransferSpeedReport] {
        var reports = results.map { calculateReport(for: $0, mediaSpecs: mediaSpecs) }
        guard !reports.isEmpty else { return [] }

        // 对每个介质找出耗时最短的 winner
        for tierIdx in 0..<mediaSpecs.count {
            var bestTime = Double.infinity
            var bestReportIdx = 0

            for (rIdx, r) in reports.enumerated() {
                if tierIdx < r.tiers.count {
                    let totalT = r.tiers[tierIdx].totalTurnaroundSeconds
                    if totalT < bestTime {
                        bestTime = totalT
                        bestReportIdx = rIdx
                    }
                }
            }

            if bestReportIdx < reports.count && tierIdx < reports[bestReportIdx].tiers.count {
                var updatedTiers = reports[bestReportIdx].tiers
                updatedTiers[tierIdx].isParetoWinner = true
                reports[bestReportIdx] = TransferSpeedReport(
                    sourceSizeBytes: reports[bestReportIdx].sourceSizeBytes,
                    algorithm: reports[bestReportIdx].algorithm,
                    level: reports[bestReportIdx].level,
                    tiers: updatedTiers,
                    overallBestTierCount: reports[bestReportIdx].overallBestTierCount + 1
                )
            }
        }

        return reports
    }

    /// 格式化为 ASCII 表格输出
    public func formatTable(reports: [TransferSpeedReport], mediaSpecs: [MediaSpec] = MediaSpec.defaultSpecs) -> String {
        var out = ""
        out += "========================================================================================================================\n"
        out += "🌐 真实物理传输介质端到端全链路耗时矩阵 (Turnaround Latency: Comp + Transfer + Decomp)\n"
        out += "========================================================================================================================\n"
        out += "Algorithm        | Lvl|   Cloud WAN (25MB/s) |    1Gbps LAN (125MB/s) |   10Gbps LAN (1250MB/s) |   NVMe SSD (3000MB/s)\n"
        out += "------------------------------------------------------------------------------------------------------------------------\n"

        for r in reports {
            let algoPadded = r.algorithm.padding(toLength: 16, withPad: " ", startingAt: 0)
            var row = String(format: "%@ | %2d |", algoPadded, r.level)
            for tier in r.tiers {
                let winBadge = tier.isParetoWinner ? " 👑" : ""
                let cell = String(format: " %7.3fs (%4.1fx)%@", tier.totalTurnaroundSeconds, tier.speedupRatio, winBadge)
                row += cell.padding(toLength: 23, withPad: " ", startingAt: 0) + "|"
            }
            out += row + "\n"
        }
        out += "========================================================================================================================\n"
        return out
    }
}
