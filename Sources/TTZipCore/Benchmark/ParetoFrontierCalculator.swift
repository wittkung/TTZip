// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 2D 帕累托非支配前沿与凸包包络线计算中枢 (2D Skyline & Monotone Chain Algorithm)
///
/// Backed by high-performance Rust core `compute_pareto_frontier_raw` ($O(N \log K)$ Dilworth's Theorem & $O(M \log M)$ Monotone Chain).
public final class ParetoFrontierCalculator: @unchecked Sendable {
    public static let shared = ParetoFrontierCalculator()
    private init() {}

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

        var points: [ParetoPoint] = benchmarkResults.map { r in
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

    /// 从直接构造的 ParetoPoint 数组中提取帕累托前沿
    public func calculateFrontierFromPoints(points: [ParetoPoint]) -> ParetoFrontierResult {
        var copy = points
        return computeParetoFrontier(points: &copy)
    }

    /// 执行 2D 扫描线与 Patience Binary Search 确定多级帕累托层级与上凸包
    public func computeParetoFrontier(points: inout [ParetoPoint]) -> ParetoFrontierResult {
        guard !points.isEmpty else {
            return ParetoFrontierResult(
                totalPointsEvaluated: 0,
                frontierPoints: [],
                convexEnvelopePoints: [],
                allPoints: []
            )
        }

        // Bridge to high-performance Rust core algorithm
        var rawPoints = [TTZipParetoPointRaw](repeating: TTZipParetoPointRaw(), count: points.count)
        for i in 0..<points.count {
            rawPoints[i] = TTZipParetoPointRaw(
                tag: UInt64(i),
                throughput_mbs: points[i].throughputMBs,
                space_savings_pct: points[i].spaceSavingsPct,
                pareto_rank: 1,
                is_pareto_optimal: false,
                is_on_convex_envelope: false
            )
        }

        let st = rawPoints.withUnsafeMutableBufferPointer { bufPtr in
            ttzip_rust_bench_compute_pareto_frontier(bufPtr.baseAddress, bufPtr.count)
        }

        if st == TTZIP_STATUS_OK {
            // Rust sorts the raw points in-place by (throughput desc, space savings desc)
            var reorderedPoints = [ParetoPoint]()
            reorderedPoints.reserveCapacity(rawPoints.count)

            for rp in rawPoints {
                let origIdx = Int(rp.tag)
                var pt = points[origIdx]
                pt.paretoRank = Int(rp.pareto_rank)
                pt.isParetoOptimal = rp.is_pareto_optimal
                pt.isOnConvexEnvelope = rp.is_on_convex_envelope
                reorderedPoints.append(pt)
            }
            points = reorderedPoints
        }

        var frontier = points.filter { $0.isParetoOptimal }
        frontier.sort { $0.throughputMBs < $1.throughputMBs }

        var convexHull = points.filter { $0.isOnConvexEnvelope }
        convexHull.sort { $0.throughputMBs < $1.throughputMBs }

        return ParetoFrontierResult(
            totalPointsEvaluated: points.count,
            frontierPoints: frontier,
            convexEnvelopePoints: convexHull,
            allPoints: points
        )
    }
}
