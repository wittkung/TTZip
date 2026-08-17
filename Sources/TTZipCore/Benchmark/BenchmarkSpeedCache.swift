import Foundation

/// 格式与压缩级别组合的实测物理指标数据模型
public struct CombinationMetrics: Codable, Sendable {
    public let formatRaw: String
    public let levelRaw: Int
    public let compressThroughputMBs: Double
    public let extractThroughputMBs: Double
    public let compressionRatioPercent: Double
    public let timestamp: Date
    
    public init(
        formatRaw: String,
        levelRaw: Int,
        compressThroughputMBs: Double,
        extractThroughputMBs: Double,
        compressionRatioPercent: Double,
        timestamp: Date = Date()
    ) {
        self.formatRaw = formatRaw
        self.levelRaw = levelRaw
        self.compressThroughputMBs = compressThroughputMBs
        self.extractThroughputMBs = extractThroughputMBs
        self.compressionRatioPercent = compressionRatioPercent
        self.timestamp = timestamp
    }
}

/// 动态计算并覆盖更新存储各组合最新物理实测速度与压缩比的管理中心
public final class BenchmarkSpeedCache: @unchecked Sendable {
    public static let shared = BenchmarkSpeedCache()
    
    private let queue = DispatchQueue(label: "com.ttzip.benchmark.cache", attributes: .concurrent)
    private var metricsData: [String: CombinationMetrics] = [:]
    
    private init() {
        loadFromDisk()
    }
    
    /// 清空内存中及磁盘上的 Benchmark 速度记录与缓存 (用于测试隔离)
    public func clearCache() {
        queue.sync(flags: .barrier) {
            self.metricsData.removeAll()
            try? FileManager.default.removeItem(at: self.cacheFileURL)
        }
    }
    
    private func cacheKey(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> String {
        return "\(format.rawValue)_\(level.rawValue)"
    }
    
    /// 动态覆盖记录某组合最新单次物理实测指标 (只保留最新一轮测试结果)
    public func record(
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        compressMBs: Double,
        extractMBs: Double = 0.0,
        ratioPercent: Double = 100.0
    ) {
        guard compressMBs > 0 && !compressMBs.isNaN && !compressMBs.isInfinite else { return }
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let key = self.cacheKey(format: format, level: level)
            // 直接覆盖已有组合结果，只保留最新测试数据
            let latest = CombinationMetrics(
                formatRaw: format.rawValue,
                levelRaw: level.rawValue,
                compressThroughputMBs: compressMBs,
                extractThroughputMBs: extractMBs,
                compressionRatioPercent: ratioPercent,
                timestamp: Date()
            )
            self.metricsData[key] = latest
            self.saveToDisk()
        }
    }
    
    /// 获取某组合最新一轮测试指标
    public func getLatestMetrics(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> CombinationMetrics? {
        queue.sync {
            let key = cacheKey(format: format, level: level)
            return metricsData[key]
        }
    }
    
    /// 动态计算某格式与级别相对于该格式最新测试中最大速度的百分比 (最高实测速度标为 100%)
    public func relativeSpeedPercentage(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Int {
        return queue.sync {
            let key = cacheKey(format: format, level: level)
            let current = metricsData[key]?.compressThroughputMBs ?? 0.0
            
            var maxSpeed = 0.0
            for l in ArchiveCompressionLevel.allCases {
                let k = cacheKey(format: format, level: l)
                if let m = metricsData[k], m.compressThroughputMBs > maxSpeed {
                    maxSpeed = m.compressThroughputMBs
                }
            }
            
            if maxSpeed > 0 && current > 0 {
                let pct = Int(round((current / maxSpeed) * 100.0))
                return max(1, min(100, pct))
            }
            
            return defaultDynamicSpeedFallback(format: format, level: level)
        }
    }
    
    /// 获取某组合最新测试的压缩体积比 (%)，若未跑测则按估计衰减返回
    public func compressionRatioPercent(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Double {
        return queue.sync {
            let key = cacheKey(format: format, level: level)
            if let m = metricsData[key] {
                return m.compressionRatioPercent
            }
            return defaultDynamicRatioFallback(format: format, level: level)
        }
    }
    
    /// 实测相对压缩体积与节省空间标注徽章 (例 "体积 31.5%" 或 "省 68.5%")
    public func ratioBadge(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> String {
        let r = compressionRatioPercent(format: format, level: level)
        let saved = max(0.0, 100.0 - r)
        if level == .store || r >= 99.9 {
            return "100% 体积"
        }
        return String(format: "体积 %.1f%% (省 %.1f%%)", r, saved)
    }
    
    /// 未获取物理实测值时的动态速度衰减预估
    private func defaultDynamicSpeedFallback(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Int {
        if level == .store { return 100 }
        let decayPerLevel: Double
        switch format {
        case .zst, .tarZst: decayPerLevel = 4.5
        case .zip: decayPerLevel = 5.5
        case .sevenZip: decayPerLevel = 8.0
        default: decayPerLevel = 5.0
        }
        let pct = Int(round(100.0 - (Double(level.rawValue) * decayPerLevel)))
        return max(10, min(100, pct))
    }
    
    /// 未获取物理实测值时的动态体积压缩比预估
    private func defaultDynamicRatioFallback(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Double {
        if level == .store { return 100.0 }
        let baseRatio: Double
        switch format {
        case .sevenZip: baseRatio = 35.0
        case .zst, .tarZst: baseRatio = 32.0
        case .zip: baseRatio = 38.0
        default: baseRatio = 36.0
        }
        let levelImprovement = Double(level.rawValue) * 0.8
        return max(5.0, baseRatio - levelImprovement)
    }
    
    /// 批量覆盖持久化最新全维度测试结果 JSON 报告
    public func saveFullReport(rows: [ExhaustiveBenchmarkRow]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for row in rows {
                let key = self.cacheKey(format: row.format, level: row.level)
                // 每次跑测直接覆盖原组合，只保留最新测试数据
                let latest = CombinationMetrics(
                    formatRaw: row.format.rawValue,
                    levelRaw: row.level.rawValue,
                    compressThroughputMBs: row.compressThroughputMBs,
                    extractThroughputMBs: row.extractThroughputMBs,
                    compressionRatioPercent: row.compressionRatioPercent,
                    timestamp: Date()
                )
                self.metricsData[key] = latest
            }
            self.saveToDisk()
            
            let reportURL = self.fullReportFileURL
            if let data = try? JSONCoderCache.shared.prettyEncoder.encode(rows) {
                try? data.write(to: reportURL)
            }
        }
    }
    
    public var fullReportFileURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths.first?.appendingPathComponent("TTZip", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("exhaustive_benchmark_latest.json")
    }
    
    // MARK: - Disk Persistence
    
    private var cacheFileURL: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent("ttzip_benchmark_metrics_latest.json")
    }
    
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let dict = try? JSONCoderCache.shared.decoder.decode([String: CombinationMetrics].self, from: data) else { return }
        self.metricsData = dict
    }
    
    private func saveToDisk() {
        guard let data = try? JSONCoderCache.shared.encoder.encode(metricsData) else { return }
        try? data.write(to: cacheFileURL)
    }
}
