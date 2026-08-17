import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class FrontendPerfOptimizationTests: XCTestCase {
    
    // MARK: - 1. ExplorerLRUCache 测试
    
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
        
        // 访问 "a"，使其成为最近访问项。当前顺序淘汰优先级为: b -> c -> a
        _ = cache.get("a")
        
        // 插入 "d"，超出容量，应淘汰 "b"
        cache.set("d", value: "Delta")
        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.get("a"), "Alpha")
        XCTAssertEqual(cache.get("c"), "Charlie")
        XCTAssertEqual(cache.get("d"), "Delta")
        
        // 测试 remove
        XCTAssertEqual(cache.remove("c"), "Charlie")
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.get("c"))
        
        // 测试 removeAll
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
    
    // MARK: - 2. ThrottledProgressPublisher 测试
    
    func testThrottledProgressPublisherGating() {
        let throttler = ThrottledProgressPublisher(maxFrequencyHz: 60.0) // 约 16.6ms 间隔
        
        let t0: UInt64 = 1_000_000_000
        XCTAssertTrue(throttler.shouldEmit(now: t0), "首次调用必须放行")
        
        // 5ms 后 (5_000_000 ns)，小于 16.6ms，应被节流
        let t1: UInt64 = t0 + 5_000_000
        XCTAssertFalse(throttler.shouldEmit(now: t1), "未达最小间隔应被节流")
        
        // 20ms 后 (20_000_000 ns)，大于 16.6ms，应放行
        let t2: UInt64 = t0 + 20_000_000
        XCTAssertTrue(throttler.shouldEmit(now: t2), "达到最小间隔应放行")
        
        // forceEmit 强制重置时钟
        let t3: UInt64 = t2 + 1_000_000
        XCTAssertFalse(throttler.shouldEmit(now: t3))
        throttler.forceEmit(now: t3)
        
        // 再次 reset
        throttler.reset()
        XCTAssertTrue(throttler.shouldEmit(now: t3), "reset 后首帧应放行")
    }
    
    // MARK: - 3. ArchiveTreeStore 异步构建与 Memoization 测试
    
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
        
        // 等待异步后台树构建完成
        for _ in 0..<50 {
            if !store.rootNodes.isEmpty && !store.isBuildingTree {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        XCTAssertFalse(store.rootNodes.isEmpty)
        XCTAssertEqual(store.rootNodes.count, 2) // FolderA, rootFile.txt
        
        // 测试 Memoization: 传入相同的 entries 不应再次重置状态
        let currentRoot = store.rootNodes
        store.updateEntries(entries)
        XCTAssertEqual(store.rootNodes, currentRoot)
        
        // 测试清空
        store.clear()
        XCTAssertTrue(store.rootNodes.isEmpty)
        XCTAssertTrue(store.filteredEntries.isEmpty)
    }
    
    // MARK: - 4. ArchiveTreeStore 搜索防抖与过滤测试
    
    @MainActor
    func testArchiveTreeStoreSearchFilter() async {
        let store = ArchiveTreeStore()
        let entries: [ArchiveEntry] = [
            ArchiveEntry(path: "docs/Document.pdf", uncompressedSize: 1024, isDirectory: false),
            ArchiveEntry(path: "images/Photo.png", uncompressedSize: 2048, isDirectory: false),
            ArchiveEntry(path: "src/Source.swift", uncompressedSize: 512, isDirectory: false)
        ]
        
        store.updateEntries(entries)
        
        // 搜索 "swift"，debounceMs 设为 10ms 加速测试
        store.filter(query: "swift", debounceMs: 10)
        
        for _ in 0..<30 {
            if !store.isFiltering && store.filteredEntries.count == 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertEqual(store.filteredEntries.first?.name, "Source.swift")
        
        // 清空搜索
        store.filter(query: "", debounceMs: 0)
        XCTAssertEqual(store.filteredEntries.count, 3)
    }
    
    // MARK: - 5. AppViewState 高频进度事件吞吐模拟测试
    
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
        
        // 验证没有崩溃，并且主线程状态最终正确
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertGreaterThan(appState.progressValue, 0.0)
    }
}
