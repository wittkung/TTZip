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

/// 原生 CoreGraphics / AppKit 高分辨率位图 PNG 渲染器 (Retina 2x/4K 级矢量光栅化图表生成)
public final class RasterParetoPlotter: @unchecked Sendable {
    public static let shared = RasterParetoPlotter()
    private init() {}

    /// 导出高清晰度 PNG 图片到指定文件路径
    public func exportPNG(
        result: ParetoFrontierResult,
        to filePath: String,
        width: CGFloat = 1920.0,
        height: CGFloat = 1200.0,
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
            throw NSError(domain: "TTZip.RasterParetoPlotter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from context"])
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "TTZip.RasterParetoPlotter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG representation"])
        }

        let fileURL = URL(fileURLWithPath: filePath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: fileURL, options: .atomic)
        #else
        throw NSError(domain: "TTZip.RasterParetoPlotter", code: -4, userInfo: [NSLocalizedDescriptionKey: "AppKit/CoreGraphics is required for PNG rasterization"])
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
        // 1. 背景绘制 (Dark Navy #0b1120 -> #020617 渐变)
        let bgGradientColors = [
            CGColor(red: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0),
            CGColor(red: 2/255.0, green: 6/255.0, blue: 23/255.0, alpha: 1.0)
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: colorSpace, colors: bgGradientColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        }

        // 坐标系边距设置
        let marginLeft: CGFloat = 160.0
        let marginRight: CGFloat = 100.0
        let marginTop: CGFloat = 160.0
        let marginBottom: CGFloat = 140.0

        let plotW = width - marginLeft - marginRight
        let plotH = height - marginTop - marginBottom

        let minLogX: Double = 1.0 // log10(10 MB/s)
        let maxLogX: Double = 5.0 // log10(100,000 MB/s)

        func mapX(_ val: Double) -> CGFloat {
            let clamped = max(10.0, min(val, 100000.0))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return marginLeft + CGFloat(norm) * plotW
        }

        func mapY(_ val: Double) -> CGFloat {
            let clamped = max(0.0, min(val, 100.0))
            let norm = clamped / 100.0
            return marginBottom + CGFloat(norm) * plotH
        }

        // 2. 绘制卡片背景面板
        ctx.setFillColor(CGColor(red: 30/255.0, green: 41/255.0, blue: 59/255.0, alpha: 0.5))
        ctx.setStrokeColor(CGColor(red: 51/255.0, green: 65/255.0, blue: 85/255.0, alpha: 0.8))
        ctx.setLineWidth(1.5)
        let cardRect = CGRect(x: marginLeft, y: marginBottom, width: plotW, height: plotH)
        ctx.fill(cardRect)
        ctx.stroke(cardRect)

        // 3. 绘制网格线与 Y 轴刻度
        ctx.setLineWidth(1.0)
        let gridMajorColor = CGColor(red: 51/255.0, green: 65/255.0, blue: 85/255.0, alpha: 0.6)
        let textColor = NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)

        for pct in stride(from: 0.0, through: 100.0, by: 20.0) {
            let y = mapY(pct)
            ctx.setStrokeColor(gridMajorColor)
            ctx.strokeLineSegments(between: [CGPoint(x: marginLeft, y: y), CGPoint(x: marginLeft + plotW, y: y)])

            let label = String(format: "%.0f%%", pct)
            let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()
            
            // CoreGraphics Text Matrix fix: draw with AppKit within graphics context
            NSGraphicsContext.saveGraphicsState()
            let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = gCtx
            str.draw(at: CGPoint(x: marginLeft - size.width - 15, y: y - size.height / 2))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 4. 绘制 X 轴对数刻度网格线
        let xTicks: [(val: Double, label: String)] = [
            (10.0, "10 MB/s"),
            (100.0, "100 MB/s"),
            (1000.0, "1,000 MB/s"),
            (10000.0, "10,000 MB/s"),
            (100000.0, "100,000 MB/s")
        ]

        for tick in xTicks {
            let x = mapX(tick.val)
            ctx.setStrokeColor(gridMajorColor)
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: marginBottom), CGPoint(x: x, y: marginBottom + plotH)])

            let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: tick.label, attributes: attrs)
            let size = str.size()

            NSGraphicsContext.saveGraphicsState()
            let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = gCtx
            str.draw(at: CGPoint(x: x - size.width / 2, y: marginBottom - size.height - 12))
            NSGraphicsContext.restoreGraphicsState()
        }

        // 5. 绘制帕累托包络线与填充区域
        let frontier = result.frontierPoints.sorted(by: { $0.throughputMBs < $1.throughputMBs })
        if frontier.count >= 2 {
            let path = CGMutablePath()
            let firstPt = CGPoint(x: mapX(frontier.first!.throughputMBs), y: mapY(frontier.first!.spaceSavingsPct))
            path.move(to: firstPt)

            for p in frontier.dropFirst() {
                path.addLine(to: CGPoint(x: mapX(p.throughputMBs), y: mapY(p.spaceSavingsPct)))
            }

            // 填充阴影
            let fillPath = CGMutablePath()
            fillPath.addPath(path)
            let lastX = mapX(frontier.last!.throughputMBs)
            let firstX = mapX(frontier.first!.throughputMBs)
            fillPath.addLine(to: CGPoint(x: lastX, y: marginBottom))
            fillPath.addLine(to: CGPoint(x: firstX, y: marginBottom))
            fillPath.closeSubpath()

            ctx.addPath(fillPath)
            ctx.setFillColor(CGColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 0.15))
            ctx.fillPath()

            // 描边包络线
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 1.0))
            ctx.setLineWidth(4.0)
            ctx.setLineDash(phase: 0, lengths: [8, 5])
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: []) // 还原虚线
        }

        // 6. 绘制所有数据点与高亮标注
        for p in result.allPoints {
            let x = mapX(p.throughputMBs)
            let y = mapY(p.spaceSavingsPct)
            let isPareto = p.isParetoOptimal

            if isPareto {
                // 外圈光晕
                ctx.setFillColor(CGColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 0.35))
                ctx.fillEllipse(in: CGRect(x: x - 18, y: y - 18, width: 36, height: 36))

                // 金色实心圆点
                ctx.setFillColor(CGColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 1.0))
                ctx.setStrokeColor(CGColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0))
                ctx.setLineWidth(3.0)
                let dotRect = CGRect(x: x - 10, y: y - 10, width: 20, height: 20)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)

                // 标签文字
                let labelText = "👑 \(p.algorithm) L\(p.level)\n\(String(format: "%.1f MB/s · %.1f%%", p.throughputMBs, p.spaceSavingsPct))"
                let font = NSFont.systemFont(ofSize: 15, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 254/255.0, green: 240/255.0, blue: 138/255.0, alpha: 1.0)
                ]
                let str = NSAttributedString(string: labelText, attributes: attrs)
                let size = str.size()

                NSGraphicsContext.saveGraphicsState()
                let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
                NSGraphicsContext.current = gCtx
                str.draw(at: CGPoint(x: x + 16, y: y - size.height / 2))
                NSGraphicsContext.restoreGraphicsState()
            } else {
                // 普通被支配点 (蓝色)
                ctx.setFillColor(CGColor(red: 96/255.0, green: 165/255.0, blue: 250/255.0, alpha: 0.9))
                ctx.setStrokeColor(CGColor(red: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0))
                ctx.setLineWidth(2.0)
                let dotRect = CGRect(x: x - 7, y: y - 7, width: 14, height: 14)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)

                let labelText = "\(p.algorithm) L\(p.level)"
                let font = NSFont.systemFont(ofSize: 13, weight: .medium)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 0.85)
                ]
                let str = NSAttributedString(string: labelText, attributes: attrs)

                NSGraphicsContext.saveGraphicsState()
                let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
                NSGraphicsContext.current = gCtx
                str.draw(at: CGPoint(x: x + 12, y: y - str.size().height / 2))
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // 7. 标题与副标题
        let titleFont = NSFont.systemFont(ofSize: 32, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(calibratedRed: 248/255.0, green: 250/255.0, blue: 252/255.0, alpha: 1.0)
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)

        let subFont = NSFont.systemFont(ofSize: 16, weight: .regular)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: NSColor(calibratedRed: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
        ]
        let subStr = NSAttributedString(string: "Apple Silicon Native In-Memory Engine · Calibrated Nanosecond Resolution Timer", attributes: subAttrs)

        NSGraphicsContext.saveGraphicsState()
        let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = gCtx
        titleStr.draw(at: CGPoint(x: marginLeft, y: height - marginTop + 70))
        subStr.draw(at: CGPoint(x: marginLeft, y: height - marginTop + 40))
        NSGraphicsContext.restoreGraphicsState()
    }
    #endif
}
