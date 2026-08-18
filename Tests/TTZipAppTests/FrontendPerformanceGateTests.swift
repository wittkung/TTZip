// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class FrontendPerformanceGateTests: XCTestCase {
    
    // MARK: - 1. Tree Construction Latency Hard Floor Gate
    
    func testTreeBuildHardPerformanceFloor() async {
        let runner = FrontendBenchmarkRunner.shared
        
        let metrics = await runner.runTreeBuildBenchmark(entryCounts: [1000, 10000, 50000])
        XCTAssertEqual(metrics.count, 3)
        
        // 1k nodes build gate: <= 10ms
        let m1k = metrics[0]
        XCTAssertLessThanOrEqual(
            m1k.durationMs,
            10.0,
            "1,000 nodes tree build duration (\(m1k.durationMs)ms) exceeded 10ms gate floor"
        )
        
        // 10k nodes build gate: <= 60ms
        let m10k = metrics[1]
        XCTAssertLessThanOrEqual(
            m10k.durationMs,
            60.0,
            "10,000 nodes tree build duration (\(m10k.durationMs)ms) exceeded 60ms gate floor"
        )
        
        // 50k nodes build gate: <= 250ms (Debug environment), >= 200,000 items/s
        let m50k = metrics[2]
        XCTAssertLessThanOrEqual(
            m50k.durationMs,
            250.0,
            "50,000 nodes tree build duration (\(m50k.durationMs)ms) exceeded 250ms gate floor"
        )
        XCTAssertGreaterThanOrEqual(
            m50k.throughputItemsPerSec,
            200_000.0,
            "50,000 nodes tree build throughput (\(m50k.throughputItemsPerSec) items/s) below 200,000 items/s floor"
        )
    }

    
    // MARK: - 2. Search and Filter Throughput Hard Floor Gate
    
    func testSearchFilterThroughputHardFloor() async {
        let runner = FrontendBenchmarkRunner.shared
        let metrics = await runner.runSearchFilterBenchmark(datasetSize: 20000, queries: ["file_100", "Folder_2", "sub"])
        
        XCTAssertEqual(metrics.count, 3)
        for m in metrics {
            XCTAssertLessThanOrEqual(
                m.durationMs,
                30.0,
                "20,000 items search [\(m.query)] duration (\(m.durationMs)ms) exceeded 30ms gate floor"
            )
            XCTAssertGreaterThanOrEqual(
                m.filterThroughputItemsPerSec,
                750_000.0,
                "20,000 items search [\(m.query)] throughput (\(m.filterThroughputItemsPerSec) items/s) below 750,000 items/s floor"
            )
        }
    }

    
    // MARK: - 3. LRU Memory Cache Operations and Eviction Throughput Gate
    
    func testLRUCacheOperationsHardFloor() {
        let cache = ExplorerLRUCache<Int, String>(capacity: 64)
        let opsCount = 10000
        
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for i in 0..<opsCount {
                cache.set(i % 128, value: "Item_\(i)")
                _ = cache.get(i % 128)
            }
        }
        
        let durationMs = Double(elapsed.components.seconds) * 1000.0 + (Double(elapsed.components.attoseconds) / 1e15)
        let opsPerSec = Double(opsCount * 2) / (durationMs / 1000.0)
        
        // Strict O(1) floor: 10,000 ops <= 8ms, throughput >= 1,500,000 ops/s
        XCTAssertLessThanOrEqual(
            durationMs,
            8.0,
            "10,000 LRU cache ops duration (\(durationMs)ms) exceeded 8ms gate floor"
        )
        XCTAssertGreaterThanOrEqual(
            opsPerSec,
            1_500_000.0,
            "LRU cache operation throughput (\(opsPerSec) ops/s) below 1,500,000 ops/s floor"
        )
    }
    
    // MARK: - 4. High-Frequency Progress Event Throttling Suppression Rate Gate
    
    func testProgressThrottleSuppressionHardFloor() async {
        let throttler = ThrottledProgressPublisher(maxFrequencyHz: 60.0)
        let totalEvents = 10000
        var emittedCount = 0
        
        var currentNano: UInt64 = 1_000_000_000
        for _ in 0..<totalEvents {
            currentNano += 1000
            if throttler.shouldEmit(now: currentNano) {
                emittedCount += 1
            }
        }
        
        let metric = ProgressThrottleMetric(totalEvents: totalEvents, emittedEvents: emittedCount, durationMs: 10.0)
        XCTAssertGreaterThanOrEqual(
            metric.suppressionRatio,
            97.0,
            "Progress throttle suppression ratio (\(metric.suppressionRatio)%) below 97% gate floor"
        )
        XCTAssertLessThanOrEqual(
            emittedCount,
            300,
            "10,000 microsecond-level events emitted count (\(emittedCount)) exceeded 300 threshold"
        )
    }
    
    // MARK: - 5. Full Frontend Performance Suite Report Verification
    
    func testFullFrontendSuiteReportGeneration() async {
        let runner = FrontendBenchmarkRunner.shared
        let report = await runner.runFullFrontendSuite()
        
        XCTAssertFalse(report.hardwareSummary.isEmpty)
        XCTAssertFalse(report.treeBuildMetrics.isEmpty)
        XCTAssertFalse(report.searchFilterMetrics.isEmpty)
        XCTAssertFalse(report.throttleMetrics.isEmpty)
        XCTAssertTrue(report.isAllPassed)
    }
}
