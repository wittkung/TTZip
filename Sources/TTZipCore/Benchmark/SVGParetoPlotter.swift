// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 零依赖响应式矢量 SVG 生成器 (X 轴: 空间压缩率 %, Y 轴: 吞吐速度 MB/s 对数刻度)
public final class SVGParetoPlotter: @unchecked Sendable {
    public static let shared = SVGParetoPlotter()
    private init() {}

    /// 生成完整的独立 SVG 字符串
    public func generateSVG(
        result: ParetoFrontierResult,
        width: Double = 1600.0,
        height: Double = 900.0,
        title: String = "macOS Compression Pareto Benchmark"
    ) -> String {
        let marginLeft = 130.0
        let marginRight = 130.0
        let marginTop = 170.0
        let marginBottom = 120.0

        let plotW = max(200.0, width - marginLeft - marginRight)
        let plotH = max(150.0, height - marginTop - marginBottom)

        // 1. 自适应 X 轴（压缩率 %）与 Y 轴（吞吐速度 MB/s 对数）
        let allSavings = result.allPoints.map { $0.spaceSavingsPct }
        let allSpeeds = result.allPoints.map { $0.throughputMBs }

        let minX = allSavings.min() ?? 80.0
        let maxX = allSavings.max() ?? 100.0
        let minY = allSpeeds.min() ?? 10.0
        let maxY = allSpeeds.max() ?? 10000.0

        let spanX = max(0.1, maxX - minX)
        let xStep: Double
        if spanX <= 2.5 {
            xStep = 0.5
        } else if spanX <= 5.0 {
            xStep = 1.0
        } else if spanX <= 8.0 {
            xStep = 2.0
        } else if spanX <= 25.0 {
            xStep = 5.0
        } else if spanX <= 55.0 {
            xStep = 10.0
        } else {
            xStep = 20.0
        }

        let padLeft = max(xStep * 0.6, spanX * 0.12)
        let domainMinX = max(0.0, floor((minX - padLeft) / xStep) * xStep)
        let padRight = max(xStep * 0.6, spanX * 0.12)
        let domainMaxX = min(100.0, ceil((maxX + padRight) / xStep) * xStep)

        let minLogY = max(0.5, floor(log10(max(1.0, minY))))
        let maxLogY = min(5.5, ceil(log10(max(10.0, maxY))) + 0.3)

        func mapX(_ savingsVal: Double) -> Double {
            let clamped = max(domainMinX, min(savingsVal, domainMaxX))
            let norm = (clamped - domainMinX) / max(1e-6, domainMaxX - domainMinX)
            return marginLeft + norm * plotW
        }

        func mapY(_ speedVal: Double) -> Double {
            let clamped = max(pow(10.0, minLogY), min(speedVal, pow(10.0, maxLogY)))
            let logV = log10(clamped)
            let norm = (logV - minLogY) / (maxLogY - minLogY)
            return (height - marginBottom) - norm * plotH
        }

        var svg = String()
        svg.reserveCapacity(32768)

        // 2. SVG 头部与 CSS 样式定义
        svg += """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(width)) \(Int(height))" width="100%" height="100%">
          <defs>
            <style>
              text { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif; }
              .grid-line { stroke: #F1F5F9; stroke-width: 1.2; }
              .axis-text { font-size: 14px; fill: #64748B; }
              .eff-text { font-size: 13px; font-weight: 500; fill: #94A3B8; }
            </style>
          </defs>

          <!-- 极简纯白背景 -->
          <rect width="\(Int(width))" height="\(Int(height))" fill="#FFFFFF"/>

          <!-- 顶部品牌标识与主标题 -->
          <text x="\(Int(width / 2))" y="65" text-anchor="middle" font-size="15" font-weight="600" fill="#2563EB">✦ TTZip Engine 2026</text>
          <text x="\(Int(width / 2))" y="108" text-anchor="middle" font-size="34" font-weight="700" fill="#0F172A">\(title)</text>

          <!-- 右上角 efficiency 提示 -->
          <text x="\(Int(marginLeft + plotW))" y="\(Int(marginTop - 12))" text-anchor="end" class="eff-text">most efficient ↗</text>

        """

        // 3. 水平网格线与 Y 轴速度刻度
        let candidateYTicks: [(val: Double, label: String)] = [
            (10.0, "10 MB/s"),
            (50.0, "50 MB/s"),
            (100.0, "100 MB/s"),
            (500.0, "500 MB/s"),
            (1000.0, "1,000 MB/s"),
            (2000.0, "2,000 MB/s"),
            (5000.0, "5,000 MB/s"),
            (10000.0, "10,000 MB/s")
        ]

        for tick in candidateYTicks {
            let logVal = log10(tick.val)
            if logVal >= minLogY && logVal <= maxLogY {
                let py = mapY(tick.val)
                svg += """
                  <line x1="\(Int(marginLeft))" y1="\(String(format: "%.1f", py))" x2="\(Int(marginLeft + plotW))" y2="\(String(format: "%.1f", py))" class="grid-line"/>
                  <text x="\(Int(marginLeft - 16))" y="\(String(format: "%.1f", py + 4))" text-anchor="end" class="axis-text">\(tick.label)</text>

                """
            }
        }

        // 4. X 轴（空间节省率 %）刻度线与标签
        for xVal in stride(from: domainMinX, through: domainMaxX, by: xStep) {
            let px = mapX(xVal)
            let label = xStep < 1.0 ? String(format: "%.1f%%", xVal) : String(format: "%.0f%%", xVal)
            svg += """
              <text x="\(String(format: "%.1f", px))" y="\(Int(height - marginBottom + 30))" text-anchor="middle" class="axis-text">\(label)</text>

            """
        }

        // 5. 软件家族聚类与 Fritsch-Carlson 样条曲线生成 (按 X 轴压缩率升序排列)
        var groupedPoints: [SoftwareFamily: [ParetoPoint]] = [:]
        for p in result.allPoints {
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)
            groupedPoints[fam, default: []].append(p)
        }

