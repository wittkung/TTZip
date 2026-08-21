// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class MIPSHardwareBenchmarkAndParetoTests: XCTestCase {
    func testMIPSHardwareBenchmarkEngineExecution() async {
        let metric = await MIPSHardwareBenchmarkEngine.shared.runMIPSBenchmark(
            dictionarySizeMB: 1,
            threadCount: 2,
            iterations: 1
        )

        XCTAssertGreaterThan(metric.compressMIPS, 0.0)
        XCTAssertGreaterThan(metric.decompressMIPS, 0.0)
        XCTAssertGreaterThan(metric.totalMIPS, 0.0)
        XCTAssertGreaterThan(metric.compressSpeedMBs, 0.0)
        XCTAssertGreaterThan(metric.decompressSpeedMBs, 0.0)
        XCTAssertEqual(metric.dictionarySizeMB, 1)
        XCTAssertEqual(metric.threadCount, 2)
    }

    func testParetoFrontierAndConvexHullCalculation() {
        let points = [
            ParetoPoint(algorithm: "TTZip Zstd", level: 1, throughputMBs: 1200.0, spaceSavingsPct: 55.0),
            ParetoPoint(algorithm: "TTZip Zstd", level: 3, throughputMBs: 800.0, spaceSavingsPct: 62.0),
            ParetoPoint(algorithm: "TTZip Zstd", level: 9, throughputMBs: 200.0, spaceSavingsPct: 70.0),
            ParetoPoint(algorithm: "Slow Engine", level: 1, throughputMBs: 100.0, spaceSavingsPct: 40.0), // Dominated
            ParetoPoint(algorithm: "Mid Engine", level: 1, throughputMBs: 500.0, spaceSavingsPct: 56.0),  // Concave interior
        ]

        let result = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: points)

        XCTAssertEqual(result.totalPointsEvaluated, 5)
        XCTAssertFalse(result.frontierPoints.isEmpty)
        XCTAssertFalse(result.convexEnvelopePoints.isEmpty)

        // Fast Zstd Level 1, 3, 9 should be pareto optimal
        let pL1 = result.allPoints.first(where: { $0.algorithm == "TTZip Zstd" && $0.level == 1 })
        let pL9 = result.allPoints.first(where: { $0.algorithm == "TTZip Zstd" && $0.level == 9 })
        let pSlow = result.allPoints.first(where: { $0.algorithm == "Slow Engine" })

        XCTAssertNotNil(pL1)
        XCTAssertTrue(pL1!.isParetoOptimal)
        XCTAssertTrue(pL1!.isOnConvexEnvelope)

        XCTAssertNotNil(pL9)
        XCTAssertTrue(pL9!.isParetoOptimal)
        XCTAssertTrue(pL9!.isOnConvexEnvelope)

        XCTAssertNotNil(pSlow)
        XCTAssertFalse(pSlow!.isParetoOptimal)
        XCTAssertFalse(pSlow!.isOnConvexEnvelope)
    }

    func testParetoFrontierEmptyInput() {
        let result = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: [])
        XCTAssertEqual(result.totalPointsEvaluated, 0)
        XCTAssertTrue(result.frontierPoints.isEmpty)
        XCTAssertTrue(result.convexEnvelopePoints.isEmpty)
        XCTAssertTrue(result.allPoints.isEmpty)
    }

    func testCalculateCodecFrontierDirectRustABI() {
        let codecs: [(name: String, compressionRatio: Double, speedMBs: Double, memoryMB: Double)] = [
            ("Snappy", 0.50, 4000.0, 8.0),
            ("ZstdL3", 0.68, 1200.0, 32.0),
            ("LZMA2L9", 0.85, 40.0, 256.0),
            ("Dominated", 0.40, 100.0, 64.0),
        ]

        let results = ParetoFrontierCalculator.shared.calculateCodecFrontier(codecs: codecs)
        XCTAssertEqual(results.count, 4)

        let dominated = results.first(where: { r in
            var name = r.codec_name
            return withUnsafeBytes(of: &name) { buf in
                let str = String(cString: buf.baseAddress!.assumingMemoryBound(to: CChar.self))
                return str == "Dominated"
            }
        })
        XCTAssertNotNil(dominated)
        XCTAssertFalse(dominated!.is_pareto_optimal)
        XCTAssertGreaterThan(dominated!.pareto_rank, 1)

        let snappy = results.first(where: { r in
            var name = r.codec_name
            return withUnsafeBytes(of: &name) { buf in
                let str = String(cString: buf.baseAddress!.assumingMemoryBound(to: CChar.self))
                return str == "Snappy"
            }
        })
        XCTAssertNotNil(snappy)
        XCTAssertTrue(snappy!.is_pareto_optimal)
        XCTAssertTrue(snappy!.is_on_convex_hull)
    }

    func testSoftwareFamilyClassificationAndTrajectories() {
        let points = [
            ParetoPoint(algorithm: "TTZip Zstd", level: 1, throughputMBs: 1200.0, spaceSavingsPct: 55.0),
            ParetoPoint(algorithm: "Keka 7z", level: 1, throughputMBs: 100.0, spaceSavingsPct: 65.0),
            ParetoPoint(algorithm: "Meta zstd", level: 3, throughputMBs: 900.0, spaceSavingsPct: 58.0),
        ]

        let trajectories = SoftwareFamilyClassifier.groupTrajectories(from: points)
        XCTAssertFalse(trajectories.isEmpty)
        XCTAssertTrue(trajectories.contains(where: { $0.family == .ttzip }))
        XCTAssertTrue(trajectories.contains(where: { $0.family == .keka }))
    }

    func testFritschCarlsonSplineCalculator() {
        let points: [(x: Double, y: Double)] = [
            (0.0, 0.0),
            (10.0, 50.0),
            (20.0, 80.0),
            (30.0, 85.0)
        ]

        let segments = FritschCarlsonSplineCalculator.calculateBezierSegments(points: points)
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].startPoint.x, 0.0)
        XCTAssertEqual(segments[2].endPoint.x, 30.0)
    }

    func testRustMonotonicNanosAndThroughputCABI() {
        let n1 = ttzip_rust_bench_monotonic_nanos()
        Thread.sleep(forTimeInterval: 0.002)
        let n2 = ttzip_rust_bench_monotonic_nanos()
        XCTAssertGreaterThan(n2, n1)

        let mb = 1024 * 1024
        let speed = ttzip_rust_bench_calc_throughput_mbs(mb, 1.0)
        XCTAssertEqual(speed, 1.0, accuracy: 0.0001)
    }
}
