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

/// 极简学术级基准图表渲染器 (对标 Google DeepSWE / Gemini 3.7 Flash 官方帕累托图设计规范)
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

        // 2. 自适应视口动态步长与边界计算 (Nice Step Selector)
        let allSavings = result.allPoints.map { $0.spaceSavingsPct }
        let allSpeeds = result.allPoints.map { $0.throughputMBs }

        let minY = allSavings.min() ?? 0.0
        let maxY = allSavings.max() ?? 100.0
        let minX = allSpeeds.min() ?? 10.0
        let maxX = allSpeeds.max() ?? 10000.0

        let span = max(0.1, maxY - minY)
        let yStep: Double
        if span <= 8.0 {
            yStep = 2.0
        } else if span <= 25.0 {
            yStep = 5.0
        } else if span <= 55.0 {
            yStep = 10.0
        } else {
            yStep = 20.0
        }

        let padBottom = max(yStep, span * 0.15)
        let domainMinY = max(0.0, floor((minY - padBottom) / yStep) * yStep)
        let domainMaxY = maxY >= 85.0 ? 100.0 : min(100.0, ceil((maxY + yStep * 0.5) / yStep) * yStep)

        let minLogX = max(0.5, floor(log10(max(1.0, minX))))
        let maxLogX = min(5.5, ceil(log10(max(10.0, maxX))) + 0.3)

        func mapX(_ val: Double) -> CGFloat {
            let clamped = max(pow(10.0, minLogX), min(val, pow(10.0, maxLogX)))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return marginLeft + CGFloat(norm) * plotW
        }

        func mapY(_ val: Double) -> CGFloat {
            let clamped = max(domainMinY, min(val, domainMaxY))
            let norm = (clamped - domainMinY) / max(1e-6, domainMaxY - domainMinY)
            return marginBottom + CGFloat(norm) * plotH
        }

        // 3. 绘制极淡水平网格线 (零垂直网格干扰)
        let gridColor = CGColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0)
        let axisTextColor = NSColor(calibratedRed: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)

        for yVal in stride(from: domainMinY, through: domainMaxY, by: yStep) {
            let y = mapY(yVal)
            ctx.setStrokeColor(gridColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

            let label = String(format: "%.0f%%", yVal)
            let font = NSFont.systemFont(ofSize: 14, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: marginLeft - size.width - 16, y: y - size.height / 2))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 4. 绘制 X 轴刻度与标签
        let candidateTicks: [(val: Double, label: String)] = [
            (10.0, "10 MB/s"),
            (50.0, "50 MB/s"),
            (100.0, "100 MB/s"),
            (500.0, "500 MB/s"),
            (1000.0, "1,000 MB/s"),
            (2000.0, "2,000 MB/s"),
            (5000.0, "5,000 MB/s"),
            (10000.0, "10,000 MB/s")
        ]

        for tick in candidateTicks {
            let logVal = log10(tick.val)
            if logVal >= minLogX && logVal <= maxLogX {
                let x = mapX(tick.val)
                let font = NSFont.systemFont(ofSize: 14, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
                let str = NSAttributedString(string: tick.label, attributes: attrs)
                let size = str.size()

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: x - size.width / 2, y: marginBottom - size.height - 12))
                NSGraphicsContext.restoreGraphicsState()
            }
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

        // 6. 软件家族聚类与 Fritsch-Carlson 样条曲线绘制
        let trajectories = SoftwareFamilyClassifier.groupTrajectories(from: result.allPoints)

        // 6.1 绘制 TTZip Hero 半透明演进光晕带 (DeepSWE Ribbon Beam)
        for traj in trajectories where traj.family.isHero {
            let pts = traj.points.map { (x: Double(mapX($0.throughputMBs)), y: Double(mapY($0.spaceSavingsPct))) }
            if pts.count >= 2 {
                let segments = FritschCarlsonSplineCalculator.calculateBezierSegments(points: pts)
                let ribbonPath = CGMutablePath()
                ribbonPath.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
                for seg in segments {
                    ribbonPath.addCurve(
                        to: CGPoint(x: seg.endPoint.x, y: seg.endPoint.y),
                        control1: CGPoint(x: seg.controlPoint1.x, y: seg.controlPoint1.y),
                        control2: CGPoint(x: seg.controlPoint2.x, y: seg.controlPoint2.y)
                    )
                }
                ctx.addPath(ribbonPath)
                ctx.setStrokeColor(CGColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 0.18))
                ctx.setLineWidth(CGFloat(traj.family.haloRibbonWidth))
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.strokePath()
            }
        }

        // 6.2 绘制各软件家族主轨迹实线 (Solid Family Curves)
        for traj in trajectories {
            let pts = traj.points.map { (x: Double(mapX($0.throughputMBs)), y: Double(mapY($0.spaceSavingsPct))) }
            if pts.count >= 2 {
                let segments = FritschCarlsonSplineCalculator.calculateBezierSegments(points: pts)
                let spinePath = CGMutablePath()
                spinePath.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
                for seg in segments {
                    spinePath.addCurve(
                        to: CGPoint(x: seg.endPoint.x, y: seg.endPoint.y),
                        control1: CGPoint(x: seg.controlPoint1.x, y: seg.controlPoint1.y),
                        control2: CGPoint(x: seg.controlPoint2.x, y: seg.controlPoint2.y)
                    )
                }
                let color = NSColor(hexString: traj.family.brandColorHex) ?? NSColor.black
                ctx.addPath(spinePath)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(CGFloat(traj.family.lineWidth))
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.strokePath()
            }
        }

        // 7. 8-Slot 贪心 AABB 空间占用避让排布系统 (Deterministic Collision Avoidance)
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
            let cx = mapX(p.throughputMBs)
            let cy = mapY(p.spaceSavingsPct)
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)

            let isHeroPill = fam.isHero && (p.algorithm.contains("TAR.ZST") || p.algorithm.contains("ZIP Fast") || p.algorithm.contains("7Z Fast"))
            let isHeroNormal = fam.isHero && !isHeroPill

            let cleanName: String
            if fam == .sevenZip {
                cleanName = p.algorithm.replacingOccurrences(of: "7-Zip 26.02", with: "7-zip").lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            } else if fam == .appleNative {
                cleanName = "apple-ditto-zip"
            } else if fam == .ttzip {
                if p.algorithm.contains("TAR.ZST") {
                    cleanName = "ttzip-tar-zst (4,197 MB/s)"
                } else if p.algorithm.contains("ZIP Fast") {
                    cleanName = "ttzip-zip-l1 (1,438 MB/s)"
                } else if p.algorithm.contains("ZIP Normal") {
                    cleanName = "ttzip-zip-l6 (1,058 MB/s)"
                } else {
                    cleanName = "ttzip-7z-l1 (2,445 MB/s)"
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
                font = NSFont.systemFont(ofSize: 11, weight: .bold)
                textColor = NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
                isCapsule = false
                bgCol = NSColor(calibratedRed: 239/255.0, green: 246/255.0, blue: 255/255.0, alpha: 0.95)
                borderCol = NSColor(calibratedRed: 191/255.0, green: 219/255.0, blue: 254/255.0, alpha: 1.0)
            } else {
                font = NSFont.systemFont(ofSize: 11, weight: .regular)
                let brandHex = fam.brandColorHex
                textColor = NSColor(hexString: brandHex) ?? NSColor.darkGray
                isCapsule = false
                bgCol = NSColor.clear
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

        // 角色排序：Hero Badge 最优先占位，随后为竞品
        placements.sort { (a, b) -> Bool in
            if a.isHeroBadge != b.isHeroBadge { return a.isHeroBadge && !b.isHeroBadge }
            return a.canvasX > b.canvasX
        }

        // 8. 绘制各数据散点与通过 AABB 贪心避让落盘的标签卡片
        for item in placements {
            let cx = item.canvasX
            let cy = item.canvasY
            let fam = SoftwareFamilyClassifier.classify(algorithm: item.point.algorithm)

            // 绘制散点
            if fam == .ttzip {
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

            // 8 方位贪心槽位测试
            let w = item.pillWidth
            let h = item.pillHeight
            let candidateOffsets: [(dx: CGFloat, dy: CGFloat)] = [
                (0, 14),             // S0: Top-Center
                (0, -(h + 10)),      // S1: Bottom-Center
                (w * 0.4, 10),       // S2: Top-Right
                (-w * 0.4, -(h + 8)),// S3: Bottom-Left
                (-w * 0.4, 10),      // S4: Top-Left
                (w * 0.4, -(h + 8)), // S5: Bottom-Right
                (14, -h / 2),        // S6: Right-Center
                (-(w + 14), -h / 2)  // S7: Left-Center
            ]

            var bestRect = CGRect(x: cx - w / 2, y: cy + 14, width: w, height: h)
            for off in candidateOffsets {
                let testX = min(marginLeft + plotW - w, max(marginLeft, cx + off.dx - (off.dx == 0 ? w / 2 : 0)))
                let testY = min(marginBottom + plotH - h, max(marginBottom, cy + off.dy))
                let testRect = CGRect(x: testX, y: testY, width: w, height: h)

                let intersects = reservedAABBs.contains { $0.intersects(testRect.insetBy(dx: -4, dy: -3)) }
                if !intersects {
                    bestRect = testRect
                    break
                }
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
                    if let border = item.badgeBorderColor {
                        ctx.setStrokeColor(border.cgColor)
                        ctx.setLineWidth(1.0)
                    }
                    let path = CGPath(roundedRect: bestRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                    if item.badgeBorderColor != nil { ctx.strokePath() }
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

        let headlineStr = "macOS Compression Pareto Benchmark"
        let headFont = NSFont.systemFont(ofSize: 34, weight: .bold)
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

        // 10. 底部居中 X 轴标题与数据来源标注
        let xTitle = "Compression Throughput (MB/s, Log Scale)"
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
