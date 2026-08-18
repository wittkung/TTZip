// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class FlyweightPatternTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ArchiveEntryFlyweightFactory.shared.clearPools()
        ByteCountFormatterFlyweight.shared.clearCache()
        MemoryPageFlyweightPool.shared.clearPool()
    }
    
    override func tearDown() {
        ArchiveEntryFlyweightFactory.shared.clearPools()
        ByteCountFormatterFlyweight.shared.clearCache()
        MemoryPageFlyweightPool.shared.clearPool()
        super.tearDown()
    }
    
    // MARK: - 1. ArchiveEntryFlyweightFactory
    
    func testArchiveEntryFlyweightFactoryStringInterning() {
        let factory = ArchiveEntryFlyweightFactory.shared
        
        let path1 = factory.internPath("node_modules/lodash/package.json")
        let path2 = factory.internPath("node_modules/lodash/package.json")
        
        // (Identity Match)
        XCTAssertTrue((path1 as NSString) === (path2 as NSString), "享元池返回的字符串应具备完全相同的堆内存指针引用")
        
        let ext1 = factory.internExtension("json")
        let ext2 = factory.internExtension("JSON")
        XCTAssertEqual(ext1, ext2)
        XCTAssertTrue((ext1 as NSString) === (ext2 as NSString))
        
        let mime1 = factory.detectMimeType(forPath: "app.js")
        let mime2 = factory.detectMimeType(forPath: "utils.js")
        XCTAssertEqual(mime1, "application/javascript")
        XCTAssertTrue((mime1 as NSString) === (mime2 as NSString))
        
        let prefix1 = factory.extractAndInternDirectoryPrefix(fromPath: "node_modules/express/lib/express.js")
        let prefix2 = factory.extractAndInternDirectoryPrefix(fromPath: "node_modules/express/lib/router.js")
        XCTAssertEqual(prefix1, "node_modules/express/lib/")
        XCTAssertTrue((prefix1 as NSString) === (prefix2 as NSString))
    }
    
    func testHighVolumeArchiveEntryMemorySavings() {
        let factory = ArchiveEntryFlyweightFactory.shared
        factory.clearPools()
        
        let totalCount = 10_000
        var entries: [ArchiveEntry] = []
        entries.reserveCapacity(totalCount)
        
        // node_modules
        for i in 0..<totalCount {
            let path = "node_modules/react/lib/Component_\(i % 10).js"
            let entry = ArchiveEntry(path: path, uncompressedSize: 1024, isDirectory: false)
            entries.append(entry)
        }
        
        XCTAssertEqual(entries.count, totalCount)
        
        let counts = factory.poolCounts
        // 10,000 ， 10 、10 、1 ， 21 （ 30,000 ）
        XCTAssertLessThanOrEqual(counts.paths, 25)
        XCTAssertEqual(counts.extensions, 28) // 包含预热的 28 个常用扩展名
        
        let savingsRatio = factory.estimatedMemorySavingsRatio(totalEntriesProcessed: totalCount)
        XCTAssertGreaterThan(savingsRatio, 0.70, "10,000 个海量重复文件条目的内存节省比例应达到 70% 以上")
    }
    
    func testArchiveEntryFlyweightFactoryConcurrency() {
        let factory = ArchiveEntryFlyweightFactory.shared
        factory.clearPools()
        let iterationCount = 5_000
        
        DispatchQueue.concurrentPerform(iterations: iterationCount) { idx in
            let path = "src/module_\(idx % 20)/index.ts"
            _ = factory.internPath(path)
            _ = factory.internExtension("ts")
            _ = factory.detectMimeType(forPath: path)
            _ = factory.extractAndInternDirectoryPrefix(fromPath: path)
        }
        
        let counts = factory.poolCounts
        XCTAssertLessThanOrEqual(counts.paths, 20)
    }
    
    // MARK: - 2. ByteCountFormatterFlyweight
    
    func testByteCountFormatterFlyweightQuantizationAndHitRatio() {
        let flyweight = ByteCountFormatterFlyweight.shared
        flyweight.clearCache()
        
        let size1 = flyweight.string(fromByteCount: 1_048_576) // 1 MB
        let size2 = flyweight.string(fromByteCount: 1_048_576) // 1 MB
        
        XCTAssertEqual(size1, size2)
        XCTAssertTrue((size1 as NSString) === (size2 as NSString), "重复获取相同字节数的格式化文本应返回同一个享元 String 引用")
        XCTAssertEqual(flyweight.hitCount, 1)
        XCTAssertGreaterThan(flyweight.hitRatio, 0.0)
        
        let q1 = flyweight.quantizedString(fromByteCount: 10_500_000)
        let q2 = flyweight.quantizedString(fromByteCount: 10_520_000)
        XCTAssertEqual(q1, q2, "64KB 块量化格式化文本应收敛为同一个享元字符串")
        
        // ByteCountFormatterCache
        let legacyFormatted = ByteCountFormatterCache.string(fromByteCount: 1_048_576)
        XCTAssertEqual(legacyFormatted, size1)
    }
    
    func testByteCountFormatterFlyweightConcurrency() {
        let flyweight = ByteCountFormatterFlyweight.shared
        flyweight.clearCache()
        
        DispatchQueue.concurrentPerform(iterations: 2_000) { idx in
            let bytes = Int64((idx % 50) * 1024)
            _ = flyweight.string(fromByteCount: bytes)
        }
        
        XCTAssertGreaterThan(flyweight.hitCount, 1000)
    }
    
    // MARK: - 3. MemoryPageFlyweightPool
    
    func testMemoryPageFlyweightPoolBorrowAndReturn() {
        let pool = MemoryPageFlyweightPool.shared
        pool.clearPool()
        
        let b64 = pool.borrowBuffer(size: .page64K)
        XCTAssertEqual(b64.capacity, 65536)
        XCTAssertEqual(b64.pageSize, .page64K)
        XCTAssertEqual(UInt(bitPattern: b64.pointer) % 4096, 0, "内存页 Buffer 必须严格遵守页面边界对齐")
        
        pool.returnBuffer(b64)
        
        let stats = pool.poolStats
        XCTAssertEqual(stats.returnCount, 1)
        XCTAssertGreaterThanOrEqual(stats.borrowCount, 1)
        
        // ， page
        let b64_reused = pool.borrowBuffer(size: .page64K)
        XCTAssertEqual(b64.pointer, b64_reused.pointer, "归还后的页 Buffer 享元应在下次借用时被优先零分配复用")
        pool.returnBuffer(b64_reused)
    }
    
    func testMemoryPageFlyweightPoolWithBufferScope() {
        let pool = MemoryPageFlyweightPool.shared
        
        let result = pool.withBuffer(size: .page4K) { ptr, cap -> Int in
            XCTAssertEqual(cap, 4096)
            let bytePtr = ptr.assumingMemoryBound(to: UInt8.self)
            bytePtr[0] = 0xAA
            bytePtr[4095] = 0xBB
            return 42
        }
        
        XCTAssertEqual(result, 42)
    }
    
    func testMemoryPageFlyweightPoolHighConcurrency() {
        let pool = MemoryPageFlyweightPool.shared
        
        DispatchQueue.concurrentPerform(iterations: 1_000) { idx in
            let size: MemoryPageSize = (idx % 2 == 0) ? .page4K : .page64K
            let buffer = pool.borrowBuffer(size: size)
            let ptr = buffer.pointer.assumingMemoryBound(to: UInt8.self)
            ptr[0] = UInt8(idx % 255)
            Thread.sleep(forTimeInterval: 0.0001)
            pool.returnBuffer(buffer)
        }
        
        let stats = pool.poolStats
        XCTAssertGreaterThan(stats.reuseRatio, 0.80, "高并发借还场景下页 Buffer 的复用率应超过 80%")
    }
    
    // MARK: - 4. ArchiveComponent, ArchiveTreeNode
    
    func testFullArchitectureFlyweightIntegration() {
        let leaf = ArchiveLeafFile(name: "index.js", path: "node_modules/express/index.js", sizeBytes: 2048)
        let composite = ArchiveCompositeDirectory(name: "express", path: "node_modules/express", children: [leaf])
        
        let treeOutput = composite.renderTree()
        XCTAssertTrue(treeOutput.contains("index.js"))
        XCTAssertTrue(treeOutput.contains("2") && (treeOutput.contains("KB") || treeOutput.contains("B")))
        
        let entry = ArchiveEntry(path: "node_modules/express/index.js", uncompressedSize: 2048, isDirectory: false)
        let node = ArchiveTreeNode(
            id: entry.id,
            name: entry.name,
            path: entry.path,
            uncompressedSize: entry.uncompressedSize,
            isDirectory: entry.isDirectory,
            entry: entry
        )
        
        XCTAssertEqual(node.name, "index.js")
        XCTAssertEqual(entry.extensionName, "js")
        XCTAssertEqual(entry.mimeType, "application/javascript")
        XCTAssertEqual(entry.directoryPrefix, "node_modules/express/")
    }
    
    // MARK: - 5. / Secondary Deep Audit Tests
    
    func testArchiveEntryFlyweightFactoryCapacityLimitAndAutoPurge() {
        let factory = ArchiveEntryFlyweightFactory.shared
        factory.clearPool()
        
        let originalCap = factory.maxPathPoolCapacity
        factory.maxPathPoolCapacity = 50
        defer { factory.maxPathPoolCapacity = originalCap }
        
        for i in 0..<120 {
            _ = factory.internPath("unique/path/file_\(i).txt")
        }
        
        // ，
        XCTAssertLessThanOrEqual(factory.poolCounts.paths, 50, "路径池容量超限时应自动实施上限截断")
        
        factory.clearPool()
        XCTAssertEqual(factory.poolCounts.paths, 0)
        XCTAssertGreaterThan(factory.poolCounts.extensions, 0, "clearPool 清空后应安全复原预热的 MIME 与扩展名映射")
    }
    
    func testByteCountFormatterFlyweightThreadSafetyAndClearPool() {
        let flyweight = ByteCountFormatterFlyweight.shared
        flyweight.clearPool()
        
        // /
        DispatchQueue.concurrentPerform(iterations: 1_000) { idx in
            let bytes = Int64(idx * 1337)
            _ = flyweight.string(fromByteCount: bytes)
            _ = flyweight.quantizedString(fromByteCount: bytes)
        }
        
        XCTAssertGreaterThan(flyweight.cacheSize, 0)
        flyweight.clearPool()
        XCTAssertEqual(flyweight.hitCount, 0)
        XCTAssertEqual(flyweight.missCount, 0)
    }
    
    func testMemoryPageFlyweightPoolDoubleReturnSafetyAndClearPool() {
        let pool = MemoryPageFlyweightPool.shared
        pool.clearPool()
        
        let buffer = pool.borrowBuffer(size: .page4K)
        pool.returnBuffer(buffer)
        
        let statsBefore = pool.poolStats
        // buffer ( )
        pool.returnBuffer(buffer)
        let statsAfter = pool.poolStats
        
        XCTAssertEqual(statsBefore.returnCount, statsAfter.returnCount, "重复归还已被归还的 Buffer 享元不应破坏池结构或增加 returnCount")
        
        pool.clearPool()
        let statsCleared = pool.poolStats
        XCTAssertEqual(statsCleared.idle4K, 0)
        XCTAssertEqual(statsCleared.idle64K, 0)
    }
}
