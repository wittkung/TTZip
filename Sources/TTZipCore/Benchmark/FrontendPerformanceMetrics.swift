import Foundation

/// 目录树构建性能指标
public struct TreeBuildMetric: Codable, Sendable, Equatable {
    public let entryCount: Int
    public let rootNodeCount: Int
    public let durationMs: Double
    public let throughputItemsPerSec: Double
    
    public init(entryCount: Int, rootNodeCount: Int, durationMs: Double) {
        self.entryCount = entryCount
        self.rootNodeCount = rootNodeCount
        self.durationMs = max(0.0001, durationMs)
        self.throughputItemsPerSec = (Double(entryCount) / (self.durationMs / 1000.0))
    }
}

/// 搜索与过滤性能指标
public struct SearchFilterMetric: Codable, Sendable, Equatable {
    public let datasetSize: Int
    public let query: String
    public let matchedCount: Int
    public let durationMs: Double
    public let filterThroughputItemsPerSec: Double
    
    public init(datasetSize: Int, query: String, matchedCount: Int, durationMs: Double) {
        self.datasetSize = datasetSize
        self.query = query
        self.matchedCount = matchedCount
        self.durationMs = max(0.0001, durationMs)
        self.filterThroughputItemsPerSec = (Double(datasetSize) / (self.durationMs / 1000.0))
    }
}

/// LRU 内存缓存性能指标
public struct LRUCacheMetric: Codable, Sendable, Equatable {
    public let operationsCount: Int
    public let capacity: Int
    public let durationMs: Double
    public let opsPerSec: Double
    public let hitRatio: Double
    
    public init(operationsCount: Int, capacity: Int, durationMs: Double, hitRatio: Double) {
        self.operationsCount = operationsCount
        self.capacity = capacity
        self.durationMs = max(0.0001, durationMs)
        self.opsPerSec = (Double(operationsCount) / (self.durationMs / 1000.0))
        self.hitRatio = max(0.0, min(1.0, hitRatio))
    }
}

/// 进度更新节流性能指标
public struct ProgressThrottleMetric: Codable, Sendable, Equatable {
    public let totalEvents: Int
    public let emittedEvents: Int
    public let throttledEvents: Int
    public let suppressionRatio: Double
    public let durationMs: Double
    
    public init(totalEvents: Int, emittedEvents: Int, durationMs: Double) {
        self.totalEvents = totalEvents
        self.emittedEvents = emittedEvents
        self.throttledEvents = max(0, totalEvents - emittedEvents)
        self.suppressionRatio = totalEvents > 0 ? (Double(self.throttledEvents) / Double(totalEvents)) * 100.0 : 0.0
        self.durationMs = max(0.0001, durationMs)
    }
}

/// 前端性能全套基准测试汇总报告
public struct FrontendPerformanceReport: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let hardwareSummary: String
    public let treeBuildMetrics: [TreeBuildMetric]
    public let searchFilterMetrics: [SearchFilterMetric]
    public let lruCacheMetrics: [LRUCacheMetric]
    public let throttleMetrics: [ProgressThrottleMetric]
    public let isAllPassed: Bool
    
    public init(
        timestamp: Date = Date(),
        hardwareSummary: String,
        treeBuildMetrics: [TreeBuildMetric],
        searchFilterMetrics: [SearchFilterMetric],
        lruCacheMetrics: [LRUCacheMetric],
        throttleMetrics: [ProgressThrottleMetric],
        isAllPassed: Bool
    ) {
        self.timestamp = timestamp
        self.hardwareSummary = hardwareSummary
        self.treeBuildMetrics = treeBuildMetrics
        self.searchFilterMetrics = searchFilterMetrics
        self.lruCacheMetrics = lruCacheMetrics
        self.throttleMetrics = throttleMetrics
        self.isAllPassed = isAllPassed
    }
}
