// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Metric model for format and compression level combinations.
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

/// Dynamic benchmark speed and ratio cache management subsystem.
public final class BenchmarkSpeedCache: @unchecked Sendable {
    public static let shared = BenchmarkSpeedCache()
    
    private let lock = NSLock()
    private var metricsData: [String: CombinationMetrics] = [:]
    
    private init() {
        loadFromDisk()
    }
    
    /// Clears cached metrics in memory and on disk.
    public func clearCache() {
        lock.withLock {
            self.metricsData.removeAll()
            try? FileManager.default.removeItem(at: self.cacheFileURL)
        }
    }
    
    private func cacheKey(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> String {
        return "\(format.rawValue)_\(level.rawValue)"
    }
    
    /// Dynamically records physical throughput and ratio metrics for a format and level combination.
    public func record(
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        compressMBs: Double,
        extractMBs: Double = 0.0,
        ratioPercent: Double = 100.0
    ) {
        guard compressMBs > 0 && !compressMBs.isNaN && !compressMBs.isInfinite else { return }
        lock.withLock {
            let key = self.cacheKey(format: format, level: level)
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
    
    /// Retrieves latest metrics for target format and compression level.
    public func getLatestMetrics(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> CombinationMetrics? {
        lock.withLock {
            let key = cacheKey(format: format, level: level)
            return metricsData[key]
        }
    }
    
    /// Calculates relative speed percentage compared to maximum observed throughput for the format (100% = max throughput).
    public func relativeSpeedPercentage(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Int {
        return lock.withLock {
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
    
    /// Retrieves latest compression ratio percentage for target format and level.
    public func compressionRatioPercent(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> Double {
        return lock.withLock {
            let key = cacheKey(format: format, level: level)
            if let m = metricsData[key] {
                return m.compressionRatioPercent
            }
            return defaultDynamicRatioFallback(format: format, level: level)
        }
    }
    
    /// Returns formatted ratio badge string.
    public func ratioBadge(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel) -> String {
        let r = compressionRatioPercent(format: format, level: level)
        let saved = max(0.0, 100.0 - r)
        if level == .store || r >= 99.9 {
            return "100% Size"
        }
        return String(format: "%.1f%% Size (%.1f%% Saved)", r, saved)
    }
    
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
    
    /// Batch persists comprehensive benchmark report JSON to disk.
    public func saveFullReport(rows: [ExhaustiveBenchmarkRow]) {
        lock.withLock {
            for row in rows {
                let key = self.cacheKey(format: row.format, level: row.level)
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
