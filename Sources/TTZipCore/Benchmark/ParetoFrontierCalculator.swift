// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 2D 帕累托非支配前沿与凸包包络线计算中枢 (2D Skyline & Monotone Chain Algorithm)
public final class ParetoFrontierCalculator: @unchecked Sendable {
    public static let shared = ParetoFrontierCalculator()
    private init() {}

    private let epsilon: Double = 1e-7

    /// 从原始基准测试结果列表中提取帕累托前沿与上凸包包络线
    public func calculateFrontier(from benchmarkResults: [AlgorithmBenchmarkResult]) -> ParetoFrontierResult {
        guard !benchmarkResults.isEmpty else {
            return ParetoFrontierResult(
                totalPointsEvaluated: 0,
                frontierPoints: [],
                convexEnvelopePoints: [],
                allPoints: []
            )
        }

        var points: [ParetoPoint] = benchmarkResults.enumerated().map { (idx, r) in
            let id = "\(r.algorithm.lowercased())_l\(r.level)"
            return ParetoPoint(
                id: id,
                algorithm: r.algorithm,
                level: r.level,
                throughputMBs: r.compressionSpeedMBs,
                spaceSavingsPct: r.spaceSavingsPct,
                compressedBytes: r.compressedBytes,
                uncompressedBytes: r.uncompressedBytes,
                paretoRank: 1,
                isParetoOptimal: false,
                isOnConvexEnvelope: false
            )
        }

        return computeParetoFrontier(points: &points)
    }

    /// 执行 2D 扫描线与 Patience Binary Search 确定多级帕累托层级与上凸包
    public func computeParetoFrontier(points: inout [ParetoPoint]) -> ParetoFrontierResult {
        guard !points.isEmpty else {
            return ParetoFrontierResult(totalPointsEvaluated: 0, frontierPoints: [], convexEnvelopePoints: [], allPoints: [])
        }

        // 1. 按照 (吞吐降序 x 降序, 空间节省率降序 y 降序) 排序
        points.sort { (a, b) -> Bool in
            if abs(a.throughputMBs - b.throughputMBs) > epsilon {
                return a.throughputMBs > b.throughputMBs
            }
            return a.spaceSavingsPct > b.spaceSavingsPct
        }

        // 2. 基于 Dilworth 定理与 Patience Sorting 计算多层 Pareto Rank (O(N log K))
        // targetTiers[j] 记录第 j 层的当前最大 y 坐标
        var targetTiers: [Double] = []

        for i in 0..<points.count {
            let curY = points[i].spaceSavingsPct
            
            // 在 targetTiers 中二分查找最小的满足 curY > targetTiers[j] 的层级 j
            var left = 0
            var right = targetTiers.count
            while left < right {
                let mid = (left + right) / 2
                if curY > targetTiers[mid] + epsilon {
                    right = mid
                } else {
                    left = mid + 1
                }
            }

            if left < targetTiers.count {
                // 加入已有层级
                points[i].paretoRank = left + 1
                targetTiers[left] = curY
            } else {
                // 开启新层级
                targetTiers.append(curY)
                points[i].paretoRank = targetTiers.count
            }

            points[i].isParetoOptimal = (points[i].paretoRank == 1)
        }

        // 3. 提取 Rank 1 帕累托前沿集合 (按吞吐升序排列)
        var frontier = points.filter { $0.isParetoOptimal }
        frontier.sort { $0.throughputMBs < $1.throughputMBs }

        // 4. 使用 Andrew's Monotone Chain 算法计算上凸包 (Upper Convex Hull)
        let convexHull = computeUpperConvexHull(frontierPoints: frontier)
        let convexHullIds = Set(convexHull.map { $0.id })

        for i in 0..<points.count {
            if convexHullIds.contains(points[i].id) {
                points[i].isOnConvexEnvelope = true
            }
        }

        return ParetoFrontierResult(
            totalPointsEvaluated: points.count,
            frontierPoints: frontier,
            convexEnvelopePoints: convexHull,
            allPoints: points
        )
    }

    /// Andrew's Monotone Chain 计算 2D 上凸包 (Upper Convex Envelope)
    private func computeUpperConvexHull(frontierPoints: [ParetoPoint]) -> [ParetoPoint] {
        guard frontierPoints.count > 2 else {
            return frontierPoints
        }

        // frontierPoints 已经按 throughputMBs 升序排列
        var upperHull: [ParetoPoint] = []

        for p in frontierPoints {
            while upperHull.count >= 2 {
                let a = upperHull[upperHull.count - 2]
                let b = upperHull[upperHull.count - 1]
                let crossProduct = (b.throughputMBs - a.throughputMBs) * (p.spaceSavingsPct - a.spaceSavingsPct) -
                                   (b.spaceSavingsPct - a.spaceSavingsPct) * (p.throughputMBs - a.throughputMBs)
                if crossProduct >= -epsilon { // 凹折或共线，弹出次优顶点
                    upperHull.removeLast()
                } else {
                    break
                }
            }
            upperHull.append(p)
        }

        return upperHull
    }
}
