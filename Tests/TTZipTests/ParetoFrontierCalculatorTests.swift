// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ParetoFrontierCalculatorTests: XCTestCase {

    func testParetoFrontierBasicDomination() {
        // Points: (Throughput MB/s, Space Savings %)
        // P1: (1000, 50%) -> Dominates P2 (500, 30%)
        // P3: (2000, 20%) -> Trade-off with P1 (Faster but less ratio)
        // P4: (400, 60%)  -> Trade-off with P1 (Higher ratio but slower)
        // P5: (300, 40%)  -> Dominated by P4 and P1
        var points: [ParetoPoint] = [
            ParetoPoint(id: "p1", algorithm: "Algo1", level: 1, throughputMBs: 1000, spaceSavingsPct: 50, compressedBytes: 50, uncompressedBytes: 100),
            ParetoPoint(id: "p2", algorithm: "Algo2", level: 1, throughputMBs: 500, spaceSavingsPct: 30, compressedBytes: 70, uncompressedBytes: 100),
            ParetoPoint(id: "p3", algorithm: "Algo3", level: 1, throughputMBs: 2000, spaceSavingsPct: 20, compressedBytes: 80, uncompressedBytes: 100),
            ParetoPoint(id: "p4", algorithm: "Algo4", level: 1, throughputMBs: 400, spaceSavingsPct: 60, compressedBytes: 40, uncompressedBytes: 100),
            ParetoPoint(id: "p5", algorithm: "Algo5", level: 1, throughputMBs: 300, spaceSavingsPct: 40, compressedBytes: 60, uncompressedBytes: 100)
        ]

        let result = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &points)

        XCTAssertEqual(result.totalPointsEvaluated, 5)
        
        let frontierIds = Set(result.frontierPoints.map { $0.id })
        XCTAssertTrue(frontierIds.contains("p1"), "P1 should be Pareto optimal")
        XCTAssertTrue(frontierIds.contains("p3"), "P3 should be Pareto optimal")
        XCTAssertTrue(frontierIds.contains("p4"), "P4 should be Pareto optimal")
        XCTAssertFalse(frontierIds.contains("p2"), "P2 is dominated and should not be on frontier")
        XCTAssertFalse(frontierIds.contains("p5"), "P5 is dominated and should not be on frontier")

        // Frontier should be sorted by throughput ascending: p4(400) -> p1(1000) -> p3(2000)
        XCTAssertEqual(result.frontierPoints.map { $0.id }, ["p4", "p1", "p3"])
    }

    func testTerminalBraillePlotterOutput() {
        var points: [ParetoPoint] = [
            ParetoPoint(id: "p1", algorithm: "ZSTD", level: 1, throughputMBs: 3000, spaceSavingsPct: 65, compressedBytes: 35, uncompressedBytes: 100),
            ParetoPoint(id: "p2", algorithm: "LZ4", level: 1, throughputMBs: 15000, spaceSavingsPct: 45, compressedBytes: 55, uncompressedBytes: 100),
            ParetoPoint(id: "p3", algorithm: "7Z-LZMA2", level: 9, throughputMBs: 400, spaceSavingsPct: 78, compressedBytes: 22, uncompressedBytes: 100)
        ]

        let res = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &points)
        let plot = TerminalParetoPlotter.shared.renderTerminalPlot(result: res, widthChars: 60, heightChars: 15)

        XCTAssertTrue(plot.contains("帕累托最优前沿分析图"))
        XCTAssertTrue(plot.contains("ZSTD"))
        XCTAssertTrue(plot.contains("LZ4"))
        XCTAssertTrue(plot.contains("7Z-LZMA2"))
        XCTAssertTrue(plot.contains("10 MB/s"))
    }
}