        var trajectories: [SoftwareFamilyTrajectory] = []
        for fam in SoftwareFamily.allCases {
            if var famPoints = groupedPoints[fam], !famPoints.isEmpty {
                famPoints.sort { (a, b) -> Bool in
                    if a.spaceSavingsPct != b.spaceSavingsPct {
                        return a.spaceSavingsPct < b.spaceSavingsPct
                    }
                    return a.throughputMBs < b.throughputMBs
                }
                let heroPill = fam.isHero ? (famPoints.max(by: { $0.throughputMBs < $1.throughputMBs })) : nil
                trajectories.append(SoftwareFamilyTrajectory(family: fam, points: famPoints, heroPillPoint: heroPill))
            }
        }

        // 5.1 绘制 TTZip Hero 半透明演进光晕带 (DeepSWE Ribbon Beam)
        for traj in trajectories where traj.family.isHero {
            let pts = traj.points.map { (x: mapX($0.spaceSavingsPct), y: mapY($0.throughputMBs)) }
            if pts.count >= 2 {
                let segments = FritschCarlsonSplineCalculator.calculateBezierSegments(points: pts)
                var pathStr = "M \(String(format: "%.1f", pts[0].x)) \(String(format: "%.1f", pts[0].y)) "
                for seg in segments {
                    pathStr += "C \(String(format: "%.1f", seg.controlPoint1.x)) \(String(format: "%.1f", seg.controlPoint1.y)), \(String(format: "%.1f", seg.controlPoint2.x)) \(String(format: "%.1f", seg.controlPoint2.y)), \(String(format: "%.1f", seg.endPoint.x)) \(String(format: "%.1f", seg.endPoint.y)) "
                }
                svg += """
                  <path d="\(pathStr)" stroke="rgba(37, 99, 235, 0.16)" stroke-width="\(Int(traj.family.haloRibbonWidth))" stroke-linecap="round" stroke-linejoin="round" fill="none"/>

                """
            }
        }

        // 5.2 绘制各软件家族主轨迹实线 (Solid Family Curves)
        for traj in trajectories {
            let pts = traj.points.map { (x: mapX($0.spaceSavingsPct), y: mapY($0.throughputMBs)) }
            if pts.count >= 2 {
                let segments = FritschCarlsonSplineCalculator.calculateBezierSegments(points: pts)
                var pathStr = "M \(String(format: "%.1f", pts[0].x)) \(String(format: "%.1f", pts[0].y)) "
                for seg in segments {
                    pathStr += "C \(String(format: "%.1f", seg.controlPoint1.x)) \(String(format: "%.1f", seg.controlPoint1.y)), \(String(format: "%.1f", seg.controlPoint2.x)) \(String(format: "%.1f", seg.controlPoint2.y)), \(String(format: "%.1f", seg.endPoint.x)) \(String(format: "%.1f", seg.endPoint.y)) "
                }
                let colorHex = traj.family.brandColorHex
                svg += """
                  <path d="\(pathStr)" stroke="\(colorHex)" stroke-width="\(traj.family.lineWidth)" stroke-linecap="round" stroke-linejoin="round" fill="none"/>

                """
            }
        }

        // 6. 绘制散点与药丸卡片
        for p in result.allPoints {
            let px = mapX(p.spaceSavingsPct)
            let py = mapY(p.throughputMBs)
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)

