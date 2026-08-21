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

    /// 软件家族聚类与全量轨迹提取 (按 level 由小到大连接，构成自然算法演进轨迹)
    func extractTrajectories(from result: ParetoFrontierResult) -> [SoftwareFamilyTrajectory] {
        var groupedPoints: [SoftwareFamily: [ParetoPoint]] = [:]
        for p in result.allPoints {
            let fam = SoftwareFamilyClassifier.classify(algorithm: p.algorithm)
            groupedPoints[fam, default: []].append(p)
        }

        var trajectories: [SoftwareFamilyTrajectory] = []
        for fam in SoftwareFamily.allCases {
            if let famPoints = groupedPoints[fam], !famPoints.isEmpty {
                let sortedPoints = famPoints.sorted { $0.level < $1.level }
                let heroPill = fam.isHero ? (sortedPoints.filter { PlotCoordinateEngine.getPointMB($0) < 50.0 }.max(by: { $0.throughputMBs < $1.throughputMBs })) : nil
                trajectories.append(SoftwareFamilyTrajectory(family: fam, points: sortedPoints, heroPillPoint: heroPill))
            }
        }
        return trajectories
    }

    /// 绘制各软件家族主实线轨迹
    func renderTrajectories(ctx: CGContext, trajectories: [SoftwareFamilyTrajectory], coords: PlotCoordinateEngine) {
        for traj in trajectories {
            let pts = traj.points.map { CGPoint(x: coords.mapX(sizeMB: PlotCoordinateEngine.getPointMB($0)), y: coords.mapY($0.throughputMBs)) }
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
    }

    /// 绘制右上角学术图例 (Academic Legend Box)
    func renderLegend(ctx: CGContext, trajectories: [SoftwareFamilyTrajectory], coords: PlotCoordinateEngine) {
        let activeFamilies = trajectories.map { $0.family }
        guard activeFamilies.count >= 2 else { return }

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
        let legendX = coords.marginLeft + coords.plotW - legendW
        let legendY = coords.marginBottom + coords.plotH - legendH - 6.0

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
}
#endif
