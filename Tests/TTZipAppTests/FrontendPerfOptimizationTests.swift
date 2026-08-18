// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class FrontendPerfOptimizationTests: XCTestCase {
    
    // MARK: - 1. ExplorerLRUCache
    
    func testExplorerLRUCacheBasicOperations() {
        let cache = ExplorerLRUCache<String, String>(capacity: 3)
        XCTAssertEqual(cache.capacity, 3)
        XCTAssertEqual(cache.count, 0)
        
        cache.set("a", value: "Alpha")
        cache.set("b", value: "Bravo")
        cache.set("c", value: "Charlie")
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache.get("a"), "Alpha")
        XCTAssertEqual(cache.get("b"), "Bravo")
        XCTAssertEqual(cache.get("c"), "Charlie")
        
        // "a"， 。 : b -> c -> a
        _ = cache.get("a")
        
        // "d"， ， "b"
        cache.set("d", value: "Delta")
        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.get("a"), "Alpha")
        XCTAssertEqual(cache.get("c"), "Charlie")
        XCTAssertEqual(cache.get("d"), "Delta")
        
        // remove
        XCTAssertEqual(cache.remove("c"), "Charlie")
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.get("c"))
        
        // removeAll
        cache.removeAll()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("d"))
    }
    
    func testExplorerLRUCacheThreadSafety() {
        let cache = ExplorerLRUCache<Int, String>(capacity: 10)
        let queue = DispatchQueue(label: "test.lru.concurrent", attributes: .concurrent)
        let iterations = 1000
        let exp = expectation(description: "Concurrent LRU access")
        exp.expectedFulfillmentCount = iterations * 2
        
        for i in 0..<iterations {
            queue.async {
                cache.set(i % 20, value: "Val_\(i)")
                exp.fulfill()
            }
            queue.async {
                _ = cache.get(i % 20)
                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 5.0)
        XCTAssertLessThanOrEqual(cache.count, 10)
    }
    
    // MARK: - 2. ThrottledProgressPublisher
    
    func testThrottledProgressPublisherGating() {
        let throttler = ThrottledProgressPublisher(maxFrequencyHz: 60.0) // 约 16.6ms 间隔
        
        let t0: UInt64 = 1_000_000_000
        XCTAssertTrue(throttler.shouldEmit(now: t0), "首次调用必须放行")
        
        // 5ms (5_000_000 ns)， 16.6ms，
        let t1: UInt64 = t0 + 5_000_000
        XCTAssertFalse(throttler.shouldEmit(now: t1), "未达最小间隔应被节流")
        
        // 20ms (20_000_000 ns)， 16.6ms，
        let t2: UInt64 = t0 + 20_000_000
        XCTAssertTrue(throttler.shouldEmit(now: t2), "达到最小间隔应放行")
        
        // forceEmit
        let t3: UInt64 = t2 + 1_000_000
        XCTAssertFalse(throttler.shouldEmit(now: t3))
        throttler.forceEmit(now: t3)
        
        // reset
        throttler.reset()
        XCTAssertTrue(throttler.shouldEmit(now: t3), "reset 后首帧应放行")
    }
    
    // MARK: - 3. ArchiveTreeStore Memoization
    
    @MainActor
    func testArchiveTreeStoreAsyncBuildAndMemoization() async {
        let store = ArchiveTreeStore()
        XCTAssertTrue(store.rootNodes.isEmpty)
        XCTAssertFalse(store.isBuildingTree)
        
        let entries: [ArchiveEntry] = [
            ArchiveEntry(path: "FolderA/", uncompressedSize: 0, isDirectory: true),
            ArchiveEntry(path: "FolderA/file1.txt", uncompressedSize: 1024, isDirectory: false),
            ArchiveEntry(path: "FolderA/file2.txt", uncompressedSize: 2048, isDirectory: false),
            ArchiveEntry(path: "rootFile.txt", uncompressedSize: 512, isDirectory: false)
        ]
        
        store.updateEntries(entries)
        
        // Verify expected invariant
        for _ in 0..<50 {
            if !store.rootNodes.isEmpty && !store.isBuildingTree {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        XCTAssertFalse(store.rootNodes.isEmpty)
        XCTAssertEqual(store.rootNodes.count, 2) // FolderA, rootFile.txt
        
        // Memoization: entries
        let currentRoot = store.rootNodes
        store.updateEntries(entries)
        XCTAssertEqual(store.rootNodes, currentRoot)
        
        // Verify expected invariant
        store.clear()
        XCTAssertTrue(store.rootNodes.isEmpty)
        XCTAssertTrue(store.filteredEntries.isEmpty)
    }
    
    // MARK: - 4. ArchiveTreeStore
    
    @MainActor
    func testArchiveTreeStoreSearchFilter() async {
        let store = ArchiveTreeStore()
        let entries: [ArchiveEntry] = [
            ArchiveEntry(path: "docs/Document.pdf", uncompressedSize: 1024, isDirectory: false),
            ArchiveEntry(path: "images/Photo.png", uncompressedSize: 2048, isDirectory: false),
            ArchiveEntry(path: "src/Source.swift", uncompressedSize: 512, isDirectory: false)
        ]
        
        store.updateEntries(entries)
        
        // "swift"，debounceMs 10ms
        store.filter(query: "swift", debounceMs: 10)
        
        for _ in 0..<30 {
            if !store.isFiltering && store.filteredEntries.count == 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertEqual(store.filteredEntries.first?.name, "Source.swift")
        
        // Verify expected invariant
        store.filter(query: "", debounceMs: 0)
        XCTAssertEqual(store.filteredEntries.count, 3)
    }
    
    // MARK: - 5. AppViewState
    
    @MainActor
    func testAppViewStateHighFrequencyProgress() async {
        let appState = AppViewState()
        
        let total = 2000
        for i in 1...total {
            let progress = ArchiveProgressInfo(
                state: .processing,
                bytesProcessed: Int64(i * 1024),
                totalBytes: Int64(total * 1024),
                currentFileName: "file_\(i).dat",
                throughputMBs: 150.0,
                estimatedTimeRemaining: 2.0,
                operationType: .compress
            )
            appState.onProgressUpdated(progress)
        }
        
        // ，
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertGreaterThan(appState.progressValue, 0.0)
    }
}
