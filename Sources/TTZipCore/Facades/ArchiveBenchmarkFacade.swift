// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Performance benchmark facade interface protocol.
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

/// Unified benchmark facade encapsulating dataset generation, throughput benchmarking, and hardware calibration.
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
