// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// 【Pattern 4.2 / 】15+
@MainActor
public final class ReadWriteLockPatternTests: XCTestCase {
    
    // MARK: - 1. POSIXReadWriteLock
    
    /// 100 Read
    public func testPOSIXReadWriteLockConcurrentReads() {
        let lock = POSIXReadWriteLock()
        let exp = expectation(description: "100 Concurrent Readers")
        exp.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent.readers", attributes: .concurrent)
        let activeReaderCount = AtomicInt(value: 0)
        let maxSimultaneousReaders = AtomicInt(value: 0)
        
        for _ in 0..<100 {
            queue.async {
                lock.withReadLock {
                    let current = activeReaderCount.incrementAndGet()
                    maxSimultaneousReaders.updateMax(current)
                    Thread.sleep(forTimeInterval: 0.005)
                    activeReaderCount.decrementAndGet()
                }
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        XCTAssertGreaterThan(maxSimultaneousReaders.value, 1, "多个并发 Task 应能同时持有读锁，最大并发读计数应 > 1")
    }
    
    /// Write ：Write Read Write
    public func testPOSIXReadWriteLockWriteExclusivity() {
        let lock = POSIXReadWriteLock()
        let exp = expectation(description: "Write Exclusivity Test")
        exp.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue(label: "test.write.exclusivity", attributes: .concurrent)
        let sharedState = AtomicInt(value: 0)
        let isWriting = AtomicBool(value: false)
        let conflictDetected = AtomicBool(value: false)
        
        // 5 5
        for _ in 0..<5 {
            queue.async {
                lock.withWriteLock {
                    if isWriting.value { conflictDetected.value = true }
                    isWriting.value = true
                    
                    let temp = sharedState.value
                    Thread.sleep(forTimeInterval: 0.003)
                    sharedState.setValue(temp + 1)
                    
                    isWriting.value = false
                }
                exp.fulfill()
            }
            
            queue.async {
                lock.withReadLock {
                    if isWriting.value { conflictDetected.value = true }
                    let _ = sharedState.value
                }
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        XCTAssertFalse(conflictDetected.value, "Write 独占期间不应有任何并发写或并发读冲突")
        XCTAssertEqual(sharedState.value, 5, "最终共享状态应精确递增 5 次")
    }
    
    /// (rethrows)
    public func testPOSIXReadWriteLockRethrows() {
        enum TestError: Error {
            case readFailure
            case writeFailure
        }
        let lock = POSIXReadWriteLock()
        
        XCTAssertThrowsError(try lock.read {
            throw TestError.readFailure
        }) { error in
            XCTAssertEqual(error as? TestError, .readFailure)
        }
        
        XCTAssertThrowsError(try lock.write {
            throw TestError.writeFailure
        }) { error in
            XCTAssertEqual(error as? TestError, .writeFailure)
        }
    }
    
    // MARK: - 2. ReadWriteLockCache LRU / TTL / Cost
    
    /// LRU ： maxEntries
    public func testCacheLRUEviction() {
        let cache = ReadWriteLockCache<String, Int>(policy: .lru(maxEntries: 3))
        
        cache.setValue(10, forKey: "A")
        cache.setValue(20, forKey: "B")
        cache.setValue(30, forKey: "C")
        
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache.value(forKey: "A"), 10) // 访问 A，调整 A 为 MRU，LRU 变为 B
        
        cache.setValue(40, forKey: "D") // 写入 D，由于容量超标限制 3，应淘汰最久未访问的 B
        
        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.value(forKey: "B"), "最久未访问节点 B 应被自动 LRU 淘汰")
        XCTAssertEqual(cache.value(forKey: "A"), 10)
        XCTAssertEqual(cache.value(forKey: "C"), 30)
        XCTAssertEqual(cache.value(forKey: "D"), 40)
    }
    
    /// TTL
    public func testCacheTTLEviction() {
        let cache = ReadWriteLockCache<String, String>(policy: .ttl(seconds: 0.1))
        
        cache.setValue("Hello", forKey: "greeting")
        XCTAssertEqual(cache.value(forKey: "greeting"), "Hello")
        
        // 150ms TTL
        Thread.sleep(forTimeInterval: 0.15)
        
        XCTAssertNil(cache.value(forKey: "greeting"), "到达 TTL 超时时间后访问应自动失效返回 nil 并移除")
        XCTAssertEqual(cache.count, 0, "超期节点移除后 count 应归 0")
    }
    
    /// Cost
    public func testCacheCostEviction() {
        let cache = ReadWriteLockCache<String, String>(policy: .cost(maxTotalCost: 100))
        
        cache.setValue("Small", forKey: "k1", cost: 30)
        cache.setValue("Medium", forKey: "k2", cost: 40)
        XCTAssertEqual(cache.totalCost, 70)
        
        // 50 Large ， Cost 120 > 100， key1 (30)
        cache.setValue("Large", forKey: "k3", cost: 50)
        
        XCTAssertLessThanOrEqual(cache.totalCost, 100, "总 Cost 应控制在 maxTotalCost (100) 以内")
        XCTAssertNil(cache.value(forKey: "k1"), "k1 应因 Cost 超限被自动淘汰")
        XCTAssertEqual(cache.value(forKey: "k2"), "Medium")
        XCTAssertEqual(cache.value(forKey: "k3"), "Large")
    }
    
    /// Key Value Cost
    public func testCacheUpdateExistingKeyCost() {
        let cache = ReadWriteLockCache<String, String>(policy: .cost(maxTotalCost: 100))
        
        cache.setValue("V1", forKey: "k1", cost: 40)
        XCTAssertEqual(cache.totalCost, 40)
        
        // k1 Cost 80
        cache.setValue("V2", forKey: "k1", cost: 80)
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.totalCost, 80)
        XCTAssertEqual(cache.value(forKey: "k1"), "V2")
    }
    
    /// Key
    public func testCacheRemoveValue() {
        let cache = ReadWriteLockCache<Int, String>(maxEntries: 10)
        
        cache.setValue("One", forKey: 1, cost: 10)
        cache.setValue("Two", forKey: 2, cost: 20)
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.totalCost, 30)
        
        let removed = cache.removeValue(forKey: 1)
        XCTAssertEqual(removed, "One")
        XCTAssertNil(cache.value(forKey: 1))
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.totalCost, 20)
    }
    
    /// removeAll
    public func testCacheRemoveAll() {
        let cache = ReadWriteLockCache<String, String>(maxEntries: 10)
        for i in 0..<5 {
            cache.setValue("Val\(i)", forKey: "K\(i)", cost: i * 10)
        }
        
        XCTAssertEqual(cache.count, 5)
        cache.removeAll()
        
        XCTAssertEqual(cache.count, 0)
        XCTAssertEqual(cache.totalCost, 0)
        XCTAssertNil(cache.value(forKey: "K0"))
    }
    
    // MARK: - 3. 100+ Zero Deadlock & Zero Data Race
    
    /// 100+ Task
    public func testCacheHighConcurrencyReadWriteStress() {
        let cache = ReadWriteLockCache<Int, Int>(policies: [
            .lru(maxEntries: 50),
            .cost(maxTotalCost: 500)
        ])
        
        let exp = expectation(description: "100 High Concurrency Workers")
        exp.expectedFulfillmentCount = 100
        let queue = DispatchQueue(label: "test.cache.stress", attributes: .concurrent)
        
        for threadId in 0..<100 {
            queue.async {
                for iter in 0..<100 {
                    let key = (threadId + iter) % 80
                    let action = (threadId + iter) % 3
                    
                    switch action {
                    case 0:
                        cache.setValue(threadId * 1000 + iter, forKey: key, cost: (key % 10) + 1)
                    case 1:
                        let _ = cache.value(forKey: key)
                    default:
                        let _ = cache.removeValue(forKey: key)
                    }
                }
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0)
        XCTAssertLessThanOrEqual(cache.count, 50, "并发压测后，缓存条目数量必须在 50 以内")
        XCTAssertLessThanOrEqual(cache.totalCost, 500, "并发压测后，总 Cost 必须在 500 以内")
    }
    
    // MARK: - 4. Core
    
    /// ArchiveInspectionCacheProxy ReadWriteLockCache
    public func testArchiveInspectionCacheProxyIntegration() async throws {
        let proxy = ArchiveInspectionCacheProxy.shared
        proxy.clearCache()
        
        let testPath = "/tmp/test_rwlock_archive_\(UUID().uuidString).zip"
        FileManager.default.createFile(atPath: testPath, contents: Data("test zip content".utf8))
        defer { try? FileManager.default.removeItem(atPath: testPath) }
        
        let countBefore = proxy.cachedItemCount
        let ratioBefore = proxy.hitRatio
        XCTAssertEqual(countBefore, 0)
        XCTAssertEqual(ratioBefore, 0.0)
        
        // Verify expected invariant
        proxy.clearCache()
        XCTAssertEqual(proxy.cachedItemCount, 0)
    }
    
    /// CharsetDetector ReadWriteLockCache
    public func testCharsetDetectorCacheIntegration() {
        CharsetDetector.clearCache()
        
        let utf8Data = Data("Hello, TTZip ReadWriteLock!".utf8)
        let charset1 = CharsetDetector.detectCharset(data: utf8Data)
        let charset2 = CharsetDetector.detectCharset(data: utf8Data)
        
        XCTAssertEqual(charset1, "ASCII")
        XCTAssertEqual(charset2, "ASCII")
        
        let sanitized1 = CharsetDetector.sanitizeFilename(bytes: utf8Data)
        let sanitized2 = CharsetDetector.sanitizeFilename(bytes: utf8Data)
        XCTAssertEqual(sanitized1, "Hello, TTZip ReadWriteLock!")
        XCTAssertEqual(sanitized2, "Hello, TTZip ReadWriteLock!")
    }
    
    /// PresetManager ReadWriteLockCache
    public func testPresetManagerCacheIntegration() {
        let manager = PresetManager.shared
        manager.resetToDefaults()
        
        let presets = manager.presets
        XCTAssertGreaterThan(presets.count, 0)
        
        let first = presets.first!
        let fetched1 = manager.preset(for: first.id)
        let fetched2 = manager.preset(for: first.id)
        
        XCTAssertEqual(fetched1?.id, first.id)
        XCTAssertEqual(fetched2?.id, first.id)
        
        // Verify expected invariant
        let cloned = manager.duplicatePreset(id: first.id, newName: "Cloned Preset")
        XCTAssertNotNil(cloned)
        XCTAssertEqual(cloned?.name, "Cloned Preset")
    }
    
    // MARK: - 5.
    
    /// LRU + TTL + Cost
    public func testCacheMultipleEvictionPoliciesCombined() {
        let cache = ReadWriteLockCache<String, String>(policies: [
            .lru(maxEntries: 5),
            .ttl(seconds: 1.0),
            .cost(maxTotalCost: 50)
        ])
        
        cache.setValue("Val1", forKey: "K1", cost: 20)
        cache.setValue("Val2", forKey: "K2", cost: 20)
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.totalCost, 40)
        
        // K3 totalCost (60 > 50) -> K1
        cache.setValue("Val3", forKey: "K3", cost: 20)
        XCTAssertNil(cache.value(forKey: "K1"))
        XCTAssertEqual(cache.value(forKey: "K2"), "Val2")
        XCTAssertEqual(cache.value(forKey: "K3"), "Val3")
    }
    
    /// compact TTL
    public func testCacheCompactExpiredTTL() {
        let cache = ReadWriteLockCache<Int, String>(policy: .ttl(seconds: 0.1))
        
        for i in 0..<10 {
            cache.setValue("Val\(i)", forKey: i)
        }
        XCTAssertEqual(cache.count, 10)
        
        Thread.sleep(forTimeInterval: 0.15)
        cache.compact()
        
        XCTAssertEqual(cache.count, 0, "compact 应主动扫尾清理掉所有已到期的 TTL 条目")
    }
    
    /// (Cost 0, maxEntries 0, key)
    public func testCacheEdgeCases() {
        let cache = ReadWriteLockCache<String, String>(maxEntries: 0)
        cache.setValue("Zero", forKey: "K0", cost: 0)
        
        XCTAssertNil(cache.value(forKey: "K0"), "maxEntries 为 0 时不保留任何缓存")
        XCTAssertNil(cache.peekValue(forKey: "NonExistentKey"))
        XCTAssertNil(cache.removeValue(forKey: "NonExistentKey"))
    }
}

// MARK: - Atomic Helpers

private final class AtomicInt: @unchecked Sendable {
    private var _value: Int
    private let lock = NSLock()
    
    init(value: Int) {
        self._value = value
    }
    
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    func setValue(_ val: Int) {
        lock.lock()
        defer { lock.unlock() }
        _value = val
    }
    
    @discardableResult
    func incrementAndGet() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
    
    @discardableResult
    func decrementAndGet() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value -= 1
        return _value
    }
    
    func updateMax(_ newVal: Int) {
        lock.lock()
        defer { lock.unlock() }
        if newVal > _value {
            _value = newVal
        }
    }
}

private final class AtomicBool: @unchecked Sendable {
    private var _value: Bool
    private let lock = NSLock()
    
    init(value: Bool) {
        self._value = value
    }
    
    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
