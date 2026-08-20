import TTZipCore
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

        // 边距设置 (预留充足的标签与坐标轴排版空间)
        let marginLeft: CGFloat = 130.0
        let marginRight: CGFloat = 120.0
        let marginTop: CGFloat = 160.0
        let marginBottom: CGFloat = 120.0

        let plotW = width - marginLeft - marginRight
        let plotH = height - marginTop - marginBottom

        // =========================================================================
        // 2. 通用算法驱动的自适应多维坐标引擎 (Adaptive Universal Coordinate Engine)
        // =========================================================================
        func getPointMB(_ p: ParetoPoint) -> Double {
            if p.compressedBytes > 0 {
                return Double(p.compressedBytes) / (1024.0 * 1024.0)
            } else {
                return 100.0 * (1.0 - p.spaceSavingsPct / 100.0)
            }
        }

        let allSizes = result.allPoints.map { getPointMB($0) }.sorted()
        let allSpeeds = result.allPoints.map { $0.throughputMBs }.sorted()

        let rawMinSize = allSizes.first ?? 2.8
        let rawMaxSize = allSizes.last ?? 4.2

        // 严格检测未压缩 Store 孤立端点 (例如压缩档位全部在 <= 20MB，而 Store 在 >= 50MB)
        let storeSizes = allSizes.filter { $0 >= 50.0 }
        let compSizes = allSizes.filter { $0 < 50.0 }
        let hasIsolatedStore = !storeSizes.isEmpty && !compSizes.isEmpty && (compSizes.last ?? 0) <= 30.0

        let activeSizes = hasIsolatedStore ? compSizes : allSizes
        let compMin = activeSizes.first ?? rawMinSize
        let compMax = activeSizes.last ?? rawMaxSize

        let compSpan = max(1e-4, compMax - compMin)
        let xMargin = max(0.005, compSpan * 0.08)
        let xDomainMin = max(0.0001, compMin - xMargin)
        let xDomainMax = compMax + xMargin

        func mapX(sizeMB: Double) -> CGFloat {
            if hasIsolatedStore {
                if sizeMB >= 50.0 {
                    return marginLeft + 0.04 * plotW
                }
                let norm = (xDomainMax - sizeMB) / max(1e-4, xDomainMax - xDomainMin)
                return marginLeft + (CGFloat(0.12) + CGFloat(max(0.0, min(1.0, norm))) * 0.86) * plotW
            } else {
                let norm = (xDomainMax - sizeMB) / max(1e-4, xDomainMax - xDomainMin)
                return marginLeft + CGFloat(max(0.0, min(1.0, norm))) * plotW
            }
        }

        // Y 轴通用对数坐标映射
        let rawMinSpeed = max(0.1, allSpeeds.first ?? 0.3)
        let rawMaxSpeed = max(10.0, allSpeeds.last ?? 1000.0)

        let logMin = floor(log10(rawMinSpeed * 0.75))
        let logMax = ceil(log10(rawMaxSpeed * 1.25))
        let logSpan = max(1.0, logMax - logMin)

        func mapY(_ speedVal: Double) -> CGFloat {
            let v = max(pow(10.0, logMin), speedVal)
            let logV = log10(v)
            let norm = (logV - logMin) / logSpan
            return marginBottom + CGFloat(max(0.0, min(1.0, norm))) * plotH
        }

        // 3. 绘制极淡水平网格线与 Y 轴刻度
        let gridColor = CGColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0)
        let axisLineColor = CGColor(red: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        let axisTextColor = NSColor(calibratedRed: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)

        let standardYTicks: [(val: Double, label: String)] = [
            (0.1, "0.1 MB/s"),
            (0.2, "0.2 MB/s"),
            (0.5, "0.5 MB/s"),
            (1.0, "1.0 MB/s"),
            (2.0, "2.0 MB/s"),
            (5.0, "5.0 MB/s"),
            (10.0, "10 MB/s"),
            (20.0, "20 MB/s"),
            (50.0, "50 MB/s"),
            (100.0, "100 MB/s"),
            (200.0, "200 MB/s"),
            (500.0, "500 MB/s"),
            (1000.0, "1.0 GB/s"),
            (2000.0, "2.0 GB/s"),
            (5000.0, "5.0 GB/s"),
            (10000.0, "10.0 GB/s"),
            (20000.0, "20.0 GB/s"),
            (50000.0, "50.0 GB/s")
        ]

        var activeYTicks: [(val: Double, label: String, canvasY: CGFloat)] = []
        var lastY: CGFloat = -1000.0
        for tick in standardYTicks {
            if tick.val >= pow(10.0, logMin) * 0.95 && tick.val <= pow(10.0, logMax) * 1.05 {
                let y = mapY(tick.val)
                if y - lastY >= 24.0 {
                    activeYTicks.append((tick.val, tick.label, y))
                    lastY = y
                }
            }
        }

        for tick in activeYTicks {
            let y = tick.canvasY
            ctx.setStrokeColor(gridColor)
            ctx.setLineWidth(1.0)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

            // Y 轴短刻度线 (5pt 向左突出)
            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft - 5, y: y), CGPoint(x: marginLeft, y: y)])

            let font = NSFont.systemFont(ofSize: 12, weight: .regular)
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
        if hasIsolatedStore {
            candidateSizeTicks.append(100.0)
        }

        let niceStep: Double
        if compSpan <= 0.08 {
            niceStep = 0.01
        } else if compSpan <= 0.20 {
            niceStep = 0.02
        } else if compSpan <= 0.50 {
            niceStep = 0.05
        } else if compSpan <= 1.2 {
            niceStep = 0.1
        } else if compSpan <= 2.5 {
            niceStep = 0.2
        } else if compSpan <= 6.0 {
            niceStep = 0.5
        } else if compSpan <= 15.0 {
            niceStep = 1.0
        } else if compSpan <= 30.0 {
            niceStep = 2.0
        } else {
            niceStep = 5.0
        }

        var tickVal = ceil(xDomainMin / niceStep) * niceStep
        while tickVal <= xDomainMax + (niceStep * 0.001) {
            if tickVal >= xDomainMin && tickVal <= xDomainMax {
                candidateSizeTicks.append(tickVal)
            }
            tickVal += niceStep
        }

        struct MappedTick {
            let sizeMB: Double
            let canvasX: CGFloat
            let label: String
        }

        var mappedTicks: [MappedTick] = []
        for sizeMB in candidateSizeTicks {
            let x = mapX(sizeMB: sizeMB)
            let lbl: String
            if sizeMB >= 50.0 && hasIsolatedStore {
                lbl = String(format: "%.0f MB (Store)", sizeMB)
            } else if niceStep < 0.02 {
                lbl = String(format: "%.2f MB", sizeMB)
            } else if niceStep < 0.2 {
                lbl = String(format: "%.2f MB", sizeMB)
            } else if niceStep < 2.0 {
                lbl = String(format: "%.1f MB", sizeMB)
            } else {
                lbl = String(format: "%.0f MB", sizeMB)
            }
            mappedTicks.append(MappedTick(sizeMB: sizeMB, canvasX: x, label: lbl))
        }

        mappedTicks.sort { $0.canvasX < $1.canvasX }

        var activeXTicks: [MappedTick] = []
        var lastTickCanvasX: CGFloat = -1000.0
        for tick in mappedTicks {
            if tick.canvasX - lastTickCanvasX >= 52.0 {
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

            let font = NSFont.systemFont(ofSize: 12, weight: .regular)
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

        // 3.3 若存在 Store 孤立点，绘制 X 轴折叠断裂标记
        if hasIsolatedStore {
            let slashW: CGFloat = 8.0
            let slashH: CGFloat = 8.0
            let slashGap: CGFloat = 4.0
            let breakX = marginLeft + CGFloat(0.08) * plotW
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

        // 6. 软件家族聚类与全量轨迹提取 (按 level 由小到大连接，构成自然算法演进轨迹)
        var trajectories: [SoftwareFamilyTrajectory] = []
        for fam in SoftwareFamily.allCases {
            if let famPoints = groupedPoints[fam], !famPoints.isEmpty {
                let sortedPoints = famPoints.sorted { $0.level < $1.level }
                let heroPill = fam.isHero ? (sortedPoints.filter { getPointMB($0) < 50.0 }.max(by: { $0.throughputMBs < $1.throughputMBs })) : nil
                trajectories.append(SoftwareFamilyTrajectory(family: fam, points: sortedPoints, heroPillPoint: heroPill))
            }
        }

        // 6. 绘制各软件家族主实线轨迹
        for traj in trajectories {
            let pts = traj.points.map { CGPoint(x: mapX(sizeMB: getPointMB($0)), y: mapY($0.throughputMBs)) }
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

        // 6.1 绘制右上角学术图例 (Academic Legend Box)
        let activeFamilies = trajectories.map { $0.family }
        if activeFamilies.count >= 2 {
            let legendFont = NSFont.systemFont(ofSize: 11, weight: .medium)
            var legendEntries: [(name: String, color: NSColor)] = []
            for fam in activeFamilies {
                let col = NSColor(hexString: fam.brandColorHex) ?? NSColor.darkGray
                let name: String
                switch fam {
                case .ttzip: name = "TTZip (ARM64 Native Engine)"
                case .libdeflate: name = "libdeflate (libdeflate-1.22)"
                case .sevenZip: name = "7-Zip (LZMA / Deflate)"
                case .appleNative: name = "Apple Native (ditto / zip)"
                case .minizipNg: name = "minizip-ng"
                case .pigz: name = "pigz (Parallel Gzip)"
                case .zstd: name = "zstd"
                case .lz4: name = "lz4"
                case .xz: name = "xz"
                case .brotli: name = "brotli"
                default: name = fam.rawValue
                }
                legendEntries.append((name, col))
            }

            let entryH: CGFloat = 18.0
            let legendPad: CGFloat = 10.0
            var maxTextW: CGFloat = 0.0
            for entry in legendEntries {
                let str = NSAttributedString(string: entry.name, attributes: [.font: legendFont])
                maxTextW = max(maxTextW, str.size().width)
            }

            let legendW = maxTextW + 36.0 + legendPad * 2
            let legendH = CGFloat(legendEntries.count) * entryH + legendPad * 2
            let legendX = marginLeft + plotW - legendW
            let legendY = marginBottom + plotH - legendH - 6.0

            let legendRect = CGRect(x: legendX, y: legendY, width: legendW, height: legendH)
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92))
            let legPath = CGPath(roundedRect: legendRect, cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
            ctx.addPath(legPath)
            ctx.fillPath()

            ctx.setStrokeColor(CGColor(red: 226/255.0, green: 232/255.0, blue: 240/255.0, alpha: 1.0))
            ctx.setLineWidth(1.0)
            ctx.addPath(legPath)
            ctx.strokePath()

            for (idx, entry) in legendEntries.enumerated() {
                let curY = legendY + legendH - legendPad - CGFloat(idx + 1) * entryH + 3.0
                let lineY = curY + 6.0
                ctx.setStrokeColor(entry.color.cgColor)
                ctx.setLineWidth(2.0)
                ctx.strokeLineSegments(between: [
                    CGPoint(x: legendX + legendPad, y: lineY),
                    CGPoint(x: legendX + legendPad + 18, y: lineY)
                ])

                ctx.setFillColor(entry.color.cgColor)
                ctx.fillEllipse(in: CGRect(x: legendX + legendPad + 6, y: lineY - 3, width: 6, height: 6))

                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: legendFont,
                    .foregroundColor: NSColor(calibratedRed: 51/255.0, green: 65/255.0, blue: 85/255.0, alpha: 1.0)
                ]
                let str = NSAttributedString(string: entry.name, attributes: textAttrs)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: legendX + legendPad + 24, y: curY))
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // 7. 预计算所有点位标签尺寸与避让
        var reservedAABBs: [CGRect] = []

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

        var placements: [PointLabelPlacement] = []

        for p in result.allPoints {
            let cx = mapX(sizeMB: getPointMB(p))
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

        // 8. 绘制散点与带背景防重叠卡片的文字标签
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
            let isNearLeftEdge = cx < marginLeft + cardW + 20
            let isNearRightEdge = cx > marginLeft + plotW - cardW - 20

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
                let testX = min(marginLeft + plotW - cardW - 4, max(marginLeft + 6, slot.x))
                let testY = min(marginBottom + plotH - cardH - 4, max(marginBottom + 4, slot.y))
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

        // 9. 顶部品牌与自适应无裁切主标题
        let starStr = "✦ TTZip Engine 2026"
        let starFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let starAttrs: [NSAttributedString.Key: Any] = [
            .font: starFont,
            .foregroundColor: NSColor(calibratedRed: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)
        ]
        let starAttrStr = NSAttributedString(string: starStr, attributes: starAttrs)

        let headlineStr = title.isEmpty ? "macOS Compression Pareto Benchmark" : title
        var titleFontSize: CGFloat = 26.0
        var headFont = NSFont.systemFont(ofSize: titleFontSize, weight: .bold)
        var headAttrs: [NSAttributedString.Key: Any] = [
            .font: headFont,
            .foregroundColor: NSColor(calibratedRed: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0)
        ]
        var headAttrStr = NSAttributedString(string: headlineStr, attributes: headAttrs)

        // 动态收缩字体直至标题宽度适应画布且两侧至少保留 50pt 边距
        while headAttrStr.size().width > width - 100.0 && titleFontSize > 14.0 {
            titleFontSize -= 1.0
            headFont = NSFont.systemFont(ofSize: titleFontSize, weight: .bold)
            headAttrs[.font] = headFont
            headAttrStr = NSAttributedString(string: headlineStr, attributes: headAttrs)
        }

        let titleX = max(40.0, (width - headAttrStr.size().width) / 2)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        starAttrStr.draw(at: CGPoint(x: (width - starAttrStr.size().width) / 2, y: height - 55))
        headAttrStr.draw(at: CGPoint(x: titleX, y: height - 95))
        NSGraphicsContext.restoreGraphicsState()

        // 10. 底部居中 X 轴标题 (Compressed File Size MB) 与数据来源标注
        let xTitle = "Compressed File Size (MB, Smaller is Better ➔) · 100MB Corpus"
        let xFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let xAttrs: [NSAttributedString.Key: Any] = [
            .font: xFont,
            .foregroundColor: NSColor(calibratedRed: 71/255.0, green: 85/255.0, blue: 105/255.0, alpha: 1.0)
        ]
        let xAttrStr = NSAttributedString(string: xTitle, attributes: xAttrs)

        let sourceStr = title.contains("[") ? "Source: TTZip Benchmark Engine · \(title) · Apple Silicon M-Series (mach_absolute_time)" : "Source: TTZip Benchmark Engine · 100MB Corpus · Apple Silicon M-Series (mach_absolute_time)"
        let sourceFont = NSFont.systemFont(ofSize: 11, weight: .regular)
        let sourceAttrs: [NSAttributedString.Key: Any] = [
            .font: sourceFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let sourceAttrStr = NSAttributedString(string: sourceStr, attributes: sourceAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        xAttrStr.draw(at: CGPoint(x: (width - xAttrStr.size().width) / 2, y: marginBottom - 48))
        sourceAttrStr.draw(at: CGPoint(x: (width - sourceAttrStr.size().width) / 2, y: 26))
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
