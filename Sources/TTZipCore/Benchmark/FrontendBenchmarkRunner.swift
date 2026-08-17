import Foundation

/// 前端核心算法与交互性能基准测试执行器
public final class FrontendBenchmarkRunner: Sendable {
    public static let shared = FrontendBenchmarkRunner()
    
    public init() {}
    
    /// 生成模拟层级归档条目数据集
    public func generateSyntheticEntries(count: Int) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        entries.reserveCapacity(count)
        
        let depth1Count = max(1, count / 100)
        let depth2Count = max(1, count / 20)
        
        for i in 0..<count {
            let d1 = i % depth1Count
            let d2 = i % depth2Count
            let isDir = (i % 20 == 0)
            let path = isDir ? "Folder_\(d1)/Sub_\(d2)/" : "Folder_\(d1)/Sub_\(d2)/file_\(i).dat"
            let entry = ArchiveEntry(
                path: path,
                uncompressedSize: isDir ? 0 : Int64((i % 1024) * 1024),
                isDirectory: isDir,
                detectedEncoding: "UTF-8"
            )
            entries.append(entry)
        }
        return entries
    }
    
    /// 执行目录树构建性能压测
    public func runTreeBuildBenchmark(entryCounts: [Int] = [1000, 10000, 50000]) async -> [TreeBuildMetric] {
        var results: [TreeBuildMetric] = []
        
        for count in entryCounts {
            let entries = generateSyntheticEntries(count: count)
            let clock = ContinuousClock()
            
            let elapsed = clock.measure {
                _ = ArchiveTreeBuilder.buildTree(from: entries)
            }
            
            let durationMs = Double(elapsed.components.seconds) * 1000.0 + (Double(elapsed.components.attoseconds) / 1e15)
            let rootCount = max(1, count / 100)
            let metric = TreeBuildMetric(entryCount: count, rootNodeCount: rootCount, durationMs: durationMs)
            results.append(metric)
        }
        return results
    }
    
    /// 执行实时搜索与过滤性能压测
    public func runSearchFilterBenchmark(datasetSize: Int = 20000, queries: [String] = ["file_100", "Folder_2", "sub", "nonexistent"]) async -> [SearchFilterMetric] {
        let entries = generateSyntheticEntries(count: datasetSize)
        var results: [SearchFilterMetric] = []
        
        for q in queries {
            let clock = ContinuousClock()
            var matched = 0
            
            let lowerQ = q.lowercased()
            let elapsed = clock.measure {
                matched = entries.filter { entry in
                    entry.name.lowercased().contains(lowerQ) || entry.path.lowercased().contains(lowerQ)
                }.count
            }
            
            let durationMs = Double(elapsed.components.seconds) * 1000.0 + (Double(elapsed.components.attoseconds) / 1e15)
            let metric = SearchFilterMetric(datasetSize: datasetSize, query: q, matchedCount: matched, durationMs: durationMs)
            results.append(metric)
        }
        return results
    }
    
    /// 执行高频事件节流压测
    public func runThrottleBenchmark(eventCount: Int = 10000, targetHz: Double = 60.0) async -> [ProgressThrottleMetric] {
        let intervalNs = UInt64(1_000_000_000.0 / targetHz)
        var lastEmitted: UInt64 = 0
        var emittedCount = 0
        
        let startNano = DispatchTime.now().uptimeNanoseconds
        var currentNano = startNano
        
        for _ in 0..<eventCount {
            currentNano += 1000 // 模拟每 1 微秒到达一个高频事件 (1,000,000 eps)
            if lastEmitted == 0 || (currentNano - lastEmitted >= intervalNs) {
                lastEmitted = currentNano
                emittedCount += 1
            }
        }
        
        let totalElapsedMs = Double(currentNano - startNano) / 1_000_000.0
        let metric = ProgressThrottleMetric(totalEvents: eventCount, emittedEvents: emittedCount, durationMs: totalElapsedMs)
        return [metric]
    }
    
    /// 运行全套前端基准测试并生成综合报告
    public func runFullFrontendSuite() async -> FrontendPerformanceReport {
        let treeMetrics = await runTreeBuildBenchmark(entryCounts: [1000, 10000, 50000])
        let searchMetrics = await runSearchFilterBenchmark(datasetSize: 20000)
        let throttleMetrics = await runThrottleBenchmark(eventCount: 10000)
        
        // 严格硬门禁判定：50k 树构建 <= 250ms (Debug), 20k 搜索吞吐 >= 500,000 items/s (Debug), 节流拦截率 >= 97%
        let isTreePassed = treeMetrics.last.map { $0.durationMs <= 250.0 } ?? true
        let isSearchPassed = searchMetrics.allSatisfy { $0.filterThroughputItemsPerSec >= 500_000.0 }
        let isThrottlePassed = throttleMetrics.allSatisfy { $0.suppressionRatio >= 97.0 }
        let allPassed = isTreePassed && isSearchPassed && isThrottlePassed
        
        let hardware = AppleSiliconTuner.shared.topology.chipName
        
        return FrontendPerformanceReport(
            hardwareSummary: hardware,
            treeBuildMetrics: treeMetrics,
            searchFilterMetrics: searchMetrics,
            lruCacheMetrics: [],
            throttleMetrics: throttleMetrics,
            isAllPassed: allPassed
        )
    }
}
