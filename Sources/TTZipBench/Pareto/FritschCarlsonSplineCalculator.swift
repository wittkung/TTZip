// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

/// 2D 三次贝塞尔曲线控制段
public struct CubicBezierSegment: Sendable {
    public let startPoint: (x: Double, y: Double)
    public let controlPoint1: (x: Double, y: Double)
    public let controlPoint2: (x: Double, y: Double)
    public let endPoint: (x: Double, y: Double)
}

/// Fritsch-Carlson (1980) 单调保形三次 Hermite 样条插值转换器
public struct FritschCarlsonSplineCalculator: Sendable {
    public static func calculateBezierSegments(points: [(x: Double, y: Double)]) -> [CubicBezierSegment] {
        let n = points.count
        guard n >= 2 else { return [] }
        if n == 2 {
            let p0 = points[0]
            let p1 = points[1]
            let cp1 = (x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y + (p1.y - p0.y) / 3.0)
            let cp2 = (x: p1.x - (p1.x - p0.x) / 3.0, y: p1.y - (p1.y - p0.y) / 3.0)
            return [CubicBezierSegment(startPoint: p0, controlPoint1: cp1, controlPoint2: cp2, endPoint: p1)]
        }

        var h = [Double](repeating: 0, count: n - 1)
        var delta = [Double](repeating: 0, count: n - 1)

        for i in 0..<(n - 1) {
            let dx = points[i + 1].x - points[i].x
            h[i] = max(1.0, dx)
            delta[i] = (points[i + 1].y - points[i].y) / h[i]
        }

        var d = [Double](repeating: 0, count: n)
        d[0] = delta[0]
        d[n - 1] = delta[n - 2]

        for i in 1..<(n - 1) {
            if delta[i - 1] * delta[i] <= 0.0 {
                d[i] = 0.0
            } else {
                let p = 2.0 * delta[i - 1] * delta[i] / (delta[i - 1] + delta[i])
                d[i] = p
            }
        }

        var segments: [CubicBezierSegment] = []
        for i in 0..<(n - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let segH = points[i + 1].x - points[i].x
            let cp1Y = p0.y + (d[i] * segH) / 3.0
            let cp2Y = p1.y - (d[i + 1] * segH) / 3.0
            let cp1 = (x: p0.x + segH / 3.0, y: cp1Y)
            let cp2 = (x: p1.x - segH / 3.0, y: cp2Y)
            segments.append(CubicBezierSegment(startPoint: p0, controlPoint1: cp1, controlPoint2: cp2, endPoint: p1))
        }
        return segments
    }
}
