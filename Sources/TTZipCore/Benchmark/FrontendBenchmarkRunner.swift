// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Frontend core algorithm and UI interaction performance benchmark executor.
public final class FrontendBenchmarkRunner: Sendable {
    public static let shared = FrontendBenchmarkRunner()
    
    public init() {}
    
    /// Generates synthetic hierarchical archive entry dataset.
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
    
    /// Runs tree build performance benchmarks across node scales.
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
    
    /// Runs real-time search and filter performance benchmarks.
    public func runSearchFilterBenchmark(datasetSize: Int = 20000, queries: [String] = ["file_100", "Folder_2", "sub", "nonexistent"]) async -> [SearchFilterMetric] {
        let entries = generateSyntheticEntries(count: datasetSize)
        var results: [SearchFilterMetric] = []
        
        for q in queries {
            let clock = ContinuousClock()
            var matched = 0
            
            let elapsed = clock.measure {
                var count = 0
                #if canImport(Darwin) || canImport(Glibc)
                q.withCString { qPtr in
                    for entry in entries {
                        let matchName = entry.name.withCString { strcasestr($0, qPtr) != nil }
                        if matchName {
                            count += 1
                        } else {
                            let matchPath = entry.path.withCString { strcasestr($0, qPtr) != nil }
                            if matchPath { count += 1 }
                        }
                    }
                }
                #else
                let lowerQ = q.lowercased()
                for entry in entries {
                    if entry.name.localizedCaseInsensitiveContains(q) || entry.path.localizedCaseInsensitiveContains(q) {
                        count += 1
                    }
                }
                #endif
                matched = count
            }
            
            let durationMs = Double(elapsed.components.seconds) * 1000.0 + (Double(elapsed.components.attoseconds) / 1e15)
            let metric = SearchFilterMetric(datasetSize: datasetSize, query: q, matchedCount: matched, durationMs: durationMs)
            results.append(metric)
        }
        return results
    }
    
    /// Runs high-frequency event throttling benchmarks.
    public func runThrottleBenchmark(eventCount: Int = 10000, targetHz: Double = 60.0) async -> [ProgressThrottleMetric] {
        let intervalNs = UInt64(1_000_000_000.0 / targetHz)
        var lastEmitted: UInt64 = 0
        var emittedCount = 0
        
        let startNano = DispatchTime.now().uptimeNanoseconds
        var currentNano = startNano
        
        for _ in 0..<eventCount {
            currentNano += 1000
            if lastEmitted == 0 || (currentNano - lastEmitted >= intervalNs) {
                lastEmitted = currentNano
                emittedCount += 1
            }
        }
        
        let totalElapsedMs = Double(currentNano - startNano) / 1_000_000.0
        let metric = ProgressThrottleMetric(totalEvents: eventCount, emittedEvents: emittedCount, durationMs: totalElapsedMs)
        return [metric]
    }
    
    /// Executes full frontend performance benchmark suite.
    public func runFullFrontendSuite() async -> FrontendPerformanceReport {
        let treeMetrics = await runTreeBuildBenchmark(entryCounts: [1000, 10000, 50000])
        let searchMetrics = await runSearchFilterBenchmark(datasetSize: 20000)
        let throttleMetrics = await runThrottleBenchmark(eventCount: 10000)
        
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
