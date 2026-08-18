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

        // 2. 自适应 X 轴（对数压缩比扩展 Log Compression Ratio Scale）与 Y 轴（吞吐速度 MB/s 对数）
        let allSavings = result.allPoints.map { $0.spaceSavingsPct }
        let allSpeeds = result.allPoints.map { $0.throughputMBs }

        let minX = allSavings.min() ?? 80.0
        let maxX = allSavings.max() ?? 99.0
        let minY = allSpeeds.min() ?? 10.0
        let maxY = allSpeeds.max() ?? 10000.0

        // 核心数学映射：将空间节省率 S 转换为压缩比对数 log10(100 / (100 - S))
        // 当 S 逼近 100% 时，该函数自动将高压缩比右侧区域横向展开 3x~5x，彻底消除右侧拥挤挤压！
        func logRatio(_ savings: Double) -> Double {
            let clamped = max(0.0, min(savings, 99.999))
            let ratio = 100.0 / max(0.001, 100.0 - clamped)
            return log10(ratio)
        }

        let minLogX = logRatio(minX)
        let maxLogX = logRatio(maxX)
        let spanLogX = max(0.01, maxLogX - minLogX)

        let domainMinLogX = max(0.0, minLogX - spanLogX * 0.08)
        let domainMaxLogX = maxLogX + spanLogX * 0.08

        let minLogY = log10(max(1.0, minY * 0.70))
        let maxLogY = log10(max(10.0, maxY * 1.25))

        func mapX(_ savingsVal: Double) -> CGFloat {
            let valLogX = logRatio(savingsVal)
            let norm = (valLogX - domainMinLogX) / max(1e-6, domainMaxLogX - domainMinLogX)
            return marginLeft + CGFloat(norm) * plotW
        }

        func mapY(_ speedVal: Double) -> CGFloat {
            let clamped = max(pow(10.0, minLogY), min(speedVal, pow(10.0, maxLogY)))
            let logV = log10(clamped)
            let norm = (logV - minLogY) / (maxLogY - minLogY)
            return marginBottom + CGFloat(norm) * plotH
        }

        // 3. 绘制极淡水平网格线 (Y 轴对数速度刻度，紧致动态范围)
        let gridColor = CGColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0)
        let axisTextColor = NSColor(calibratedRed: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)

        let candidateYTicks: [(val: Double, label: String)] = [
            (10.0, "10 MB/s"),
            (50.0, "50 MB/s"),
            (100.0, "100 MB/s"),
            (200.0, "200 MB/s"),
            (500.0, "500 MB/s"),
            (1000.0, "1,000 MB/s"),
            (2000.0, "2,000 MB/s"),
            (5000.0, "5,000 MB/s"),
            (10000.0, "10 GB/s"),
            (20000.0, "20 GB/s"),
            (30000.0, "30 GB/s"),
            (50000.0, "50 GB/s"),
            (75000.0, "75 GB/s"),
            (100000.0, "100 GB/s"),
            (150000.0, "150 GB/s"),
            (200000.0, "200 GB/s")
        ]

        for tick in candidateYTicks {
            let logVal = log10(tick.val)
            if logVal >= minLogY && logVal <= maxLogY {
                let y = mapY(tick.val)
                ctx.setStrokeColor(gridColor)
                ctx.setLineWidth(1.2)
                ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

                let font = NSFont.systemFont(ofSize: 14, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
                let str = NSAttributedString(string: tick.label, attributes: attrs)
                let size = str.size()

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: marginLeft - size.width - 16, y: y - size.height / 2))
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // 4. 绘制 X 轴（对数空间节省率 %）刻度与标签
        let candidateXTicks: [Double] = [
            0.0, 20.0, 40.0, 60.0, 70.0, 80.0, 85.0, 90.0, 92.0, 94.0, 95.0,
            95.5, 96.0, 96.2, 96.4, 96.5, 96.6, 96.7, 96.8, 97.0, 97.2, 97.5,
            98.0, 98.5, 99.0, 99.5, 99.8, 99.9
        ]

        var activeXTicks: [Double] = []
        var lastTickCanvasX: CGFloat = -1000.0
        for tickVal in candidateXTicks {
            let tickLog = logRatio(tickVal)
            if tickLog >= domainMinLogX && tickLog <= domainMaxLogX {
                let x = mapX(tickVal)
                if x - lastTickCanvasX >= 75.0 {
                    activeXTicks.append(tickVal)
                    lastTickCanvasX = x
                }
            }
        }

        for xVal in activeXTicks {
            let x = mapX(xVal)
            let label: String
            if xVal >= 95.0 {
                label = String(format: "%.1f%%", xVal)
            } else if xVal == floor(xVal) {
                label = String(format: "%.0f%%", xVal)
            } else {
                label = String(format: "%.1f%%", xVal)
            }
            let font = NSFont.systemFont(ofSize: 14, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: x - size.width / 2, y: marginBottom - size.height - 12))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 5. 绘制右上角 "most efficient ↗" 引导标注
        let effFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let effAttrs: [NSAttributedString.Key: Any] = [
            .font: effFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let effStr = NSAttributedString(string: "most efficient ↗", attributes: effAttrs)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        effStr.draw(at: CGPoint(x: marginLeft + plotW - effStr.size().width, y: marginBottom + plotH + 12))
        NSGraphicsContext.restoreGraphicsState()

        // 6. 软件家族聚类与 Fritsch-Carlson 样条曲线绘制 (按 X 轴压缩率升序排列)
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

        // 6.1 绘制 TTZip Hero 半透明演进光晕带 (DeepSWE Ribbon Beam - 纯直折线)
        for traj in trajectories where traj.family.isHero {
            let pts = traj.points.map { CGPoint(x: mapX($0.spaceSavingsPct), y: mapY($0.throughputMBs)) }
            if pts.count >= 2 {
                let ribbonPath = CGMutablePath()
                ribbonPath.move(to: pts[0])
                for i in 1..<pts.count {
                    ribbonPath.addLine(to: pts[i])
                }
                ctx.setStrokeColor(CGColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 0.16))
                ctx.setLineWidth(CGFloat(traj.family.haloRibbonWidth))
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.addPath(ribbonPath)
                ctx.strokePath()
            }
        }

        // 6.2 绘制各软件家族主实线轨迹 (纯直折线，真实透明)
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
            ctx.setLineWidth(CGFloat(traj.family.lineWidth))
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

            let isFlagshipEndpoint = (fam == .ttzip && (p.level == 1 || p.level == 12)) || (p.algorithm == "TTZip (ZIP Fast)" || p.algorithm == "TTZip (ZIP Ultra)")
            let isHeroPill = isFlagshipEndpoint
            let isHeroNormal = fam.isHero && !isHeroPill

            let cleanName: String
            if fam == .ttzip {
                let speedStr = p.throughputMBs >= 1000 ? String(format: "%.1f GB/s", p.throughputMBs / 1000.0) : String(format: "%.0f MB/s", p.throughputMBs)
                if p.level == 1 {
                    cleanName = "ttzip-l1 (\(speedStr))"
                } else if p.level == 12 {
                    cleanName = "ttzip-l12 (\(speedStr))"
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
                cleanName = "mx=\(p.level)"
            } else if fam == .pigz {
                cleanName = "pigz-\(p.level)"
            } else if fam == .appleNative {
                if p.algorithm.contains("ditto") {
                    cleanName = "ditto"
                } else {
                    cleanName = "zip-\(p.level)"
                }
            } else {
                cleanName = p.algorithm.lowercased()
            }

            let font: NSFont
            let textColor: NSColor
            let isCapsule: Bool
            let bgCol: NSColor
            let borderCol: NSColor?

            if isHeroPill {
                font = NSFont.systemFont(ofSize: 12, weight: .bold)
                textColor = NSColor.white
                isCapsule = true
                bgCol = NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
                borderCol = nil
            } else if isHeroNormal {
                font = NSFont.systemFont(ofSize: 10, weight: .bold)
                textColor = NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
                isCapsule = true
                bgCol = NSColor(calibratedRed: 239/255.0, green: 246/255.0, blue: 255/255.0, alpha: 0.95)
                borderCol = NSColor(calibratedRed: 191/255.0, green: 219/255.0, blue: 254/255.0, alpha: 1.0)
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

            let padX: CGFloat = isHeroPill ? 12.0 : (isHeroNormal ? 8.0 : 0.0)
            let padY: CGFloat = isHeroPill ? 5.0 : (isHeroNormal ? 3.0 : 0.0)
            let pillW = strSize.width + padX * 2
            let pillH = strSize.height + padY * 2

            placements.append(PointLabelPlacement(
                point: p,
                canvasX: cx,
                canvasY: cy,
                isHeroBadge: isHeroPill || isHeroNormal,
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

        // 10. 底部居中 X 轴标题 (Space Savings %) 与数据来源标注
        let xTitle = "Space Savings Ratio (%, Higher is Better)"
        let xFont = NSFont.systemFont(ofSize: 14, weight: .medium)
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
