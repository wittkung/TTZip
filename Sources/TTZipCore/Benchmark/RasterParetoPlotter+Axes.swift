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
extension RasterParetoPlotter {
    
    /// 1. 纯白极简学术背景 (#FFFFFF)
    func renderBackground(ctx: CGContext, width: CGFloat, height: CGFloat) {
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// 3. 绘制坐标轴、极淡水平网格线与 Y/X 轴刻度
    func renderAxesAndGrids(ctx: CGContext, coords: PlotCoordinateEngine) {
        let gridColor = CGColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0)
        let axisLineColor = CGColor(red: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        let axisTextColor = NSColor(calibratedRed: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)

        // 3.1 绘制 Y 轴网格线与刻度
        let activeYTicks = coords.computeActiveYTicks()
        for tick in activeYTicks {
            let y = tick.canvasY
            ctx.setStrokeColor(gridColor)
            ctx.setLineWidth(1.0)
            ctx.strokeLineSegments(between: [CGPoint(x: coords.marginLeft, y: y), CGPoint(x: coords.marginLeft + coords.plotW, y: y)])

            // Y 轴短刻度线 (5pt 向左突出)
            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: coords.marginLeft - 5, y: y), CGPoint(x: coords.marginLeft, y: y)])

            let font = NSFont.systemFont(ofSize: 12, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: tick.label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            str.draw(at: CGPoint(x: coords.marginLeft - size.width - 12, y: y - size.height / 2))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 3.2 绘制 X 轴刻度与短刻度线
        let activeXTicks = coords.computeActiveXTicks()
        for tick in activeXTicks {
            let x = tick.canvasX
            // X 轴短刻度线 (5pt 向下突出)
            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: coords.marginBottom), CGPoint(x: x, y: coords.marginBottom - 5)])

            let font = NSFont.systemFont(ofSize: 12, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: axisTextColor]
            let str = NSAttributedString(string: tick.label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let drawX = x == coords.marginLeft ? x : (x - size.width / 2)
            str.draw(at: CGPoint(x: drawX, y: coords.marginBottom - size.height - 12))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 3.3 绘制实线坐标轴主框架 (Solid Coordinate Axes Lines)
        ctx.setStrokeColor(axisLineColor)
        ctx.setLineWidth(1.5)
        // 绘制 Y 轴实线
        ctx.strokeLineSegments(between: [CGPoint(x: coords.marginLeft, y: coords.marginBottom), CGPoint(x: coords.marginLeft, y: coords.marginBottom + coords.plotH)])
        // 绘制 X 轴实线
        ctx.strokeLineSegments(between: [CGPoint(x: coords.marginLeft, y: coords.marginBottom), CGPoint(x: coords.marginLeft + coords.plotW, y: coords.marginBottom)])

        // 3.4 若存在 Store 孤立点，绘制 X 轴折叠断裂标记
        if coords.hasIsolatedStore {
            let slashW: CGFloat = 8.0
            let slashH: CGFloat = 8.0
            let slashGap: CGFloat = 4.0
            let breakX = coords.marginLeft + CGFloat(0.08) * coords.plotW
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            ctx.fill(CGRect(x: breakX - 10, y: coords.marginBottom - 6, width: 20, height: 12))

            ctx.setStrokeColor(axisLineColor)
            ctx.setLineWidth(1.8)
            ctx.strokeLineSegments(between: [
                CGPoint(x: breakX - slashGap - slashW/2, y: coords.marginBottom - slashH/2),
                CGPoint(x: breakX - slashGap + slashW/2, y: coords.marginBottom + slashH/2),
                CGPoint(x: breakX + slashGap - slashW/2, y: coords.marginBottom - slashH/2),
                CGPoint(x: breakX + slashGap + slashW/2, y: coords.marginBottom + slashH/2)
            ])
        }

        // 3.5 绘制右上角 "most efficient ↗" 引导标注
        let effFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let effAttrs: [NSAttributedString.Key: Any] = [
            .font: effFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let effStr = NSAttributedString(string: "most efficient ↗", attributes: effAttrs)
        let effSize = effStr.size()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        effStr.draw(at: CGPoint(x: coords.marginLeft + coords.plotW - effSize.width - 4, y: coords.marginBottom + coords.plotH + 8))
        NSGraphicsContext.restoreGraphicsState()
    }

    /// 绘制顶部品牌与标题以及底部 X 轴标题与数据来源
    func renderHeaderAndFooterTitles(
        ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        marginBottom: CGFloat,
        title: String
    ) {
        // 顶部品牌与自适应无裁切主标题
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

        // 底部居中 X 轴标题 (Compressed File Size MB) 与数据来源标注
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
}
#endif
