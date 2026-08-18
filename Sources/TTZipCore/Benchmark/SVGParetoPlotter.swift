// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 零依赖响应式 SVG 矢量图表生成器 (自适应动态 Y 轴聚焦域 + 侧边栏排行榜看板 + 悬浮 Tooltip)
public final class SVGParetoPlotter: @unchecked Sendable {
    public static let shared = SVGParetoPlotter()
    private init() {}

    /// 生成完整的独立 SVG 字符串
    public func generateSVG(
        result: ParetoFrontierResult,
        width: Double = 1440.0,
        height: Double = 900.0,
        title: String = "TTZip Compression Pareto Frontier Analysis"
    ) -> String {
        let sidebarWidth = 380.0
        let marginLeft = 110.0
        let marginRight = sidebarWidth + 50.0
        let marginTop = 130.0
        let marginBottom = 100.0

        let plotW = max(200.0, width - marginLeft - marginRight)
        let plotH = max(150.0, height - marginTop - marginBottom)

        // 1. 自适应 Y 轴与 X 轴聚焦域
        let allSavings = result.allPoints.map { $0.spaceSavingsPct }
        let allSpeeds = result.allPoints.map { $0.throughputMBs }

        let rawMinY = allSavings.min() ?? 0.0
        let rawMaxY = allSavings.max() ?? 100.0
        let rawMinX = allSpeeds.min() ?? 10.0
        let rawMaxX = allSpeeds.max() ?? 100000.0

        let rangeY = max(5.0, rawMaxY - rawMinY)
        let domainMinY = max(0.0, floor(rawMinY - rangeY * 0.4))
        let domainMaxY = min(100.0, ceil(rawMaxY + rangeY * 0.25))

        let minLogX = max(0.5, floor(log10(max(1.0, rawMinX)) * 2.0) / 2.0 - 0.2)
        let maxLogX = min(6.0, ceil(log10(max(10.0, rawMaxX)) * 2.0) / 2.0 + 0.2)

        func mapX(_ val: Double) -> Double {
            let clamped = max(pow(10.0, minLogX), min(val, pow(10.0, maxLogX)))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return marginLeft + norm * plotW
        }

        func mapY(_ val: Double) -> Double {
            let clamped = max(domainMinY, min(val, domainMaxY))
            let norm = (clamped - domainMinY) / (domainMaxY - domainMinY)
            return (height - marginBottom) - norm * plotH
        }

        var svg = String()
        svg.reserveCapacity(32768)

        // 2. SVG 头部与 CSS 样式声明
        svg += """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(width)) \(Int(height))" width="100%" height="100%">
          <defs>
            <style>
              :root {
                --bg: #0A0F1D;
                --card-bg: rgba(17, 24, 39, 0.75);
                --sidebar-bg: rgba(17, 24, 39, 0.85);
                --card-border: #1F2937;
                --grid-line: rgba(31, 41, 55, 0.8);
                --text-main: #F9FAFB;
                --text-muted: #9CA3AF;
                --text-secondary: #D1D5DB;
                --pareto-line: #F59E0B;
                --pareto-fill: rgba(245, 158, 11, 0.12);
                --pt-pareto: #F59E0B;
                --pt-regular: #60A5FA;
                --tooltip-bg: rgba(31, 41, 55, 0.98);
                --tooltip-border: #F59E0B;
              }
              text { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif; }
              .point-node:hover circle { r: 9; stroke-width: 3px; }
            </style>
            <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="#0A0F1D"/>
              <stop offset="100%" stop-color="#030712"/>
            </linearGradient>
            <linearGradient id="paretoFillGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="rgba(245, 158, 11, 0.25)"/>
              <stop offset="100%" stop-color="rgba(245, 158, 11, 0.0)"/>
            </linearGradient>
          </defs>

          <!-- 全局背景 -->
          <rect width="\(Int(width))" height="\(Int(height))" fill="url(#bgGrad)"/>

          <!-- 顶部标题 -->
          <text x="\(Int(marginLeft))" y="58" font-size="26" font-weight="700" fill="var(--text-main)">\(title)</text>
          <text x="\(Int(marginLeft))" y="86" font-size="14" font-weight="400" fill="var(--text-muted)">Apple Silicon Native In-Memory Engine · Calibrated Nanosecond Resolution Timer</text>

          <!-- 左侧图表主卡片 -->
          <rect x="\(Int(marginLeft))" y="\(Int(marginTop))" width="\(Int(plotW))" height="\(Int(plotH))" rx="8" fill="var(--card-bg)" stroke="var(--card-border)" stroke-width="1.5"/>

        """

        // 3. Y 轴水平网格线与自适应刻度
        let yStep = max(1.0, (domainMaxY - domainMinY) / 5.0)
        for yVal in stride(from: domainMinY, through: domainMaxY, by: yStep) {
            let py = mapY(yVal)
            svg += """
              <line x1="\(Int(marginLeft))" y1="\(String(format: "%.1f", py))" x2="\(Int(marginLeft + plotW))" y2="\(String(format: "%.1f", py))" stroke="var(--grid-line)" stroke-width="1" stroke-dasharray="4,4"/>
              <text x="\(Int(marginLeft - 12))" y="\(String(format: "%.1f", py + 4))" text-anchor="end" font-size="13" font-family="monospace" fill="var(--text-muted)">\(String(format: "%.1f%%", yVal))</text>

            """
        }

        // 4. X 轴垂直对数刻度线
        let candidateTicks: [(val: Double, label: String)] = [
            (50.0, "50 MB/s"),
            (100.0, "100 MB/s"),
            (500.0, "500 MB/s"),
            (1000.0, "1,000 MB/s"),
            (2000.0, "2,000 MB/s"),
            (5000.0, "5,000 MB/s"),
            (10000.0, "10,000 MB/s"),
            (50000.0, "50,000 MB/s")
        ]

        for tick in candidateTicks {
            let logVal = log10(tick.val)
            if logVal >= minLogX && logVal <= maxLogX {
                let px = mapX(tick.val)
                svg += """
                  <line x1="\(String(format: "%.1f", px))" y1="\(Int(marginTop))" x2="\(String(format: "%.1f", px))" y2="\(Int(marginTop + plotH))" stroke="var(--grid-line)" stroke-width="1" stroke-dasharray="4,4"/>
                  <text x="\(String(format: "%.1f", px))" y="\(Int(marginTop + plotH + 24))" text-anchor="middle" font-size="13" font-family="monospace" fill="var(--text-muted)">\(tick.label)</text>

                """
            }
        }

        // 5. 绘制帕累托包络线与填充区
        let frontier = result.frontierPoints.sorted(by: { $0.throughputMBs < $1.throughputMBs })
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

            svg += """
              <path d="\(fillPath)" fill="url(#paretoFillGrad)"/>
              <path d="\(pathData)" stroke="var(--pareto-line)" stroke-width="3.5" stroke-dasharray="6,4" fill="none"/>

            """
        }

