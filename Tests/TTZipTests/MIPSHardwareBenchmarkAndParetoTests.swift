// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

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
}
