// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 零依赖独立响应式 SVG 矢量图表生成器 (Dark/Light Mode 自适应 + 悬浮 Tooltip + 帕累托包络线)
public final class SVGParetoPlotter: @unchecked Sendable {
    public static let shared = SVGParetoPlotter()
    private init() {}

    /// 生成完整的独立 SVG 字符串
    public func generateSVG(
        result: ParetoFrontierResult,
        width: Double = 960.0,
        height: Double = 600.0,
        title: String = "TTZip Compression Pareto Frontier Analysis"
    ) -> String {
        let marginLeft = 80.0
        let marginRight = 50.0
        let marginTop = 70.0
        let marginBottom = 70.0

        let plotW = max(200.0, width - marginLeft - marginRight)
        let plotH = max(150.0, height - marginTop - marginBottom)

        let minLogX = 1.0 // log10(10 MB/s)
        let maxLogX = 5.0 // log10(100,000 MB/s)

        func mapX(_ val: Double) -> Double {
            let clamped = max(10.0, min(val, 100000.0))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return marginLeft + norm * plotW
        }

        func mapY(_ val: Double) -> Double {
            let clamped = max(0.0, min(val, 100.0))
            let norm = (100.0 - clamped) / 100.0
            return marginTop + norm * plotH
        }

        var svg = String()
        svg.reserveCapacity(16384)

        // 1. SVG 头部声明
        svg += """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(width)) \(Int(height))" width="100%" height="100%">
          <defs>
            <style>
              :root {
                --bg: #ffffff;
                --card-bg: #f8fafc;
                --grid-major: #cbd5e1;
                --grid-minor: #f1f5f9;
                --axis: #475569;
                --text-main: #0f172a;
                --text-muted: #64748b;
                --pareto-line: #d97706;
                --pareto-fill: rgba(217, 119, 6, 0.12);
                --pt-pareto: #f59e0b;
                --pt-regular: #3b82f6;
                --tooltip-bg: rgba(15, 23, 42, 0.95);
                --tooltip-text: #ffffff;
                --tooltip-border: #d97706;
              }
              @media (prefers-color-scheme: dark) {
                :root {
                  --bg: #0f172a;
                  --card-bg: #1e293b;
                  --grid-major: #334155;
                  --grid-minor: #1e293b;
                  --axis: #94a3b8;
                  --text-main: #f8fafc;
                  --text-muted: #94a3b8;
                  --pareto-line: #fbbf24;
                  --pareto-fill: rgba(251, 191, 36, 0.15);
                  --pt-pareto: #fbbf24;
                  --pt-regular: #60a5fa;
                  --tooltip-bg: rgba(30, 41, 59, 0.98);
                  --tooltip-text: #ffffff;
                  --tooltip-border: #fbbf24;
                }
              }
              text { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif; }
              .tooltip-box {
                opacity: 0;
                pointer-events: none;
                transition: opacity 0.15s ease-in-out;
              }
              .point-node:hover .tooltip-box, .point-node:focus .tooltip-box {
                opacity: 1;
              }
              .point-node:hover circle {
                r: 8;
                stroke: var(--text-main);
                stroke-width: 2.5px;
              }
            </style>
            <linearGradient id="paretoGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="var(--pareto-line)" stop-opacity="0.25"/>
              <stop offset="100%" stop-color="var(--pareto-line)" stop-opacity="0.02"/>
            </linearGradient>
          </defs>

          <!-- 背景 -->
          <rect width="100%" height="100%" fill="var(--bg)"/>
          <rect x="\(Int(marginLeft))" y="\(Int(marginTop))" width="\(Int(plotW))" height="\(Int(plotH))" fill="var(--card-bg)" rx="8"/>

        """

        // 2. 标题与元数据
        svg += """
          <text x="\(Int(marginLeft))" y="38" font-size="20" font-weight="700" fill="var(--text-main)">\(title)</text>
          <text x="\(Int(marginLeft))" y="56" font-size="12" fill="var(--text-muted)">Evaluated \(result.totalPointsEvaluated) points · \(result.frontierPoints.count) Pareto-optimal configurations · Apple Silicon M-Series Native</text>

        """

        // 3. Y 轴网格线与刻度 (0% - 100%)
        let ySteps = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
        for yVal in ySteps {
            let py = mapY(yVal)
            svg += "  <line x1=\"\(Int(marginLeft))\" y1=\"\(String(format: "%.1f", py))\" x2=\"\(Int(marginLeft + plotW))\" y2=\"\(String(format: "%.1f", py))\" stroke=\"var(--grid-major)\" stroke-width=\"1\" stroke-dasharray=\"3,3\"/>\n"
            svg += "  <text x=\"\(Int(marginLeft - 12))\" y=\"\(String(format: "%.1f", py + 4))\" text-anchor=\"end\" font-size=\"11\" fill=\"var(--text-muted)\">\(Int(yVal))%</text>\n"
        }

        // 4. X 轴对数网格线 (10^1 to 10^5)
        let decades = [
            (10.0, "10"),
            (100.0, "100"),
            (1000.0, "1K"),
            (10000.0, "10K"),
            (100000.0, "100K")
        ]

        for (dVal, dLabel) in decades {
            let px = mapX(dVal)
            svg += "  <line x1=\"\(String(format: "%.1f", px))\" y1=\"\(Int(marginTop))\" x2=\"\(String(format: "%.1f", px))\" y2=\"\(Int(marginTop + plotH))\" stroke=\"var(--grid-major)\" stroke-width=\"1\" stroke-dasharray=\"3,3\"/>\n"
            svg += "  <text x=\"\(String(format: "%.1f", px))\" y=\"\(Int(marginTop + plotH + 20))\" text-anchor=\"middle\" font-size=\"11\" fill=\"var(--text-muted)\">\(dLabel) MB/s</text>\n"
        }

        // 5. 绘制帕累托包络线与阴影填充
        let frontier = result.frontierPoints
        if frontier.count >= 2 {
            var pathData = "M "
            for (idx, p) in frontier.enumerated() {
                let px = String(format: "%.1f", mapX(p.throughputMBs))
                let py = String(format: "%.1f", mapY(p.spaceSavingsPct))
                pathData += "\(px) \(py) "
                if idx < frontier.count - 1 { pathData += "L " }
            }

            let firstX = String(format: "%.1f", mapX(frontier.first!.throughputMBs))
            let lastX = String(format: "%.1f", mapX(frontier.last!.throughputMBs))
            let bottomY = String(format: "%.1f", marginTop + plotH)
            let fillPath = "\(pathData) L \(lastX) \(bottomY) L \(firstX) \(bottomY) Z"

            svg += "  <path d=\"\(fillPath)\" fill=\"url(#paretoGrad)\"/>\n"
            svg += "  <path d=\"\(pathData)\" stroke=\"var(--pareto-line)\" stroke-width=\"2.5\" stroke-dasharray=\"6,4\" fill=\"none\"/>\n"
        }

        // 6. 绘制所有数据点与 Tooltip
        for p in result.allPoints {
            let px = mapX(p.throughputMBs)
            let py = mapY(p.spaceSavingsPct)
            let isPareto = p.isParetoOptimal
            let circleColor = isPareto ? "var(--pt-pareto)" : "var(--pt-regular)"
            let radius = isPareto ? 6.5 : 4.5
            let strokeW = isPareto ? 2.0 : 1.0

            let tooltipTitle = "\(p.algorithm) L\(p.level)"
            let tooltipMetric = String(format: "%.1f MB/s · %.1f%% 节省", p.throughputMBs, p.spaceSavingsPct)
            let tooltipRank = isPareto ? "👑 帕累托最优 (Rank 1)" : "Rank \(p.paretoRank)"

            svg += """
              <g class="point-node" tabindex="0">
                <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="\(radius)" fill="\(circleColor)" stroke="var(--bg)" stroke-width="\(strokeW)" cursor="pointer"/>
                <title>\(tooltipTitle) - \(tooltipMetric) (\(tooltipRank))</title>
                <g class="tooltip-box" transform="translate(\(String(format: "%.1f", px)), \(String(format: "%.1f", py - 12)))">
                  <rect x="-80" y="-56" width="160" height="50" rx="6" fill="var(--tooltip-bg)" stroke="var(--tooltip-border)" stroke-width="1.2"/>
                  <text x="0" y="-38" text-anchor="middle" font-size="11" font-weight="700" fill="var(--tooltip-text)">\(tooltipTitle)</text>
                  <text x="0" y="-24" text-anchor="middle" font-size="10" fill="var(--tooltip-text)">\(tooltipMetric)</text>
                  <text x="0" y="-12" text-anchor="middle" font-size="9" fill="var(--pareto-line)">\(tooltipRank)</text>
                </g>
              </g>

            """
        }

        // 7. 坐标轴名称与图例
        svg += """
          <text x="\(Int(marginLeft + plotW / 2))" y="\(Int(height - 18))" text-anchor="middle" font-size="12" font-weight="600" fill="var(--text-main)">吞吐速率 Throughput (MB/s, Log10)</text>
          <text x="24" y="\(Int(marginTop + plotH / 2))" text-anchor="middle" font-size="12" font-weight="600" fill="var(--text-main)" transform="rotate(-90, 24, \(Int(marginTop + plotH / 2)))">空间节省率 Space Savings (%)</text>
        </svg>
        """

        return svg
    }

    /// 导出 SVG 文件到指定磁盘路径
    public func exportSVG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: Double = 960.0,
        height: Double = 600.0,
        title: String = "TTZip Compression Pareto Frontier Analysis"
    ) throws {
        let svgContent = generateSVG(result: result, width: width, height: height, title: title)
        let fileURL = URL(fileURLWithPath: filePath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
