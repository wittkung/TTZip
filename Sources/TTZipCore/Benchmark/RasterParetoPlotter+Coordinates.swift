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
/// 通用算法驱动的自适应多维坐标引擎 (Adaptive Universal Coordinate Engine)
struct PlotCoordinateEngine {
    let marginLeft: CGFloat = 130.0
    let marginRight: CGFloat = 120.0
    let marginTop: CGFloat = 160.0
    let marginBottom: CGFloat = 120.0

    let width: CGFloat
    let height: CGFloat
    let plotW: CGFloat
    let plotH: CGFloat

    let hasIsolatedStore: Bool
    let xDomainMin: Double
    let xDomainMax: Double
    let logMin: Double
    let logMax: Double
    let logSpan: Double
    let compSpan: Double

    struct MappedTick {
        let sizeMB: Double
        let canvasX: CGFloat
        let label: String
    }

    init(width: CGFloat, height: CGFloat, result: ParetoFrontierResult) {
        self.width = width
        self.height = height
        self.plotW = width - 130.0 - 120.0
        self.plotH = height - 160.0 - 120.0

        let allSizes = result.allPoints.map { Self.getPointMB($0) }.sorted()
        let allSpeeds = result.allPoints.map { $0.throughputMBs }.sorted()

        let rawMinSize = allSizes.first ?? 2.8
        let rawMaxSize = allSizes.last ?? 4.2

        let storeSizes = allSizes.filter { $0 >= 50.0 }
        let compSizes = allSizes.filter { $0 < 50.0 }
        let isolated = !storeSizes.isEmpty && !compSizes.isEmpty && (compSizes.last ?? 0) <= 30.0
        self.hasIsolatedStore = isolated

        let activeSizes = isolated ? compSizes : allSizes
        let compMin = activeSizes.first ?? rawMinSize
        let compMax = activeSizes.last ?? rawMaxSize

        let cSpan = max(1e-4, compMax - compMin)
        self.compSpan = cSpan
        let xMargin = max(0.005, cSpan * 0.08)
        self.xDomainMin = max(0.0001, compMin - xMargin)
        self.xDomainMax = compMax + xMargin

        let rawMinSpeed = max(0.1, allSpeeds.first ?? 0.3)
        let rawMaxSpeed = max(10.0, allSpeeds.last ?? 1000.0)

        let lMin = floor(log10(rawMinSpeed * 0.75))
        let lMax = ceil(log10(rawMaxSpeed * 1.25))
        self.logMin = lMin
        self.logMax = lMax
        self.logSpan = max(1.0, lMax - lMin)
    }

    static func getPointMB(_ p: ParetoPoint) -> Double {
        if p.compressedBytes > 0 {
            return Double(p.compressedBytes) / (1024.0 * 1024.0)
        } else {
            return 100.0 * (1.0 - p.spaceSavingsPct / 100.0)
        }
    }

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

    func mapY(_ speedVal: Double) -> CGFloat {
        let v = max(pow(10.0, logMin), speedVal)
        let logV = log10(v)
        let norm = (logV - logMin) / logSpan
        return marginBottom + CGFloat(max(0.0, min(1.0, norm))) * plotH
    }

    func computeActiveYTicks() -> [(val: Double, label: String, canvasY: CGFloat)] {
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
        return activeYTicks
    }

    func computeActiveXTicks() -> [MappedTick] {
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
        return activeXTicks
    }
}
#endif