            let speedStr = p.throughputMBs >= 1000 ? String(format: "%.1f GB/s", p.throughputMBs / 1000.0) : String(format: "%.0f MB/s", p.throughputMBs)
            let cleanName: String
            if fam == .sevenZip {
                cleanName = p.algorithm.replacingOccurrences(of: "7-Zip 26.02 (ZIP ", with: "7-zip-")
                    .replacingOccurrences(of: "7-Zip 26.02 (7Z ", with: "7-zip-")
                    .replacingOccurrences(of: ")", with: "")
                    .lowercased()
            } else if fam == .appleNative {
                cleanName = p.algorithm.replacingOccurrences(of: "Apple Native (zip -", with: "apple-zip-")
                    .replacingOccurrences(of: "Apple Native (", with: "apple-")
                    .replacingOccurrences(of: ")", with: "")
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
            } else if fam == .pigz {
                cleanName = p.algorithm.replacingOccurrences(of: "pigz (ZIP ", with: "pigz-")
                    .replacingOccurrences(of: ")", with: "")
                    .lowercased()
            } else if fam == .ttzip {
                let speedStr = p.throughputMBs >= 1000 ? String(format: "%.1f GB/s", p.throughputMBs / 1000.0) : String(format: "%.0f MB/s", p.throughputMBs)
                let baseAlgo = p.algorithm.replacingOccurrences(of: "TTZip (ZIP ", with: "ttzip-")
                    .replacingOccurrences(of: "TTZip (", with: "ttzip-")
                    .replacingOccurrences(of: ")", with: "")
                    .lowercased()
                cleanName = "\(baseAlgo) (\(speedStr))"
            } else {
                cleanName = p.algorithm.lowercased()
            }

            let isHeroPill = fam.isHero && (p.algorithm.contains("ZIP Fast") || p.algorithm.contains("ZIP Ultra") || p.algorithm.contains("TAR.ZST") || p.algorithm.contains("7Z Fast") || p.algorithm.contains("LZ4"))
            let isHeroNormal = fam.isHero && !isHeroPill

            if isHeroPill {
                let pillW = Double(cleanName.count * 8 + 24)
                let pillH = 26.0
                let pillX = min(marginLeft + plotW - pillW, max(marginLeft, px - pillW / 2))
                let pillY = py - 36.0

                svg += """
                  <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="6" fill="#2563EB" stroke="#FFFFFF" stroke-width="2.5"/>
                  <g transform="translate(\(String(format: "%.1f", pillX)), \(String(format: "%.1f", pillY)))">
                    <rect width="\(Int(pillW))" height="\(Int(pillH))" rx="\(Int(pillH / 2))" fill="#2563EB"/>
                    <text x="\(Int(pillW / 2))" y="17" text-anchor="middle" font-size="12" font-weight="700" fill="#FFFFFF">\(cleanName)</text>
                  </g>

                """
            } else if isHeroNormal {
                let pillW = Double(cleanName.count * 7 + 16)
                let pillH = 22.0
                let pillX = min(marginLeft + plotW - pillW, max(marginLeft, px - pillW / 2))
                let pillY = py - 30.0

                svg += """
                  <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="5" fill="#2563EB" stroke="#FFFFFF" stroke-width="2"/>
                  <g transform="translate(\(String(format: "%.1f", pillX)), \(String(format: "%.1f", pillY)))">
                    <rect width="\(Int(pillW))" height="\(Int(pillH))" rx="6" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
                    <text x="\(Int(pillW / 2))" y="15" text-anchor="middle" font-size="11" font-weight="700" fill="#2563EB">\(cleanName)</text>
                  </g>

                """
            } else {
                let colorHex = fam.brandColorHex
                svg += """
                  <circle cx="\(String(format: "%.1f", px))" cy="\(String(format: "%.1f", py))" r="4.5" fill="\(colorHex)"/>
                  <text x="\(String(format: "%.1f", px))" y="\(String(format: "%.1f", py + 16))" text-anchor="middle" font-size="11" fill="\(colorHex)">\(cleanName)</text>

                """
            }
        }

        // 7. 底部居中 X 轴标题与数据源声明
        svg += """
          <text x="\(Int(width / 2))" y="\(Int(height - marginBottom + 65))" text-anchor="middle" font-size="14" font-weight="500" fill="#475569">Space Savings Ratio (%, Higher is Better)</text>
          <text x="\(Int(width / 2))" y="\(Int(height - 25))" text-anchor="middle" font-size="12" fill="#94A3B8">Source: TTZip Benchmark Engine · 100MB Wikipedia Corpus (enwik8) · Apple Silicon M-Series (mach_absolute_time)</text>
        </svg>
        """

        return svg
    }

    /// 导出 SVG 文件
    public func exportSVG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: Double = 1600.0,
        height: Double = 900.0,
        title: String = "macOS Compression Pareto Benchmark"
    ) throws {
        let svgContent = generateSVG(result: result, width: width, height: height, title: title)
        let fileURL = URL(fileURLWithPath: filePath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
