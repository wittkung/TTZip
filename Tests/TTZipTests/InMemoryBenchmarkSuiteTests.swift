// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class InMemoryBenchmarkSuiteTests: XCTestCase {

    func testInMemoryBenchmarkBasicExecution() async throws {
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["zip", "zstd", "lz4"],
            selectedLevels: [1],
            bufferSizeBytes: 2 * 1024 * 1024, // 2MB
            warmupPasses: 1,
            minDurationMs: 150,
            useBinaryUnits: false,
            turboBenchOutput: true
        )

        let report = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)

        XCTAssertTrue(report.allPassed, "All benchmark algorithms should pass roundtrip verification")
        XCTAssertEqual(report.results.count, 3, "Expected 3 algorithm results")
        
        for res in report.results {
            XCTAssertTrue(res.integrityVerified, "\(res.algorithm) roundtrip memcmp must be byte-exact")
            XCTAssertGreaterThan(res.compressionSpeedMBs, 100.0, "\(res.algorithm) compression speed should exceed 100 MB/s")
            XCTAssertGreaterThan(res.decompressionSpeedMBs, 500.0, "\(res.algorithm) decompression speed should exceed 500 MB/s")
            XCTAssertGreaterThan(res.ratio, 1.0, "\(res.algorithm) ratio should exceed 1.0x")
            XCTAssertGreaterThanOrEqual(res.spaceSavingsPct, 0.0)
            XCTAssertLessThanOrEqual(res.spaceSavingsPct, 100.0)
        }
    }

    func testInMemoryBenchmarkLowVarianceRepeatability() async throws {
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["zip"],
            selectedLevels: [1],
            bufferSizeBytes: 1 * 1024 * 1024, // 1MB
            warmupPasses: 2,
            minDurationMs: 200,
            useBinaryUnits: false
        )

        var speeds: [Double] = []
        for _ in 0..<5 {
            let rep = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)
            if let first = rep.results.first {
                speeds.append(first.compressionSpeedMBs)
            }
        }

        XCTAssertEqual(speeds.count, 5)
        let mean = speeds.reduce(0.0, +) / Double(speeds.count)
        let variance = speeds.map { pow($0 - mean, 2.0) }.reduce(0.0, +) / Double(speeds.count)
        let stdDev = sqrt(variance)
        let cv = (stdDev / mean) * 100.0 // Percentage CV

        // In pure memory execution, CV should remain highly stable (< 10% even on shared dev machine)
        XCTAssertLessThan(cv, 15.0, "Coefficient of variation should be low in pure memory mode (got \(cv)%)")
    }

    func testTurboBenchOutputFormatting() async throws {
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["zstd"],
            selectedLevels: [1],
            bufferSizeBytes: 1 * 1024 * 1024,
            warmupPasses: 1,
            minDurationMs: 100,
            turboBenchOutput: true
        )

        let report = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)
        let table = InMemoryBenchmarkEngine.shared.generateTurboBenchTable(report: report)

        XCTAssertTrue(table.contains("In-Memory Benchmark Results (TurboBench / lzbench Model / Apple Silicon RAM)"))
        XCTAssertTrue(table.contains("Algorithm"))
        XCTAssertTrue(table.contains("Zstandard"))
        XCTAssertTrue(table.contains("PASSED (OK)"))
    }

    func testJSONReportExportAndValidation() async throws {
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["lz4"],
            selectedLevels: [1],
            bufferSizeBytes: 1 * 1024 * 1024,
            warmupPasses: 1,
            minDurationMs: 100
        )

        let report = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_report_\(UUID().uuidString).json").path
        defer {
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        try InMemoryBenchmarkEngine.shared.exportJSONReport(report: report, to: tmpPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
        let decoded = try JSONDecoder().decode(BenchmarkSuiteReport.self, from: data)

        XCTAssertEqual(decoded.reportId, report.reportId)
        XCTAssertEqual(decoded.results.count, report.results.count)
        XCTAssertEqual(decoded.results.first?.algorithm, report.results.first?.algorithm)
        XCTAssertEqual(decoded.allPassed, true)
    }
}
