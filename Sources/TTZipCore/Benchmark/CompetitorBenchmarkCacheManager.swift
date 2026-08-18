// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 外部竞品基准测试持久化缓存条目
public struct CompetitorCacheEntry: Codable, Sendable {
    public let toolId: String
    public let algorithm: String
    public let level: Int
    public let datasetSha256: String
    public let throughputMBs: Double
    public let spaceSavingsPct: Double
    public let compressedBytes: Int64
    public let uncompressedBytes: Int64
    public let timestamp: Double
    
    public init(
        toolId: String,
        algorithm: String,
        level: Int,
        datasetSha256: String,
        throughputMBs: Double,
        spaceSavingsPct: Double,
        compressedBytes: Int64,
        uncompressedBytes: Int64,
        timestamp: Double = Date().timeIntervalSince1970
    ) {
        self.toolId = toolId
        self.algorithm = algorithm
        self.level = level
        self.datasetSha256 = datasetSha256
        self.throughputMBs = throughputMBs
        self.spaceSavingsPct = spaceSavingsPct
        self.compressedBytes = compressedBytes
        self.uncompressedBytes = uncompressedBytes
        self.timestamp = timestamp
    }
}

/// 外部竞品基准测试结果持久化缓存管理器
///
/// 原则：
/// 1. 外部第三方静态软件 (pigz, advzip, 7-Zip, ditto) 的二进制版本与数据集指纹不变时，直接命中持久化缓存，避免 190s 重复开销；
/// 2. TTZip 自身每一次代码修改必须 100% 实时实测，绝对禁止缓存；
/// 3. 当数据集 SHA-256 变更或环境变量设置 `TTZIP_FORCE_BENCH_RERUN=1` 时，自动作废旧缓存并全量现场重跑。
public final class CompetitorBenchmarkCacheManager: @unchecked Sendable {
    
    public static let shared = CompetitorBenchmarkCacheManager()
    
    private let lock = NSLock()
    private var cacheEntries: [String: CompetitorCacheEntry] = [:]
    private let cacheFilePath: String
    
    public init() {
        // 首选项目内文档目录，兜底用户缓存目录
        let projectDocsCache = "docs/benchmarks/competitor_cache_zip.json"
        if FileManager.default.fileExists(atPath: "docs/benchmarks") {
            self.cacheFilePath = projectDocsCache
        } else {
            let userCache = (NSHomeDirectory() as NSString).appendingPathComponent(".cache/ttzip/competitor_cache_zip.json")
            self.cacheFilePath = userCache
        }
        loadCacheFromDisk()
    }
    
    private func loadCacheFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: cacheFilePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: cacheFilePath)),
              let decoded = try? JSONDecoder().decode([String: CompetitorCacheEntry].self, from: data) else {
            return
        }
        self.cacheEntries = decoded
    }
    
    private func saveCacheToDisk() {
        guard let data = try? JSONEncoder().encode(cacheEntries) else { return }
        let dir = (cacheFilePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: cacheFilePath))
    }
    
    /// 获取或执行竞品基准测试 (当指纹匹配时 0.001s 极速复用)
    public func getOrRun(
        toolId: String,
        algorithm: String,
        level: Int,
        datasetSha256: String,
        runBlock: () throws -> (throughputMBs: Double, spaceSavingsPct: Double, compressedBytes: Int64, uncompressedBytes: Int64)
    ) rethrows -> ParetoPoint {
        let isForceRerun = ProcessInfo.processInfo.environment["TTZIP_FORCE_BENCH_RERUN"] == "1"
        
        lock.lock()
        if !isForceRerun, let entry = cacheEntries[toolId], entry.datasetSha256 == datasetSha256 {
            lock.unlock()
            return ParetoPoint(
                id: entry.toolId,
                algorithm: entry.algorithm,
                level: entry.level,
                throughputMBs: entry.throughputMBs,
                spaceSavingsPct: entry.spaceSavingsPct,
                compressedBytes: entry.compressedBytes,
                uncompressedBytes: entry.uncompressedBytes
            )
        }
        lock.unlock()
        
        // 缓存未命中或强制重跑，执行物理实测
        let res = try runBlock()
        
        let entry = CompetitorCacheEntry(
            toolId: toolId,
            algorithm: algorithm,
            level: level,
            datasetSha256: datasetSha256,
            throughputMBs: res.throughputMBs,
            spaceSavingsPct: res.spaceSavingsPct,
            compressedBytes: res.compressedBytes,
            uncompressedBytes: res.uncompressedBytes
        )
        
        lock.lock()
        cacheEntries[toolId] = entry
        saveCacheToDisk()
        lock.unlock()
        
        return ParetoPoint(
            id: entry.toolId,
            algorithm: entry.algorithm,
            level: entry.level,
            throughputMBs: entry.throughputMBs,
            spaceSavingsPct: entry.spaceSavingsPct,
            compressedBytes: entry.compressedBytes,
            uncompressedBytes: entry.uncompressedBytes
        )
    }
}