        // 6. 绘制数据点与智能避让标签
        for (idx, p) in result.allPoints.enumerated() {
            let px = mapX(p.throughputMBs)
            let py = mapY(p.spaceSavingsPct)
            let isPareto = p.isParetoOptimal

            if isPareto {
                let isTopStagger = (idx % 2 == 0)
                let pillY = isTopStagger ? (py - 30) : (py + 14)
                let pillText = "👑 \(p.algorithm) L\(p.level): \(String(format: "%.0f MB/s", p.throughputMBs))"

                svg += """
                  <g class="point-node">
                    <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="12" fill="rgba(245, 158, 11, 0.3)"/>
                    <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="7" fill="var(--pt-pareto)" stroke="#ffffff" stroke-width="2"/>
                    <g transform="translate(\(String(format: "%.1f", px)), \(String(format: "%.1f", pillY)))">
                      <rect x="-85" y="-12" width="170" height="24" rx="4" fill="var(--tooltip-bg)" stroke="var(--tooltip-border)" stroke-width="1"/>
                      <text x="0" y="4" text-anchor="middle" font-size="11" font-weight="700" fill="#FEF08A">\(pillText)</text>
                    </g>
                  </g>

                """
            } else {
                svg += """
                  <g class="point-node">
                    <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="5" fill="var(--pt-regular)" stroke="var(--card-bg)" stroke-width="1.5"/>
                  </g>

                """
            }
        }

        // 7. 右侧独立数据排行榜看板
        let sidebarX = width - sidebarWidth - 25.0
        svg += """
          <!-- 右侧独立数据看板 -->
          <rect x="\(Int(sidebarX))" y="\(Int(marginTop))" width="\(Int(sidebarWidth))" height="\(Int(plotH))" rx="8" fill="var(--sidebar-bg)" stroke="var(--card-border)" stroke-width="1.5"/>
          <text x="\(Int(sidebarX + 18))" y="\(Int(marginTop + 32))" font-size="16" font-weight="700" fill="var(--text-main)">📊 算法性能全量排名看板</text>

        """

        let sortedPoints = result.allPoints.sorted { (a, b) -> Bool in
            if a.isParetoOptimal != b.isParetoOptimal { return a.isParetoOptimal && !b.isParetoOptimal }
            return a.throughputMBs > b.throughputMBs
        }

        var itemY = marginTop + 68.0
        for (rankIdx, p) in sortedPoints.enumerated() {
            if itemY > marginTop + plotH - 30.0 { break }

            let isPareto = p.isParetoOptimal
            let badge = isPareto ? "👑 前沿最优" : "⚪ 被支配"
            let badgeColor = isPareto ? "#F59E0B" : "#6B7280"
            let titleColor = isPareto ? "#FEF08A" : "#E5E7EB"

            let rowHeader = "\(rankIdx + 1). \(p.algorithm) L\(p.level)"
            let rowMetrics = "\(String(format: "%.1f MB/s", p.throughputMBs)) · \(String(format: "%.1f%%", p.spaceSavingsPct))"

            svg += """
              <g transform="translate(\(Int(sidebarX + 18)), \(String(format: "%.1f", itemY)))">
                <text x="0" y="0" font-size="13" font-weight="\(isPareto ? "700" : "500")" fill="\(titleColor)">\(rowHeader)</text>
                <text x="\(Int(sidebarWidth - 36))" y="0" text-anchor="end" font-size="11" font-weight="600" fill="\(badgeColor)">\(badge)</text>
                <text x="0" y="18" font-size="12" font-family="monospace" fill="var(--text-muted)">\(rowMetrics)</text>
              </g>

            """
            itemY += 46.0
        }

        // 8. 坐标轴标签
        svg += """
          <text x="\(Int(marginLeft + plotW / 2))" y="\(Int(height - marginBottom + 48))" text-anchor="middle" font-size="13" font-weight="600" fill="var(--text-secondary)">压缩吞吐速度 Throughput (MB/s, 对数尺度)</text>
          <text x="\(Int(marginLeft))" y="\(Int(marginTop - 12))" font-size="13" font-weight="600" fill="var(--text-secondary)">空间节省率 Space Savings (%)</text>
        </svg>
        """

        return svg
    }

    /// 导出 SVG 文件
    public func exportSVG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: Double = 1440.0,
        height: Double = 900.0,
        title: String = "TTZip Compression Pareto Frontier Analysis"
    ) throws {
        let svgContent = generateSVG(result: result, width: width, height: height, title: title)
        let fileURL = URL(fileURLWithPath: filePath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
