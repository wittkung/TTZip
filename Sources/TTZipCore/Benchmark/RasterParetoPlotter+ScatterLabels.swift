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

#if canImport(AppKit)
struct PointLabelPlacement {
    let point: ParetoPoint
    let canvasX: CGFloat
    let canvasY: CGFloat
    let isHeroBadge: Bool
    let labelText: String
    let textSize: CGSize
    let font: NSFont
    let textColor: NSColor
    let cardBgColor: NSColor
    let borderColor: NSColor
}

extension RasterParetoPlotter {

    /// 预计算所有点位标签尺寸与避让
    func buildLabelPlacements(result: ParetoFrontierResult, coords: PlotCoordinateEngine) -> [PointLabelPlacement] {
        var placements: [PointLabelPlacement] = []

        for p in result.allPoints {
            let cx = coords.mapX(sizeMB: PlotCoordinateEngine.getPointMB(p))
            let cy = coords.mapY(p.throughputMBs)
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
            } else if fam == .libdeflate {
                cleanName = "libdeflate L\(p.level)"
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
            let cardBg: NSColor
            let borderCol: NSColor

            if fam.isHero {
                font = NSFont.systemFont(ofSize: 11, weight: .bold)
                textColor = NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
                cardBg = NSColor(calibratedRed: 239/255.0, green: 246/255.0, blue: 255/255.0, alpha: 0.95)
                borderCol = NSColor(calibratedRed: 191/255.0, green: 219/255.0, blue: 254/255.0, alpha: 1.0)
            } else {
                font = NSFont.systemFont(ofSize: 10, weight: .semibold)
                let brandHex = fam.brandColorHex
                textColor = NSColor(hexString: brandHex) ?? NSColor.darkGray
                cardBg = NSColor(calibratedWhite: 1.0, alpha: 0.95)
                borderCol = NSColor(calibratedRed: 226/255.0, green: 232/255.0, blue: 240/255.0, alpha: 1.0)
            }

            let str = NSAttributedString(string: cleanName, attributes: [.font: font])
            let strSize = str.size()

            placements.append(PointLabelPlacement(
                point: p,
                canvasX: cx,
                canvasY: cy,
                isHeroBadge: fam.isHero,
                labelText: cleanName,
                textSize: strSize,
                font: font,
                textColor: textColor,
                cardBgColor: cardBg,
                borderColor: borderCol
            ))
        }

        // 优先占位排序：Hero 优先，随后从高吞吐到低吞吐
        placements.sort { (a, b) -> Bool in
            if a.isHeroBadge != b.isHeroBadge { return a.isHeroBadge && !b.isHeroBadge }
            return a.canvasY > b.canvasY
        }

        return placements
    }

    /// 绘制散点与带背景防重叠卡片的文字标签
    func renderScatterPointsAndLabels(ctx: CGContext, placements: [PointLabelPlacement], coords: PlotCoordinateEngine) {
        var reservedAABBs: [CGRect] = []

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

            let padX: CGFloat = 4.0
            let padY: CGFloat = 2.0
            let cardW = item.textSize.width + padX * 2
            let cardH = item.textSize.height + padY * 2

            let candidateSlots: [(x: CGFloat, y: CGFloat)]
            let isNearLeftEdge = cx < coords.marginLeft + cardW + 20
            let isNearRightEdge = cx > coords.marginLeft + coords.plotW - cardW - 20

            if item.point.spaceSavingsPct <= 5.0 {
                // Store 点位槽位：靠右避让
                candidateSlots = [
                    (cx + 12, cy - cardH / 2),
                    (cx + 12, cy + 4),
                    (cx + 12, cy - cardH - 4)
                ]
            } else if fam == .ttzip {
                // TTZip 槽位优先：右上、右侧、右下、上方；若近右边缘则优先放左侧
                if isNearRightEdge {
                    candidateSlots = [
                        (cx - cardW - 10, cy - cardH / 2),
                        (cx - cardW - 8, cy + 8),
                        (cx - cardW - 8, cy - cardH - 8),
                        (cx - cardW / 2, cy + 12),
                        (cx - cardW / 2, cy - cardH - 12)
                    ]
                } else {
                    candidateSlots = [
                        (cx + 10, cy - cardH / 2),
                        (cx + 10, cy + 8),
                        (cx + 10, cy - cardH - 8),
                        (cx - cardW / 2, cy + 12),
                        (cx - cardW / 2, cy - cardH - 12),
                        (cx - cardW - 10, cy - cardH / 2)
                    ]
                }
            } else {
                // 竞品槽位优先：左侧、左上、左下；若近左边缘则优先放右侧
                if isNearLeftEdge {
                    candidateSlots = [
                        (cx + 12, cy - cardH / 2),
                        (cx + 12, cy + 8),
                        (cx + 12, cy - cardH - 8),
                        (cx - cardW / 2, cy + 12),
                        (cx - cardW / 2, cy - cardH - 12)
                    ]
                } else {
                    candidateSlots = [
                        (cx - cardW - 10, cy - cardH / 2),
                        (cx - cardW - 8, cy + 8),
                        (cx - cardW - 8, cy - cardH - 8),
                        (cx - cardW / 2, cy - cardH - 12),
                        (cx - cardW / 2, cy + 12),
                        (cx + 10, cy - cardH / 2)
                    ]
                }
            }

            var bestRect = CGRect(x: cx + 10, y: cy - cardH / 2, width: cardW, height: cardH)
            var foundSlot = false
            for slot in candidateSlots {
                let testX = min(coords.marginLeft + coords.plotW - cardW - 4, max(coords.marginLeft + 6, slot.x))
                let testY = min(coords.marginBottom + coords.plotH - cardH - 4, max(coords.marginBottom + 4, slot.y))
                let testRect = CGRect(x: testX, y: testY, width: cardW, height: cardH)

                let intersects = reservedAABBs.contains { $0.intersects(testRect.insetBy(dx: -2, dy: -2)) }
                if !intersects {
                    bestRect = testRect
                    foundSlot = true
                    break
                }
            }

            // 关键端点强制显示，非关键拥挤点可隐藏文本标签以保持整洁
            let isFlagshipEndpoint = (fam == .ttzip && (item.point.level == 1 || item.point.level == 12 || item.point.level == 0))
            if !foundSlot && !isFlagshipEndpoint {
                continue
            }

            reservedAABBs.append(bestRect)

            // 绘制防遮挡小卡片背景与浅灰边框
            ctx.setFillColor(item.cardBgColor.cgColor)
            let cardPath = CGPath(roundedRect: bestRect, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil)
            ctx.addPath(cardPath)
            ctx.fillPath()

            ctx.setStrokeColor(item.borderColor.cgColor)
            ctx.setLineWidth(1.0)
            ctx.addPath(cardPath)
            ctx.strokePath()

            // 绘制文字
            let textAttrs: [NSAttributedString.Key: Any] = [.font: item.font, .foregroundColor: item.textColor]
            let str = NSAttributedString(string: item.labelText, attributes: textAttrs)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: bestRect.origin.x + padX, y: bestRect.origin.y + padY - 0.5))
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
#endif
