// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 终端 Unicode Braille 盲文点阵 (8x 分辨率) 2D 帕累托散点与折线渲染器
public final class TerminalParetoPlotter: @unchecked Sendable {
    public static let shared = TerminalParetoPlotter()
    private init() {}

    /// 渲染终端 2D 散点图字符串 (默认 60 列 x 20 行 Braille 字符，对应 120 x 80 虚拟像素)
    public func renderTerminalPlot(
        result: ParetoFrontierResult,
        widthChars: Int = 60,
        heightChars: Int = 18
    ) -> String {
        let cols = max(40, min(widthChars, 120))
        let rows = max(10, min(heightChars, 40))

        let dotWidth = cols * 2
        let dotHeight = rows * 4

        // 1. 初始化点阵位图 (Uint8 数组: 每个元素代表 8 个点位掩码)
        var canvas = [UInt8](repeating: 0, count: cols * rows)

        // 2. 确定 X (Log10 吞吐 MB/s: 10 到 100,000) 与 Y (Space Savings %: 0 到 100) 坐标映射
        let minLogX = 1.0 // log10(10)
        let maxLogX = 5.0 // log10(100,000)

        func mapX(_ mbS: Double) -> Int {
            let clamped = max(10.0, min(mbS, 100000.0))
            let logV = log10(clamped)
            let norm = (logV - minLogX) / (maxLogX - minLogX)
            return max(0, min(Int(norm * Double(dotWidth - 1)), dotWidth - 1))
        }

        func mapY(_ savingPct: Double) -> Int {
            let clamped = max(0.0, min(savingPct, 100.0))
            let norm = (100.0 - clamped) / 100.0 // 0% 在底部，100% 在顶部
            return max(0, min(Int(norm * Double(dotHeight - 1)), dotHeight - 1))
        }

        func setDot(dotX: Int, dotY: Int) {
            guard dotX >= 0 && dotX < dotWidth && dotY >= 0 && dotY < dotHeight else { return }
            let cellX = dotX / 2
            let cellY = dotY / 4
            let subX = dotX % 2
            let subY = dotY % 4

            // Braille 点位映射掩码:
            // subX=0: row 0=1(0x01), row 1=2(0x02), row 2=3(0x04), row 3=7(0x40)
            // subX=1: row 0=4(0x08), row 1=5(0x10), row 2=6(0x20), row 3=8(0x80)
            let bitMask: UInt8
            if subX == 0 {
                switch subY {
                case 0: bitMask = 0x01
                case 1: bitMask = 0x02
                case 2: bitMask = 0x04
                default: bitMask = 0x40
                }
            } else {
                switch subY {
                case 0: bitMask = 0x08
                case 1: bitMask = 0x10
                case 2: bitMask = 0x20
                default: bitMask = 0x80
                }
            }

            let cellIdx = cellY * cols + cellX
            canvas[cellIdx] |= bitMask
        }

        // 3. 使用 Bresenham 算法连线帕累托前沿顶点
        let frontier = result.frontierPoints
        if frontier.count >= 2 {
            for i in 0..<(frontier.count - 1) {
                let x0 = mapX(frontier[i].throughputMBs)
                let y0 = mapY(frontier[i].spaceSavingsPct)
                let x1 = mapX(frontier[i + 1].throughputMBs)
                let y1 = mapY(frontier[i + 1].spaceSavingsPct)
                rasterizeBresenhamLine(x0: x0, y0: y0, x1: x1, y1: y1, setPixel: setDot)
            }
        }

        // 4. 绘制所有离散散点
        for p in result.allPoints {
            let x = mapX(p.throughputMBs)
            let y = mapY(p.spaceSavingsPct)
            // 绘制 2x2 像素块强化散点可见性
            setDot(dotX: x, dotY: y)
            setDot(dotX: min(dotWidth - 1, x + 1), dotY: y)
            setDot(dotX: x, dotY: min(dotHeight - 1, y + 1))
        }

        // 5. 组合 ANSI 边框与图表字符串
        var out = ""
        out += "╔═ 📈 帕累托最优前沿分析图 (Pareto Frontier: 压缩率 vs 吞吐速率) ═══════════════════╗\n"
        out += "║ Y: 空间节省率 (Space Savings %)  |  X: 吞吐速率 (Throughput MB/s, Log10)           ║\n"
        out += "╠════════════════════════════════════════════════════════════════════════════════════╣\n"

        let yLabels: [Int: String] = [
            0: "100% ┤",
            rows / 4: " 75% ┤",
            rows / 2: " 50% ┤",
            (rows * 3) / 4: " 25% ┤",
            rows - 1: "  0% ┤"
        ]

        for r in 0..<rows {
            let label = yLabels[r] ?? "     │"
            out += "║ " + label
            for c in 0..<cols {
                let mask = canvas[r * cols + c]
                let scalarVal = 0x2800 + UInt32(mask)
                if let scalar = UnicodeScalar(scalarVal) {
                    out.append(Character(scalar))
                } else {
                    out.append(" ")
                }
            }
            out += " ║\n"
        }

        out += "║      └" + String(repeating: "─", count: cols) + " ║\n"
        out += "║       10 MB/s      100 MB/s      1,000 MB/s      10,000 MB/s     100,000 MB/s      ║\n"
        out += "╠════════════════════════════════════════════════════════════════════════════════════╣\n"
        out += "║ 👑 帕累托最优顶点集合 (Pareto-Optimal Set):                                        ║\n"

        for p in result.frontierPoints {
            let crown = p.isOnConvexEnvelope ? "👑 (Convex Winner)" : "⭐ (Frontier)"
            let algoPadded = p.algorithm.padding(toLength: 16, withPad: " ", startingAt: 0)
            let line = String(format: "║  • %@ | %2d | %8.1f MB/s | %5.1f%% 节省 | %@ ",
                              algoPadded, p.level, p.throughputMBs, p.spaceSavingsPct, crown)
            out += line.padding(toLength: 85, withPad: " ", startingAt: 0) + "║\n"
        }

        out += "╚════════════════════════════════════════════════════════════════════════════════════╝\n"
        return out
    }

    /// 经典 Bresenham 直线点阵光栅化算法
    private func rasterizeBresenhamLine(
        x0: Int,
        y0: Int,
        x1: Int,
        y1: Int,
        setPixel: (Int, Int) -> Void
    ) {
        var cx0 = x0
        var cy0 = y0
        let dx = abs(x1 - cx0)
        let sx = cx0 < x1 ? 1 : -1
        let dy = -abs(y1 - cy0)
        let sy = cy0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            setPixel(cx0, cy0)
            if cx0 == x1 && cy0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                cx0 += sx
            }
            if e2 <= dx {
                err += dx
                cy0 += sy
            }
        }
    }
}
