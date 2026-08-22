// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import CTTZipBridge

/// 2D 帕累托非支配前沿与凸包包络线计算中枢 (2D Skyline & Monotone Chain Algorithm)
public final class ParetoFrontierCalculator: @unchecked Sendable {
    public static let shared = ParetoFrontierCalculator()
    private init() {}

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

    /// 计算指定编解码器配置集合的 2D 帕累托上凸包与最优前沿
    public func calculateCodecFrontier(
        codecs: [(name: String, compressionRatio: Double, speedMBs: Double, memoryMB: Double)]
    ) -> [TTZipParetoCodecPointRaw] {
        guard !codecs.isEmpty else { return [] }

        var rawPoints = [TTZipParetoCodecPointRaw]()
        rawPoints.reserveCapacity(codecs.count)

        for c in codecs {
            var raw = TTZipParetoCodecPointRaw()
            var nameBuf = (
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0),
                CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0), CChar(0)
            )
            withUnsafeMutableBytes(of: &nameBuf) { buf in
                let cStr = c.name.utf8CString
                let copyLen = min(buf.count - 1, cStr.count)
                for i in 0..<copyLen {
                    buf[i] = UInt8(bitPattern: cStr[i])
                }
            }
            raw.codec_name = nameBuf
            raw.compression_ratio = c.compressionRatio
            raw.speed_mb_s = c.speedMBs
            raw.memory_mb = c.memoryMB
            raw.pareto_rank = 1
            raw.is_pareto_optimal = false
            raw.is_on_convex_hull = false
            rawPoints.append(raw)
        }

        let st = rawPoints.withUnsafeMutableBufferPointer { bufPtr in
            ttzip_rust_calculate_pareto_frontier(bufPtr.baseAddress, bufPtr.count)
        }

        guard st == TTZIP_STATUS_OK else {
            return []
        }
        return rawPoints
    }
}
