// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SVGParetoPlotterTests: XCTestCase {

    func testSVGGenerationW3CValidityAndStyles() throws {
        var points: [ParetoPoint] = [
            ParetoPoint(id: "zstd_l1", algorithm: "Zstandard", level: 1, throughputMBs: 3200, spaceSavingsPct: 62.5, compressedBytes: 375, uncompressedBytes: 1000),
            ParetoPoint(id: "lz4_l1", algorithm: "LZ4", level: 1, throughputMBs: 18000, spaceSavingsPct: 48.0, compressedBytes: 520, uncompressedBytes: 1000),
            ParetoPoint(id: "zip_l6", algorithm: "ZIP", level: 6, throughputMBs: 1200, spaceSavingsPct: 58.0, compressedBytes: 420, uncompressedBytes: 1000)
        ]

        let frontierRes = ParetoFrontierCalculator.shared.computeParetoFrontier(points: &points)
        let svg = SVGParetoPlotter.shared.generateSVG(result: frontierRes)

        // 1. 基本 W3C XML 标签闭合校验
        XCTAssertTrue(svg.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
        XCTAssertTrue(svg.hasSuffix("</svg>"))

        // 2. 检查深浅色自适应媒体查询
        XCTAssertTrue(svg.contains("@media (prefers-color-scheme: dark)"))
        XCTAssertTrue(svg.contains("--pareto-line"))

        // 3. 检查 Tooltip 与数据点
        XCTAssertTrue(svg.contains("Zstandard L1"))
        XCTAssertTrue(svg.contains("LZ4 L1"))
        XCTAssertTrue(svg.contains("👑 帕累托最优"))

        // 4. 文件体积约束 (< 25 KB)
        let utf8Bytes = svg.utf8.count
        XCTAssertLessThan(utf8Bytes, 25 * 1024, "SVG size should be well under 25KB, actual: \(utf8Bytes) bytes")

        // 5. 磁盘导出验证
        let tempPath = NSTemporaryDirectory() + "test_pareto_\(UUID().uuidString).svg"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        try SVGParetoPlotter.shared.exportSVG(result: frontierRes, to: tempPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))
    }
}
