// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// In-memory compression benchmark engine verification and multi-codec PK test suite.
final class InMemoryBenchmarkSuiteTests: XCTestCase {

    /// Verifies basic in-memory execution and roundtrip byte-exactness across multiple codecs.
    func testInMemoryBenchmarkBasicExecution() async throws {
        let minDuration = TestBenchmarkTier.isBenchmarkMode ? 150 : 20
        let bufSize: Int64 = TestBenchmarkTier.isBenchmarkMode ? (1 * 1024 * 1024) : (256 * 1024)
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["zip", "zstd", "lz4"],
            selectedLevels: [1],
            bufferSizeBytes: bufSize,
            warmupPasses: 1,
            minDurationMs: minDuration,
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

    /// Verifies low coefficient of variation across repeated in-memory benchmark passes.
    func testInMemoryBenchmarkLowVarianceRepeatability() async throws {
        let minDuration = TestBenchmarkTier.isBenchmarkMode ? 200 : 20
        let bufSize: Int64 = TestBenchmarkTier.isBenchmarkMode ? (1 * 1024 * 1024) : (256 * 1024)
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["zip"],
            selectedLevels: [1],
            bufferSizeBytes: bufSize,
            warmupPasses: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            minDurationMs: minDuration,
            useBinaryUnits: false
        )

        let rounds = TestBenchmarkTier.benchmarkIterations(default: 2, benchmark: 5)
        var speeds: [Double] = []
        for _ in 0..<rounds {
            let rep = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)
            if let first = rep.results.first {
                speeds.append(first.compressionSpeedMBs)
            }
        }

        XCTAssertEqual(speeds.count, rounds)
        let mean = speeds.reduce(0.0, +) / Double(speeds.count)
        let variance = speeds.map { pow($0 - mean, 2.0) }.reduce(0.0, +) / Double(speeds.count)
        let stdDev = sqrt(variance)
        let cv = (stdDev / mean) * 100.0 // Percentage CV

        // In pure memory execution, CV should remain highly stable (< 15% on shared dev machine)
        XCTAssertLessThan(cv, 15.0, "Coefficient of variation should be low in pure memory mode (got \(cv)%)")
    }

    /// Tests TurboBench-style tabular output string generation.
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

    /// Tests JSON report file serialization and schema consistency.
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

    /// Multi-codec in-memory PK benchmark comparing Google Snappy against LZ4, Deflate, and Zstandard.
    func testSnappyInMemoryComparisonAgainstFastCodecs() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Benchmark test requires TTZIP_RUN_BENCHMARKS=1")
        }
        let config = InMemoryBenchmarkConfig(
            selectedFormats: ["snappy", "lz4", "zip", "zstd"],
            selectedLevels: [1],
            bufferSizeBytes: 10 * 1024 * 1024, // 10MB
            warmupPasses: 2,
            minDurationMs: 200,
            useBinaryUnits: false,
            turboBenchOutput: true
        )

        let report = try await InMemoryBenchmarkEngine.shared.runInMemoryBenchmark(config: config)
        let table = InMemoryBenchmarkEngine.shared.generateTurboBenchTable(report: report)
        TTLogger.debug("\n" + table + "\n")

        XCTAssertTrue(report.allPassed)
        XCTAssertEqual(report.results.count, 4)

        if let snappyRes = report.results.first(where: { $0.algorithm == "Google-Snappy" }) {
            XCTAssertTrue(snappyRes.integrityVerified)
            TTLogger.debug("🚀 [PHYSICAL BENCHMARK RESULT] Google Snappy: Comp=\(String(format: "%.1f", snappyRes.compressionSpeedMBs)) MB/s, Decomp=\(String(format: "%.1f", snappyRes.decompressionSpeedMBs)) MB/s, Ratio=\(String(format: "%.2fx", snappyRes.ratio))")
        }
    }
}
