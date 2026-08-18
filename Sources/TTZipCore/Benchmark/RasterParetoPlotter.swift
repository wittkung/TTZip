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

/// 顶级专业高分辨率帕累托前沿图表生成器 (自适应数据域缩放 + 右侧独立排行榜看板 + 智能标签避让)
public final class RasterParetoPlotter: @unchecked Sendable {
    public static let shared = RasterParetoPlotter()
    private init() {}

    /// 生成超高清 2x/4K 级 PNG 图像
    public func exportPNG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: CGFloat = 1440.0,
        height: CGFloat = 900.0,
        title: String = "TTZip Compression Pareto Frontier Analysis"
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

        renderChart(ctx: ctx, result: result, width: width, height: height, title: title)

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
    private func renderChart(
        ctx: CGContext,
        result: ParetoFrontierResult,
        width: CGFloat,
        height: CGFloat,
        title: String
    ) {
        // 1. 背景绘制 (Deep Slate #0A0F1D -> #030712 渐变)
        let bgGradientColors = [
            CGColor(red: 10/255.0, green: 15/255.0, blue: 29/255.0, alpha: 1.0),
            CGColor(red: 3/255.0, green: 7/255.0, blue: 18/255.0, alpha: 1.0)
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: colorSpace, colors: bgGradientColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        }

        // 2. 布局分区：左侧图表区 (Plot Area) + 右侧数据看板 (Leaderboard Sidebar)
        let sidebarWidth: CGFloat = 380.0
        let marginLeft: CGFloat = 110.0
        let marginRight: CGFloat = sidebarWidth + 50.0
        let marginTop: CGFloat = 130.0
        let marginBottom: CGFloat = 100.0

        let plotW = width - marginLeft - marginRight
        let plotH = height - marginTop - marginBottom

        // 3. 计算自适应 Y 轴与 X 轴数据域 (Adaptive Focus Domain)
        let allSavings = result.allPoints.map { $0.spaceSavingsPct }
        let allSpeeds = result.allPoints.map { $0.throughputMBs }

        let rawMinY = allSavings.min() ?? 0.0
        let rawMaxY = allSavings.max() ?? 100.0
        let rawMinX = allSpeeds.min() ?? 10.0
        let rawMaxX = allSpeeds.max() ?? 100000.0

        // 动态扩展 Y 轴范围（解决点全部挤在上部 3% 的问题）
        let rangeY = max(5.0, rawMaxY - rawMinY)
        let domainMinY = max(0.0, floor(rawMinY - rangeY * 0.4))
        let domainMaxY = min(100.0, ceil(rawMaxY + rangeY * 0.25))

        let minLogX = max(0.5, floor(log10(max(1.0, rawMinX)) * 2.0) / 2.0 - 0.2)
        let maxLogX = min(6.0, ceil(log10(max(10.0, rawMaxX)) * 2.0) / 2.0 + 0.2)

        func mapX(_ val: Double) -> CGFloat {
            let clamped = max(pow(10.0, minLogX), min(val, pow(10.0, maxLogX)))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return marginLeft + CGFloat(norm) * plotW
        }

        func mapY(_ val: Double) -> CGFloat {
            let clamped = max(domainMinY, min(val, domainMaxY))
            let norm = (clamped - domainMinY) / (domainMaxY - domainMinY)
            return marginBottom + CGFloat(norm) * plotH
        }

        // 4. 绘制左侧主图表卡片面板 (#111827)
        let cardRect = CGRect(x: marginLeft, y: marginBottom, width: plotW, height: plotH)
        ctx.setFillColor(CGColor(red: 17/255.0, green: 24/255.0, blue: 39/255.0, alpha: 0.75))
        ctx.setStrokeColor(CGColor(red: 31/255.0, green: 41/255.0, blue: 55/255.0, alpha: 1.0))
        ctx.setLineWidth(1.5)
        ctx.fill(cardRect)
        ctx.stroke(cardRect)

        // 5. 绘制 Y 轴网格线与自适应刻度 (5 档自适应)
        let yStep = max(1.0, (domainMaxY - domainMinY) / 5.0)
        let gridLineColor = CGColor(red: 31/255.0, green: 41/255.0, blue: 55/255.0, alpha: 0.8)
        let labelColor = NSColor(calibratedRed: 156/255.0, green: 163/255.0, blue: 175/255.0, alpha: 1.0)

        for yVal in stride(from: domainMinY, through: domainMaxY, by: yStep) {
            let y = mapY(yVal)
            ctx.setStrokeColor(gridLineColor)
            ctx.setLineWidth(1.0)
            ctx.setLineDash(phase: 0, lengths: [4, 4])
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

            let label = String(format: "%.1f%%", yVal)
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: labelColor]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: marginLeft - size.width - 12, y: y - size.height / 2))
            NSGraphicsContext.restoreGraphicsState()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // 6. 绘制 X 轴刻度网格线
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
                let x = mapX(tick.val)
                ctx.setStrokeColor(gridLineColor)
                ctx.setLineWidth(1.0)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                ctx.strokeLineSegments(between: [CGPoint(x: x, y: marginBottom), CGPoint(x: x, y: marginBottom + plotH)])

                let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: labelColor]
                let str = NSAttributedString(string: tick.label, attributes: attrs)
                let size = str.size()

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: x - size.width / 2, y: marginBottom - size.height - 10))
                NSGraphicsContext.restoreGraphicsState()
            }
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // 7. 绘制帕累托最优包络线与填充区
        let frontier = result.frontierPoints.sorted(by: { $0.throughputMBs < $1.throughputMBs })
        if frontier.count >= 2 {
            let path = CGMutablePath()
            let firstPt = CGPoint(x: mapX(frontier[0].throughputMBs), y: mapY(frontier[0].spaceSavingsPct))
            path.move(to: firstPt)

            for p in frontier.dropFirst() {
                path.addLine(to: CGPoint(x: mapX(p.throughputMBs), y: mapY(p.spaceSavingsPct)))
            }

            // 填充渐变区域
            let fillPath = CGMutablePath()
            fillPath.addPath(path)
            let lastX = mapX(frontier.last!.throughputMBs)
            let firstX = mapX(frontier.first!.throughputMBs)
            fillPath.addLine(to: CGPoint(x: lastX, y: marginBottom))
            fillPath.addLine(to: CGPoint(x: firstX, y: marginBottom))
            fillPath.closeSubpath()

            ctx.addPath(fillPath)
            ctx.setFillColor(CGColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 0.12))
            ctx.fillPath()

            // 描边包络线
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 1.0))
            ctx.setLineWidth(3.5)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // 8. 绘制数据点与智能避让标签
        for (idx, p) in result.allPoints.enumerated() {
            let x = mapX(p.throughputMBs)
            let y = mapY(p.spaceSavingsPct)
            let isPareto = p.isParetoOptimal

            if isPareto {
                // 外圈光晕
                ctx.setFillColor(CGColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 0.3))
                ctx.fillEllipse(in: CGRect(x: x - 14, y: y - 14, width: 28, height: 28))

                // 金色实心点
                ctx.setFillColor(CGColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 1.0))
                ctx.setStrokeColor(CGColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0))
                ctx.setLineWidth(2.5)
                let dotRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)

                // 悬浮标签药丸卡片 (智能交错上下排布防重叠)
                let isTopStagger = (idx % 2 == 0)
                let pillY = isTopStagger ? (y + 16) : (y - 34)
                let pillText = "👑 \(p.algorithm) L\(p.level): \(String(format: "%.0f MB/s", p.throughputMBs))"
                let font = NSFont.systemFont(ofSize: 11, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 254/255.0, green: 240/255.0, blue: 138/255.0, alpha: 1.0)
                ]
                let str = NSAttributedString(string: pillText, attributes: attrs)
                let strSize = str.size()

                let pillRect = CGRect(x: x - strSize.width / 2 - 6, y: pillY, width: strSize.width + 12, height: strSize.height + 6)
                ctx.setFillColor(CGColor(red: 31/255.0, green: 41/255.0, blue: 55/255.0, alpha: 0.95))
                ctx.setStrokeColor(CGColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 0.8))
                ctx.setLineWidth(1.0)
                ctx.fill(pillRect)
                ctx.stroke(pillRect)

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                str.draw(at: CGPoint(x: x - strSize.width / 2, y: pillY + 3))
                NSGraphicsContext.restoreGraphicsState()
            } else {
                // 普通被支配点 (蓝色微型圆点)
                ctx.setFillColor(CGColor(red: 96/255.0, green: 165/255.0, blue: 250/255.0, alpha: 0.85))
                ctx.setStrokeColor(CGColor(red: 17/255.0, green: 24/255.0, blue: 39/255.0, alpha: 1.0))
                ctx.setLineWidth(1.5)
                let dotRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)
            }
        }

        // 9. 绘制右侧独立数据看板面板 (Leaderboard & Metrics Sidebar)
        let sidebarX = width - sidebarWidth - 25.0
        let sidebarRect = CGRect(x: sidebarX, y: marginBottom, width: sidebarWidth, height: plotH)
        ctx.setFillColor(CGColor(red: 17/255.0, green: 24/255.0, blue: 39/255.0, alpha: 0.85))
        ctx.setStrokeColor(CGColor(red: 31/255.0, green: 41/255.0, blue: 55/255.0, alpha: 1.0))
        ctx.setLineWidth(1.5)
        ctx.fill(sidebarRect)
        ctx.stroke(sidebarRect)

        // 看板标题
        let sbTitleFont = NSFont.systemFont(ofSize: 16, weight: .bold)
        let sbTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: sbTitleFont,
            .foregroundColor: NSColor(calibratedRed: 243/255.0, green: 244/255.0, blue: 246/255.0, alpha: 1.0)
        ]
        let sbTitle = NSAttributedString(string: "📊 算法性能全量排名看板", attributes: sbTitleAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        sbTitle.draw(at: CGPoint(x: sidebarX + 16, y: marginBottom + plotH - 35))

        // 逐条绘制排名条目
        var itemY = marginBottom + plotH - 65
        let sortedPoints = result.allPoints.sorted { (a, b) -> Bool in
            if a.isParetoOptimal != b.isParetoOptimal { return a.isParetoOptimal && !b.isParetoOptimal }
            return a.throughputMBs > b.throughputMBs
        }

        for (rankIdx, p) in sortedPoints.enumerated() {
            if itemY < marginBottom + 20 { break }

            let isPareto = p.isParetoOptimal
            let badge = isPareto ? "👑 前沿最优" : "⚪ 被支配"
            let badgeColor = isPareto ? NSColor(calibratedRed: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 1.0) : NSColor(calibratedRed: 107/255.0, green: 114/255.0, blue: 128/255.0, alpha: 1.0)

            let rowHeader = "\(rankIdx + 1). \(p.algorithm) L\(p.level)"
            let rowMetrics = "\(String(format: "%.1f MB/s", p.throughputMBs)) · \(String(format: "%.1f%%", p.spaceSavingsPct))"

            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: isPareto ? .bold : .medium),
                .foregroundColor: isPareto ? NSColor(calibratedRed: 254/255.0, green: 240/255.0, blue: 138/255.0, alpha: 1.0) : NSColor(calibratedRed: 209/255.0, green: 213/255.0, blue: 219/255.0, alpha: 1.0)
            ]
            let metricsAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor(calibratedRed: 156/255.0, green: 163/255.0, blue: 175/255.0, alpha: 1.0)
            ]
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: badgeColor
            ]

            let hStr = NSAttributedString(string: rowHeader, attributes: headerAttrs)
            let mStr = NSAttributedString(string: rowMetrics, attributes: metricsAttrs)
            let bStr = NSAttributedString(string: badge, attributes: badgeAttrs)

            hStr.draw(at: CGPoint(x: sidebarX + 16, y: itemY))
            bStr.draw(at: CGPoint(x: sidebarX + sidebarWidth - bStr.size().width - 16, y: itemY))
            mStr.draw(at: CGPoint(x: sidebarX + 16, y: itemY - 18))

            itemY -= 48
        }
        NSGraphicsContext.restoreGraphicsState()

        // 10. 顶部主标题与硬件信息
        let titleFont = NSFont.systemFont(ofSize: 26, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(calibratedRed: 248/255.0, green: 250/255.0, blue: 252/255.0, alpha: 1.0)
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)

        let subFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let subStr = NSAttributedString(string: "Apple Silicon Native In-Memory Engine · Calibrated Nanosecond Resolution Timer", attributes: subAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        titleStr.draw(at: CGPoint(x: marginLeft, y: height - marginTop + 60))
        subStr.draw(at: CGPoint(x: marginLeft, y: height - marginTop + 35))
        NSGraphicsContext.restoreGraphicsState()

        // 11. 坐标轴名称说明
        let axisFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: axisFont,
            .foregroundColor: NSColor(calibratedRed: 209/255.0, green: 213/255.0, blue: 219/255.0, alpha: 1.0)
        ]
        let xAxisLabel = NSAttributedString(string: "压缩吞吐速度 Throughput (MB/s, 对数尺度)", attributes: axisAttrs)
        let yAxisLabel = NSAttributedString(string: "空间节省率 Space Savings (%)", attributes: axisAttrs)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        xAxisLabel.draw(at: CGPoint(x: marginLeft + (plotW - xAxisLabel.size().width) / 2, y: marginBottom - 45))
        yAxisLabel.draw(at: CGPoint(x: marginLeft, y: marginBottom + plotH + 8))
        NSGraphicsContext.restoreGraphicsState()
    }
    #endif
}
