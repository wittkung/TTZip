import Foundation

/// 性能基准测试门面接口
public protocol ArchiveBenchmarkFacading: Sendable {
    func runQuickBenchmark(size: BenchmarkDataSize, profile: BenchmarkDatasetProfile) async throws -> BenchmarkResult
    func runAllPresetsSuite(size: BenchmarkDataSize) async throws -> [BenchmarkResult]
    func cleanCache()
}

extension ArchiveBenchmarkFacading {
    public func runQuickBenchmark(
        size: BenchmarkDataSize = .small,
        profile: BenchmarkDatasetProfile = .mixedOffice
    ) async throws -> BenchmarkResult {
        return try await runQuickBenchmark(size: size, profile: profile)
    }
    
    public func runAllPresetsSuite(
        size: BenchmarkDataSize = .small
    ) async throws -> [BenchmarkResult] {
        return try await runAllPresetsSuite(size: size)
    }
}


/// 【2.5 外观模式 (Facade Pattern)】性能基准测试门面 (`ArchiveBenchmarkFacade`)
/// 屏蔽硬件基准测试、多数据集生成、竞品压测对比与硬件调控编排
public final class ArchiveBenchmarkFacade: ArchiveBenchmarkFacading, @unchecked Sendable {
    public static let shared = ArchiveBenchmarkFacade()
    
    private let benchmarkEngine: BenchmarkEngine
    
    private convenience init() {
        self.init(benchmarkEngine: BenchmarkEngine())
    }
    
    internal init(benchmarkEngine: BenchmarkEngine = BenchmarkEngine()) {
        self.benchmarkEngine = benchmarkEngine
    }
    
    public func runQuickBenchmark(
        size: BenchmarkDataSize = .small,
        profile: BenchmarkDatasetProfile = .mixedOffice
    ) async throws -> BenchmarkResult {
        return try await benchmarkEngine.runBenchmark(size: size, profile: profile)
    }
    
    public func runAllPresetsSuite(size: BenchmarkDataSize = .small) async throws -> [BenchmarkResult] {
        return try await benchmarkEngine.runAllPresetsSuite(size: size)
    }
    
    public func cleanCache() {
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let docsCacheDir = docsUrl.appendingPathComponent("TTZipExhaustiveDatasetCache")
        let tmpCacheDir = fm.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")
        
        try? fm.removeItem(at: docsCacheDir)
        try? fm.removeItem(at: tmpCacheDir)
    }
}
