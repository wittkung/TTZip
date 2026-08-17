import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class FrontendPerformanceGateTests: XCTestCase {
    
    // MARK: - 1. 目录树构建延迟硬门禁测试 (Tree Construction Latency Floor)
    
    func testTreeBuildHardPerformanceFloor() async {
        let runner = FrontendBenchmarkRunner.shared
        
        let metrics = await runner.runTreeBuildBenchmark(entryCounts: [1000, 10000, 50000])
        XCTAssertEqual(metrics.count, 3)
        
        // 1k 节点构建门禁: <= 10ms
        let m1k = metrics[0]
        XCTAssertLessThanOrEqual(
            m1k.durationMs,
            10.0,
            "1,000 节点目录树构建耗时 (\(m1k.durationMs)ms) 超过 10ms 门禁底线"
        )
        
        // 10k 节点构建门禁: <= 60ms
        let m10k = metrics[1]
        XCTAssertLessThanOrEqual(
            m10k.durationMs,
            60.0,
            "10,000 节点目录树构建耗时 (\(m10k.durationMs)ms) 超过 60ms 门禁底线"
        )
        
        // 50k 节点构建门禁: <= 250ms (Debug 环境), >= 250,000 items/s
        let m50k = metrics[2]
        XCTAssertLessThanOrEqual(
            m50k.durationMs,
            250.0,
            "50,000 节点目录树构建耗时 (\(m50k.durationMs)ms) 超过 250ms 门禁底线"
        )
        XCTAssertGreaterThanOrEqual(
            m50k.throughputItemsPerSec,
            250_000.0,
            "50,000 节点目录树构建吞吐 (\(m50k.throughputItemsPerSec) items/s) 低于 250,000 items/s 底线"
        )
    }

    
    // MARK: - 2. 搜索与过滤吞吐硬门禁测试 (Search Filter Throughput Floor)
    
    func testSearchFilterThroughputHardFloor() async {
        let runner = FrontendBenchmarkRunner.shared
        let metrics = await runner.runSearchFilterBenchmark(datasetSize: 20000, queries: ["file_100", "Folder_2", "sub"])
        
        XCTAssertEqual(metrics.count, 3)
        for m in metrics {
            XCTAssertLessThanOrEqual(
                m.durationMs,
                30.0,
                "20,000 条目搜索 [\(m.query)] 耗时 (\(m.durationMs)ms) 超过 30ms 门禁底线"
            )
            XCTAssertGreaterThanOrEqual(
                m.filterThroughputItemsPerSec,
                750_000.0,
                "20,000 条目搜索 [\(m.query)] 吞吐 (\(m.filterThroughputItemsPerSec) items/s) 低于 750,000 items/s 底线"
            )
        }
    }

    
    // MARK: - 3. LRU 内存缓存存取与淘汰吞吐门禁 (LRU Cache Operations Floor)
    
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
        
        // 极致 O(1) 硬门禁：10,000 次读写耗时 <= 8ms，吞吐 >= 1,500,000 ops/s
        XCTAssertLessThanOrEqual(
            durationMs,
            8.0,
            "10,000 次 LRU 缓存存取耗时 (\(durationMs)ms) 超过 8ms 门禁底线"
        )
        XCTAssertGreaterThanOrEqual(
            opsPerSec,
            1_500_000.0,
            "LRU 缓存操作吞吐 (\(opsPerSec) ops/s) 低于 1,500,000 ops/s 底线"
        )
    }
    
    // MARK: - 4. 高频进度节流拦截率门禁 (Progress Throttle Suppression Floor)
    
    func testProgressThrottleSuppressionHardFloor() async {
        let throttler = ThrottledProgressPublisher(maxFrequencyHz: 60.0)
        let totalEvents = 10000
        var emittedCount = 0
        
        var currentNano: UInt64 = 1_000_000_000
        for _ in 0..<totalEvents {
            currentNano += 1000 // 模拟每微秒到达一个事件
            if throttler.shouldEmit(now: currentNano) {
                emittedCount += 1
            }
        }
        
        let metric = ProgressThrottleMetric(totalEvents: totalEvents, emittedEvents: emittedCount, durationMs: 10.0)
        XCTAssertGreaterThanOrEqual(
            metric.suppressionRatio,
            97.0,
            "高频事件节流拦截率 (\(metric.suppressionRatio)%) 低于 97% 门禁底线"
        )
        XCTAssertLessThanOrEqual(
            emittedCount,
            300,
            "10,000 次微秒级高频事件放行数 (\(emittedCount)) 超过 300 阈值"
        )
    }
    
    // MARK: - 5. 全套前端基准测试执行器验证
    
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
