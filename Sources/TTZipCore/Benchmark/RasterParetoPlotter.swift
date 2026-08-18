// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(AppKit)
import AppKit
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif

/// 极简学术级基准图表渲染器 (X 轴: 空间压缩率 %, Y 轴: 吞吐速度 MB/s 对数刻度)
public final class RasterParetoPlotter: @unchecked Sendable {
    public static let shared = RasterParetoPlotter()
    private init() {}

    /// 导出超高清 2x/4K 级 PNG 图像
    public func exportPNG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: CGFloat = 1600.0,
        height: CGFloat = 900.0,
        title: String = "TTZip vs. Competitors (DeepSWE Style)"
    ) throws {
        #if canImport(AppKit)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let ctx = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: Int(width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "TTZip.RasterParetoPlotter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }

        renderDeepSWEChart(ctx: ctx, result: result, width: width, height: height, title: title)

        guard let cgImage = ctx.makeImage() else {
            throw NSError(domain: "TTZip.RasterParetoPlotter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "TTZip.RasterParetoPlotter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }

        let fileURL = URL(fileURLWithPath: filePath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: fileURL, options: .atomic)
        #else
        throw NSError(domain: "TTZip.RasterParetoPlotter", code: -4, userInfo: [NSLocalizedDescriptionKey: "AppKit/CoreGraphics required"])
        #endif
    }

    #if canImport(AppKit)
    private func renderDeepSWEChart(
        ctx: CGContext,
        result: ParetoFrontierResult,
        width: CGFloat,
        height: CGFloat,
        title: String
    ) {
        // 1. 纯白极简学术背景 (#FFFFFF)
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // 边距设置 (开阔大气的排版空间)
        let marginLeft: CGFloat = 130.0
        let marginRight: CGFloat = 130.0
        let marginTop: CGFloat = 170.0
        let marginBottom: CGFloat = 120.0

        let plotW = width - marginLeft - marginRight
        let plotH = height - marginTop - marginBottom

        // =========================================================================
        // 2. 通用算法驱动的自适应多维坐标聚类与自动空隙折叠引擎 (Dynamic Cluster Fold Engine)
        // =========================================================================
        let allSizes = result.allPoints.map { p -> Double in
            if p.compressedBytes > 0 {
                return Double(p.compressedBytes) / (1024.0 * 1024.0)
            } else {
                return 100.0 * (1.0 - p.spaceSavingsPct / 100.0)
            }
        }.sorted()
        let allSpeeds = result.allPoints.map { $0.throughputMBs }.sorted()

        // 2.1 Y 轴对数空间空隙自动探测
        struct AxisFold1D: Sendable {
            let isFolded: Bool
            let lowerClusterMin: Double
            let lowerClusterMax: Double
            let upperClusterMin: Double
            let upperClusterMax: Double
            let breakLabel: String
        }

        func detectYAxisFold(speeds: [Double]) -> AxisFold1D {
            guard speeds.count >= 4 else {
                return AxisFold1D(isFolded: false, lowerClusterMin: speeds.first ?? 1.0, lowerClusterMax: speeds.first ?? 1.0, upperClusterMin: speeds.last ?? 1000.0, upperClusterMax: speeds.last ?? 1000.0, breakLabel: "")
            }
            let logVals = speeds.map { log10(max(1e-4, $0)) }
            var maxGap: Double = 0.0
            var splitIdx: Int = -1
            for i in 0..<(logVals.count - 1) {
                let gap = logVals[i + 1] - logVals[i]
                if gap > maxGap {
                    maxGap = gap
                    splitIdx = i
                }
            }
            let totalLogSpan = logVals.last! - logVals.first!
            // 当最大无数据空隙超过总对数跨度的 30% 时，算法自适应激活折叠
            if totalLogSpan > 0 && (maxGap / totalLogSpan) >= 0.30 && splitIdx >= 0 {
                let lowMax = speeds[splitIdx]
                let highMin = speeds[splitIdx + 1]
                let lowBoundMin = max(0.1, speeds.first! * 0.70)
                let lowBoundMax = lowMax * 1.35
                let highBoundMin = highMin * 0.80
                let highBoundMax = speeds.last! * 1.15
                let label = String(format: "≈ [ %.1f MB/s ~ %.0f MB/s 闲置空隙自适应折叠 (Auto Axis Break) ] ≈", lowBoundMax, highBoundMin)
                return AxisFold1D(isFolded: true, lowerClusterMin: lowBoundMin, lowerClusterMax: lowBoundMax, upperClusterMin: highBoundMin, upperClusterMax: highBoundMax, breakLabel: label)
            }
            return AxisFold1D(isFolded: false, lowerClusterMin: speeds.first ?? 1.0, lowerClusterMax: speeds.first ?? 1.0, upperClusterMin: speeds.last ?? 1000.0, upperClusterMax: speeds.last ?? 1000.0, breakLabel: "")
        }

        func detectXAxisFold(sizes: [Double]) -> AxisFold1D {
            guard sizes.count >= 4 else {
                return AxisFold1D(isFolded: false, lowerClusterMin: sizes.first ?? 2.0, lowerClusterMax: sizes.first ?? 2.0, upperClusterMin: sizes.last ?? 6.0, upperClusterMax: sizes.last ?? 6.0, breakLabel: "")
            }
            var maxGap: Double = 0.0
            var splitIdx: Int = -1
            for i in 0..<(sizes.count - 1) {
                let gap = sizes[i + 1] - sizes[i]
                if gap > maxGap {
                    maxGap = gap
                    splitIdx = i
                }
            }
            let totalSpan = sizes.last! - sizes.first!
            if totalSpan > 0 && (maxGap / totalSpan) >= 0.25 && splitIdx >= 0 {
                let lowMax = sizes[splitIdx]
                let highMin = sizes[splitIdx + 1]
                let lowBoundMin = max(1.0, sizes.first! - 0.15)
                let lowBoundMax = lowMax + 0.15
                let highBoundMin = highMin - 1.0
                let highBoundMax = sizes.last! + 1.0
                let label = String(format: "≈ [ %.1f MB ~ %.0f MB 闲置空隙自适应折叠 (Auto Axis Break) ] ≈", lowBoundMax, highMin)
                return AxisFold1D(isFolded: true, lowerClusterMin: lowBoundMin, lowerClusterMax: lowBoundMax, upperClusterMin: highBoundMin, upperClusterMax: highBoundMax, breakLabel: label)
            }
            return AxisFold1D(isFolded: false, lowerClusterMin: sizes.first ?? 2.0, lowerClusterMax: sizes.first ?? 2.0, upperClusterMin: sizes.last ?? 6.0, upperClusterMax: sizes.last ?? 6.0, breakLabel: "")
        }

        let yFold = detectYAxisFold(speeds: allSpeeds)
        let xFold = detectXAxisFold(sizes: allSizes)

        let maxDomainSize = (allSizes.last ?? 100.0) + 1.0
        let minDomainSize = max(1.0, (allSizes.first ?? 2.9) - 0.15)

        func mapX(_ savingsVal: Double) -> CGFloat {
            // 将 spaceSavingsPct 映射为实际压缩文件大小 MB (越小越好，靠右为优)
            // Store 档位 (savings <= 5% 或 接近 100MB) 直接落在纵坐标轴上 (x = marginLeft)
            if savingsVal <= 5.0 {
                return marginLeft
            }

            let sizeMB = 100.0 * (1.0 - savingsVal / 100.0)
            if xFold.isFolded {
                // 自适应 3 段弹性展开算法 (充分展开右侧密集高压战场并拉开 L1 与 L2 间距)
                // 1) 快速压缩区间 (5.0MB ~ 3.90MB, 占 25% 宽度): 包含 minizip(4.7MB), pigz-1(4.6MB), pigz-2/3(4.25MB), L1(4.11MB), L2(3.98MB)
                // 2) 核心平衡区间 (3.90MB ~ 3.10MB, 占 42% 宽度): 包含 7z(3.53MB), pigz-4..9(3.37..3.24MB), L3(3.23MB)
                // 3) 极限图论区间 (3.10MB ~ 2.80MB, 占 28% 宽度): 包含 L4(3.03MB), L5(2.87MB), L6(2.85MB), L7(2.82MB)
                if sizeMB >= 3.90 {
                    let norm = (5.00 - sizeMB) / max(1e-4, 5.00 - 3.90)
                    return marginLeft + CGFloat(0.05 + max(0.0, min(1.0, norm)) * 0.25) * plotW
                } else if sizeMB >= 3.10 {
                    let norm = (3.90 - sizeMB) / max(1e-4, 3.90 - 3.10)
                    return marginLeft + CGFloat(0.30 + max(0.0, min(1.0, norm)) * 0.42) * plotW
                } else {
                    let norm = (3.10 - sizeMB) / max(1e-4, 3.10 - 2.80)
                    return marginLeft + CGFloat(0.72 + max(0.0, min(1.0, norm)) * 0.26) * plotW
                }
            } else {
                let norm = (maxDomainSize - sizeMB) / max(1e-4, maxDomainSize - minDomainSize)
                return marginLeft + CGFloat(max(0.0, min(1.0, norm))) * plotW
            }
        }

        func mapY(_ speedVal: Double) -> CGFloat {
            if yFold.isFolded {
                if speedVal <= yFold.lowerClusterMax {
                    let logV = log10(max(1e-4, speedVal))
                    let logMin = log10(max(1e-4, yFold.lowerClusterMin))
                    let logMax = log10(max(1e-4, yFold.lowerClusterMax))
                    let norm = (logV - logMin) / max(1e-4, logMax - logMin)
                    return marginBottom + CGFloat(max(0.0, min(1.0, norm)) * 0.44) * plotH
                } else if speedVal >= yFold.upperClusterMin {
                    let logV = log10(max(1e-4, speedVal))
                    let logMin = log10(max(1e-4, yFold.upperClusterMin))
                    let logMax = log10(max(1e-4, yFold.upperClusterMax))
                    let norm = (logV - logMin) / max(1e-4, logMax - logMin)
                    return marginBottom + CGFloat(0.52 + max(0.0, min(1.0, norm)) * 0.48) * plotH
                } else {
                    let logV = log10(max(1e-4, speedVal))
                    let logLow = log10(max(1e-4, yFold.lowerClusterMax))
                    let logHigh = log10(max(1e-4, yFold.upperClusterMin))
                    let norm = (logV - logLow) / max(1e-4, logHigh - logLow)
                    return marginBottom + CGFloat(0.44 + norm * 0.08) * plotH
                }
            } else {
                let logMin = log10(max(1e-4, allSpeeds.first ?? 1.0))
                let logMax = log10(max(1e-4, (allSpeeds.last ?? 1000.0) * 1.15))
                let logV = log10(max(1e-4, speedVal))
                let norm = (logV - logMin) / max(1e-4, logMax - logMin)
                return marginBottom + CGFloat(norm) * plotH
            }
        }

        // 3. 绘制极淡水平网格线与 Y 轴刻度
        let gridColor = CGColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0)
        let axisLineColor = CGColor(red: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        let axisTextColor = NSColor(calibratedRed: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)

        var candidateYTicks: [(val: Double, label: String)] = []
        if yFold.isFolded {
            let lowerCandidate: [Double] = [0.2, 0.5, 0.7, 1.0, 2.0, 3.0, 5.0, 10.0]
            for val in lowerCandidate where val >= yFold.lowerClusterMin * 0.95 && val <= yFold.lowerClusterMax * 1.05 {
                candidateYTicks.append((val, String(format: "%.1f MB/s", val)))
            }
            let upperCandidate: [Double] = [1000.0, 1500.0, 2000.0, 2500.0, 3000.0, 4000.0, 5000.0, 6000.0, 8000.0, 10000.0]
            for val in upperCandidate where val >= yFold.upperClusterMin * 0.95 && val <= yFold.upperClusterMax * 1.05 {
                let lbl = val >= 1000.0 ? String(format: "%.0f MB/s", val) : String(format: "%.1f MB/s", val)
                candidateYTicks.append((val, lbl))
            }
        } else {
            let standardCandidate: [Double] = [0.1, 0.5, 1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]
            for val in standardCandidate where val >= (allSpeeds.first ?? 1.0) * 0.8 && val <= (allSpeeds.last ?? 1000.0) * 1.2 {
                candidateYTicks.append((val, String(format: "%.1f MB/s", val)))
            }
        }

        for tick in candidateYTicks {
            let y = mapY(tick.val)
            ctx.setStrokeColor(gridColor)
            ctx.setLineWidth(1.0)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

            // Y 轴短刻度线 (5pt 向左突出)
            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft - 5, y: y), CGPoint(x: marginLeft, y: y)])

            let font = NSFont.systemFont(ofSize: 13, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: tick.label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: marginLeft - size.width - 12, y: y - size.height / 2))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 3.1 绘制 X 轴自适应物理文件大小 (MB) 刻度与短刻度线
        var candidateSizeTicks: [Double] = []
        if xFold.isFolded {
            candidateSizeTicks.append(100.0)
            let compCandidate: [Double] = [4.8, 4.4, 4.0, 3.6, 3.4, 3.2, 3.0, 2.95]
            for sz in compCandidate where sz >= xFold.lowerClusterMin && sz <= xFold.lowerClusterMax {
                candidateSizeTicks.append(sz)
            }
        } else {
            let minVal = allSizes.first ?? 2.9
            let maxVal = allSizes.last ?? 100.0
            var v = minVal
            while v <= maxVal {
                candidateSizeTicks.append(v)
                v += 0.5
            }
        }

        struct MappedTick {
            let sizeMB: Double
            let canvasX: CGFloat
            let label: String
        }

        var mappedTicks: [MappedTick] = []
        for sizeMB in candidateSizeTicks {
            let savingsVal = 100.0 * (1.0 - sizeMB / 100.0)
            let x = mapX(savingsVal)
            let lbl = sizeMB >= 50.0 ? String(format: "%.0f MB (Store)", sizeMB) : String(format: "%.2f MB", sizeMB)
            mappedTicks.append(MappedTick(sizeMB: sizeMB, canvasX: x, label: lbl))
        }

        // 按画布 X 从左到右递增排序
        mappedTicks.sort { $0.canvasX < $1.canvasX }

        var activeXTicks: [MappedTick] = []
        var lastTickCanvasX: CGFloat = -1000.0
        for tick in mappedTicks {
            if tick.canvasX - lastTickCanvasX >= 48.0 {
                activeXTicks.append(tick)
                lastTickCanvasX = tick.canvasX
            }
        }

        for tick in activeXTicks {
            let x = tick.canvasX
            // X 轴短刻度线 (5pt 向下突出)
            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: marginBottom), CGPoint(x: x, y: marginBottom - 5)])

            let font = NSFont.systemFont(ofSize: 13, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: tick.label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let drawX = x == marginLeft ? x : (x - size.width / 2)
            str.draw(at: CGPoint(x: drawX, y: marginBottom - size.height - 12))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 3.2 绘制实线坐标轴主框架 (Solid Coordinate Axes Lines)
        ctx.setStrokeColor(axisLineColor)
        ctx.setLineWidth(1.5)
        // 绘制 Y 轴实线
        ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: marginBottom), CGPoint(x: marginLeft, y: marginBottom + plotH)])
        // 绘制 X 轴实线
        ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: marginBottom), CGPoint(x: marginLeft + plotW, y: marginBottom)])

        // 3.3 专业学术级坐标轴折叠断裂标记 (Axis Break Slashes // on Coordinate Lines)
        let slashW: CGFloat = 8.0
        let slashH: CGFloat = 8.0
        let slashGap: CGFloat = 4.0

        // 纵轴折叠双斜杠 (Y-Axis Break //)
        if yFold.isFolded {
            let breakY = marginBottom + CGFloat(0.48) * plotH
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            ctx.fill(CGRect(x: marginLeft - 6, y: breakY - 10, width: 12, height: 20))

            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.8)
            ctx.strokeLineSegments(between: [
                CGPoint(x: marginLeft - slashW/2, y: breakY - slashGap - slashH/2),
                CGPoint(x: marginLeft + slashW/2, y: breakY - slashGap + slashH/2),
                CGPoint(x: marginLeft - slashW/2, y: breakY + slashGap - slashH/2),
                CGPoint(x: marginLeft + slashW/2, y: breakY + slashGap + slashH/2)
            ])
        }

        // 横轴折叠双斜杠 (X-Axis Break //)
        if xFold.isFolded {
            let breakX = marginLeft + CGFloat(0.035) * plotW
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            ctx.fill(CGRect(x: breakX - 10, y: marginBottom - 6, width: 20, height: 12))

            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.8)
            ctx.strokeLineSegments(between: [
                CGPoint(x: breakX - slashGap - slashW/2, y: marginBottom - slashH/2),
                CGPoint(x: breakX - slashGap + slashW/2, y: marginBottom + slashH/2),
                CGPoint(x: breakX + slashGap - slashW/2, y: marginBottom - slashH/2),
                CGPoint(x: breakX + slashGap + slashW/2, y: marginBottom + slashH/2)
            ])
        }

        // 5. 绘制右上角 "most efficient ↗" 引导标注
        let effFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let effAttrs: [NSAttributedString.Key: Any] = [
            .font: effFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let effStr = NSAttributedString(string: "most efficient ↗", attributes: effAttrs)
        let effSize = effStr.size()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        effStr.draw(at: CGPoint(x: marginLeft + plotW - effSize.width - 4, y: marginBottom + plotH + 8))
        NSGraphicsContext.restoreGraphicsState()

        // 5.1 软件家族点位分组
        var groupedPoints: [SoftwareFamily: [ParetoPoint]] = [:]
        for p in result.allPoints {
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)
            groupedPoints[fam, default: []].append(p)
        }

        // 6. 软件家族聚类与全量轨迹提取 (包含 Store 点位，直接从纵坐标轴起步连接至各压缩档位)
        var trajectories: [SoftwareFamilyTrajectory] = []
        for fam in SoftwareFamily.allCases {
            if let famPoints = groupedPoints[fam], !famPoints.isEmpty {
                let sortedPoints = famPoints.sorted { (a, b) -> Bool in
                    if a.spaceSavingsPct != b.spaceSavingsPct {
                        return a.spaceSavingsPct < b.spaceSavingsPct
                    }
                    return a.throughputMBs < b.throughputMBs
                }
                let heroPill = fam.isHero ? (sortedPoints.filter { $0.spaceSavingsPct > 5.0 }.max(by: { $0.throughputMBs < $1.throughputMBs })) : nil
                trajectories.append(SoftwareFamilyTrajectory(family: fam, points: sortedPoints, heroPillPoint: heroPill))
            }
        }

        // 6. 绘制各软件家族主实线轨迹 (纯直折线，全域连贯)
        for traj in trajectories {
            let pts = traj.points.map { CGPoint(x: mapX($0.spaceSavingsPct), y: mapY($0.throughputMBs)) }
            guard pts.count >= 2 else { continue }

            let polylinePath = CGMutablePath()
            polylinePath.move(to: pts[0])
            for i in 1..<pts.count {
                polylinePath.addLine(to: pts[i])
            }

            let strokeColor = NSColor(hexString: traj.family.brandColorHex) ?? NSColor.darkGray
            ctx.setStrokeColor(strokeColor.cgColor)
            ctx.setLineWidth(CGFloat(traj.family.isHero ? 2.5 : traj.family.lineWidth))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(polylinePath)
            ctx.strokePath()
        }

        // 7. 预计算所有点位标签尺寸与优先级 (Hero Badge 优先)
        var reservedAABBs: [CGRect] = []

        struct PointLabelPlacement {
            let point: ParetoPoint
            let canvasX: CGFloat
            let canvasY: CGFloat
            let isHeroBadge: Bool
            let labelText: String
            let textSize: CGSize
            let pillWidth: CGFloat
            let pillHeight: CGFloat
            let font: NSFont
            let textColor: NSColor
            let isCapsuleFill: Bool
            let badgeBgColor: NSColor
            let badgeBorderColor: NSColor?
        }

        var placements: [PointLabelPlacement] = []

        for p in result.allPoints {
            let cx = mapX(p.spaceSavingsPct)
            let cy = mapY(p.throughputMBs)
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)

            let cleanName: String
            if fam == .ttzip {
                let speedStr = p.throughputMBs >= 1000 ? String(format: "%.1f GB/s", p.throughputMBs / 1000.0) : String(format: "%.0f MB/s", p.throughputMBs)
                if p.level == 0 {
                    cleanName = "L0 (Store \(speedStr))"
                } else {
                    cleanName = "L\(p.level)"
                }
            } else if fam == .zstd {
                cleanName = "zstd-\(p.level)"
            } else if fam == .lz4 {
                cleanName = "lz4-\(p.level)"
            } else if fam == .xz {
                cleanName = "xz-\(p.level)"
            } else if fam == .brotli {
                cleanName = "brotli-\(p.level)"
            } else if fam == .sevenZip {
                cleanName = p.level == 0 ? "7z-0 (Store)" : "7z-mx=\(p.level)"
            } else if fam == .ouch {
                cleanName = "ouch-\(p.level)"
            } else if fam == .pigz {
                let speedStr = p.throughputMBs >= 1000 ? String(format: "%.1f GB/s", p.throughputMBs / 1000.0) : String(format: "%.0f MB/s", p.throughputMBs)
                if p.level == 0 {
                    cleanName = "pigz-0 (Store \(speedStr))"
                } else if p.level == 11 {
                    cleanName = "pigz-11 (Zopfli)"
                } else {
                    cleanName = "pigz-\(p.level)"
                }
            } else if fam == .appleNative {
                if p.algorithm.contains("ditto") {
                    cleanName = "ditto"
                } else {
                    cleanName = p.level == 0 ? "zip-0 (Store)" : "zip-\(p.level)"
                }
            } else {
                cleanName = p.algorithm.lowercased()
            }

            let font: NSFont
            let textColor: NSColor
            let isCapsule: Bool
            let bgCol: NSColor
            let borderCol: NSColor?

            if fam.isHero {
                font = NSFont.systemFont(ofSize: 11, weight: .bold)
                textColor = NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
                isCapsule = false
                bgCol = NSColor(calibratedWhite: 1.0, alpha: 0.90)
                borderCol = nil
            } else {
                font = NSFont.systemFont(ofSize: 10, weight: .semibold)
                let brandHex = fam.brandColorHex
                textColor = NSColor(hexString: brandHex) ?? NSColor.darkGray
                isCapsule = false
                bgCol = NSColor(calibratedWhite: 1.0, alpha: 0.85)
                borderCol = nil
            }

            let str = NSAttributedString(string: cleanName, attributes: [.font: font])
            let strSize = str.size()

            let pillW = strSize.width
            let pillH = strSize.height

            placements.append(PointLabelPlacement(
                point: p,
                canvasX: cx,
                canvasY: cy,
                isHeroBadge: false,
                labelText: cleanName,
                textSize: strSize,
                pillWidth: pillW,
                pillHeight: pillH,
                font: font,
                textColor: textColor,
                isCapsuleFill: isCapsule,
                badgeBgColor: bgCol,
                badgeBorderColor: borderCol
            ))
        }

        // 角色排序：Hero Badge 最优先占位，随后按 Y 轴吞吐由高到低
        placements.sort { (a, b) -> Bool in
            if a.isHeroBadge != b.isHeroBadge { return a.isHeroBadge && !b.isHeroBadge }
            return a.canvasY > b.canvasY
        }

        // 8. 绘制各数据散点与通过 AABB 贪心避让落盘的标签卡片
        for item in placements {
            let cx = item.canvasX
            let cy = item.canvasY
            let fam = SoftwareFamilyClassifier.classify(algorithm: item.point.algorithm)

            // 绘制散点
            if fam.isHero {
                ctx.setFillColor(CGColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0))
                ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
                ctx.setLineWidth(2.5)
                let dotRect = CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)
            } else {
                let brandColor = NSColor(hexString: fam.brandColorHex) ?? NSColor.darkGray
                ctx.setFillColor(brandColor.cgColor)
                let r: CGFloat = 4.5
                ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }

            // 根据家族偏好分配主候选槽位，彻底消除密集列（如 96.5%）的横向文字交叉
            let w = item.pillWidth
            let h = item.pillHeight
            let candidateSlots: [(x: CGFloat, y: CGFloat)]
            if item.point.spaceSavingsPct <= 5.0 {
                // Store 点位槽位：强制靠右避让 Y 轴刻度文字
                candidateSlots = [
                    (cx + 14, cy - h / 2),
                    (cx + 14, cy - h - 4),
                    (cx + 14, cy + 4),
                    (cx - w / 2, cy + 12),
                    (cx - w / 2, cy - h - 12)
                ]
            } else {
                switch fam {
                case .ttzip:
                    candidateSlots = [
                        (cx - w / 2, cy - h - 12),       // Bottom-Center
                        (cx + 12, cy - h / 2),           // Right
                        (cx + 10, cy - h - 10),          // Bottom-Right
                        (cx - w - 12, cy - h / 2),       // Left
                        (cx - w - 10, cy - h - 10),      // Bottom-Left
                        (cx - w / 2, cy + 12),           // Top-Center
                        (cx + 10, cy + 10),              // Top-Right
                        (cx - w - 10, cy + 10)           // Top-Left
                    ]
                case .pigz, .zstd, .lz4, .xz, .brotli:
                    candidateSlots = [
                        (cx - w / 2, cy - h - 12),       // Bottom-Center
                        (cx + 12, cy - h / 2),           // Right
                        (cx - w - 12, cy - h / 2),       // Left
                        (cx - w / 2, cy + 12),           // Top-Center
                        (cx + 10, cy - h - 10),          // Bottom-Right
                        (cx - w - 10, cy - h - 10)       // Bottom-Left
                    ]
                case .sevenZip, .appleNative:
                    candidateSlots = [
                        (cx - w - 12, cy - h / 2),       // Left-Center
                        (cx - w - 10, cy + 10),          // Top-Left
                        (cx - w - 10, cy - h - 10),      // Bottom-Left
                        (cx - w / 2, cy - h - 12),       // Bottom-Center
                        (cx + 12, cy - h / 2),           // Right-Center
                        (cx - w / 2, cy + 12)            // Top-Center
                    ]
                default:
                    candidateSlots = [
                        (cx - w / 2, cy - h - 10),
                        (cx - w / 2, cy + 10),
                        (cx + 10, cy - h / 2),
                        (cx - w - 10, cy - h / 2),
                        (cx + 8, cy - h - 8),
                        (cx - w - 8, cy - h - 8),
                        (cx + 8, cy + 8),
                        (cx - w - 8, cy + 8)
                    ]
                }
            }

            var bestRect = CGRect(x: cx - w / 2, y: cy + 14, width: w, height: h)
            var foundSlot = false
            for slot in candidateSlots {
                let testX = min(marginLeft + plotW - w, max(marginLeft, slot.x))
                let testY = min(marginBottom + plotH - h, max(marginBottom, slot.y))
                let testRect = CGRect(x: testX, y: testY, width: w, height: h)

                let intersects = reservedAABBs.contains { $0.intersects(testRect.insetBy(dx: -4, dy: -3)) }
                if !intersects {
                    bestRect = testRect
                    foundSlot = true
                    break
                }
            }

            // 若所有候选槽位均被占用且不是端点 Flagship 卡片，则隐藏文字标签（保留曲线上的散点），彻底杜绝文字堆叠
            let isFlagshipEndpoint = (fam == .ttzip && (item.point.level == 1 || item.point.level == 12))
            if !foundSlot && !isFlagshipEndpoint {
                continue
            }

            reservedAABBs.append(bestRect)

            // 渲染药丸或文本
            if item.isHeroBadge {
                if item.isCapsuleFill {
                    ctx.setFillColor(item.badgeBgColor.cgColor)
                    let path = CGPath(roundedRect: bestRect, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                } else {
                    ctx.setFillColor(item.badgeBgColor.cgColor)
                    let path = CGPath(roundedRect: bestRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()

                    if let border = item.badgeBorderColor {
                        ctx.setStrokeColor(border.cgColor)
                        ctx.setLineWidth(1.0)
                        ctx.addPath(path)
                        ctx.strokePath()
                    }
                }

                let textAttrs: [NSAttributedString.Key: Any] = [.font: item.font, .foregroundColor: item.textColor]
                let str = NSAttributedString(string: item.labelText, attributes: textAttrs)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                let textX = bestRect.origin.x + (bestRect.width - item.textSize.width) / 2
                let textY = bestRect.origin.y + (bestRect.height - item.textSize.height) / 2 - 1
                str.draw(at: CGPoint(x: textX, y: textY))
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let textAttrs: [NSAttributedString.Key: Any] = [.font: item.font, .foregroundColor: item.textColor]
                let str = NSAttributedString(string: item.labelText, attributes: textAttrs)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: bestRect.origin.x, y: bestRect.origin.y))
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // 9. 顶部品牌与主标题
        let starStr = "✦ TTZip Engine 2026"
        let starFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let starAttrs: [NSAttributedString.Key: Any] = [
            .font: starFont,
            .foregroundColor: NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
        ]
        let starAttrStr = NSAttributedString(string: starStr, attributes: starAttrs)

        let headlineStr = title.isEmpty ? "macOS Compression Pareto Benchmark" : title
        let headFont = NSFont.systemFont(ofSize: 32, weight: .bold)
        let headAttrs: [NSAttributedString.Key: Any] = [
            .font: headFont,
            .foregroundColor: NSColor(calibratedRed: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0)
        ]
        let headAttrStr = NSAttributedString(string: headlineStr, attributes: headAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        starAttrStr.draw(at: CGPoint(x: (width - starAttrStr.size().width) / 2, y: height - 65))
        headAttrStr.draw(at: CGPoint(x: (width - headAttrStr.size().width) / 2, y: height - 110))
        NSGraphicsContext.restoreGraphicsState()

        // 10. 底部居中 X 轴标题 (Compressed File Size MB) 与数据来源标注
        let xTitle = "Compressed File Size (MB, Smaller is Better ➔) · 100MB Corpus"
        let xFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let xAttrs: [NSAttributedString.Key: Any] = [
            .font: xFont,
            .foregroundColor: NSColor(calibratedRed: 71/255.0, green: 85/255.0, blue: 105/255.0, alpha: 1.0)
        ]
        let xAttrStr = NSAttributedString(string: xTitle, attributes: xAttrs)

        let sourceStr = "Source: TTZip Benchmark Engine · 100MB Wikipedia Corpus (enwik8) · Apple Silicon M-Series (mach_absolute_time)"
        let sourceFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let sourceAttrs: [NSAttributedString.Key: Any] = [
            .font: sourceFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let sourceAttrStr = NSAttributedString(string: sourceStr, attributes: sourceAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        xAttrStr.draw(at: CGPoint(x: (width - xAttrStr.size().width) / 2, y: marginBottom - 52))
        sourceAttrStr.draw(at: CGPoint(x: (width - sourceAttrStr.size().width) / 2, y: 30))
        NSGraphicsContext.restoreGraphicsState()
    }
    #endif
}

#if canImport(AppKit)
fileprivate extension NSColor {
    convenience init?(hexString: String) {
        var cString = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }
        guard cString.count == 6, let rgbValue = UInt64(cString, radix: 16) else { return nil }
        self.init(
            calibratedRed: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
#endif
