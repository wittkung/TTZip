import XCTest
import CTTZipBridge
@testable import TTZipCore

final class LZ4DeepIntegrationAndVFSTests: XCTestCase {
    
    // MARK: - 1. LZ4 Partial Decompress & TLS Acceleration Tests
    
    func testLZ4PartialDecompressAndTLSCompression() throws {
        let engine = LZ4LzoEngine()
        let sampleString = String(repeating: "TTZip Native LZ4 Zero-Entropy High Speed Compression 2026! ", count: 200)
        let sampleData = sampleString.data(using: .utf8)!
        
        // 1. TLS 状态池复用压缩
        let compressed = engine.compressWithTLS(data: sampleData, acceleration: 2)
        XCTAssertFalse(compressed.isEmpty, "TLS LZ4 压缩结果不应为空")
        XCTAssertLessThan(compressed.count, sampleData.count, "可压缩文本经 LZ4 压缩后体积应缩小")
        
        // 2. 全量解压还原验证
        let decompressedFull = engine.decompress(data: compressed, originalSizeHint: sampleData.count)
        XCTAssertEqual(decompressedFull, sampleData, "全量解压数据应与源数据 100% 一致")
        
        // 3. 部分截断解压 (Partial Decompression) 验证
        let targetPrefixSize = 64
        let decompressedPartial = engine.decompressPartial(data: compressed, targetSize: targetPrefixSize)
        XCTAssertGreaterThanOrEqual(decompressedPartial.count, targetPrefixSize, "部分解压应至少解压出目标字节数")
        
        let expectedPrefix = sampleData.prefix(targetPrefixSize)
        let actualPrefix = decompressedPartial.prefix(targetPrefixSize)
        XCTAssertEqual(actualPrefix, expectedPrefix, "部分截断解压前缀应与原始数据前缀完全一致")
    }
    
    // MARK: - 2. VFS Two-Tier LZ4 Cache Pool (RAM + Disk Spill)
    
    func testVFSLz4CachePoolStorageAndEviction() throws {
        // 创建一个配额极小 (256 字节) 的 VFS 缓存池以必定触发 LRU 磁盘溢出
        let pool = VFSLz4CachePool(maxRamBytes: 256)
        let sessionId = "test_vfs_session_\(UUID().uuidString)"
        
        // 构造 10 个数据块 (每个压缩后约 50~100 字节，总计必超 256 字节配额)
        var originalBlocks: [Int: Data] = [:]
        for chunkIdx in 0..<10 {
            let content = "VFS_BLOCK_CHUNK_\(chunkIdx)_" + String(repeating: "DATA_\(chunkIdx)_", count: 1000)
            let data = content.data(using: .utf8)!
            originalBlocks[chunkIdx] = data
            pool.put(sessionId: sessionId, chunkIndex: chunkIdx, rawData: data)
        }
        
        let stats = pool.getStats()
        XCTAssertGreaterThan(stats.ramCount, 0, "RAM 缓存应包含热数据块")
        XCTAssertGreaterThan(stats.diskCount, 0, "超配数据应成功 LRU 溢出至磁盘")
        
        // 验证全量 10 个数据块无论是从 RAM 还是 Disk 拉取，均能 100% 无损还原
        for chunkIdx in 0..<10 {
            let fetched = pool.get(sessionId: sessionId, chunkIndex: chunkIdx)
            XCTAssertNotNil(fetched, "应成功获取 chunk \(chunkIdx)")
            XCTAssertEqual(fetched, originalBlocks[chunkIdx], "获取的数据块应与原始数据完全一致")
        }
        
        // 清理会话
        pool.clearSession(sessionId: sessionId)
        let clearedStats = pool.getStats()
        XCTAssertEqual(clearedStats.ramCount, 0, "清理后 RAM 计数应为 0")
        XCTAssertEqual(clearedStats.diskCount, 0, "清理后 Disk 计数应为 0")
    }
    
    // MARK: - 3. TAR Seek Scanner Rapid Traversal
    
    func testTarSeekScannerStreamParsing() throws {
        let scanner = TarLz4SeekScanner()
        
        // 手工构造一个标准的 512 字节 USTAR TAR 数据流
        var tarData = Data()
        
        // 条目 1: hello.txt (13 字节)
        var header1 = [UInt8](repeating: 0, count: 512)
        let name1 = "hello.txt".utf8
        for (i, b) in name1.enumerated() { header1[i] = b }
        let size1Str = String(format: "%011o", 13) // 8 进制 13
        for (i, b) in size1Str.utf8.enumerated() { header1[124 + i] = b }
        header1[156] = 48 // '0' 普通文件
        tarData.append(contentsOf: header1)
        
        let payload1 = "Hello, TTZip!".data(using: .utf8)!
        tarData.append(payload1)
        // 填充至 512 字节对齐
        tarData.append(contentsOf: [UInt8](repeating: 0, count: 512 - payload1.count))
        
        // 条目 2: docs/ (目录)
        var header2 = [UInt8](repeating: 0, count: 512)
        let name2 = "docs/".utf8
        for (i, b) in name2.enumerated() { header2[i] = b }
        header2[156] = 53 // '5' 目录
        tarData.append(contentsOf: header2)
        
        // 尾部全零块 (1024 字节)
        tarData.append(contentsOf: [UInt8](repeating: 0, count: 1024))
        
        // 执行扫描
        let entries = scanner.scanTarStream(tarData: tarData)
        XCTAssertEqual(entries.count, 2, "应扫描出 2 个有效条目")
        XCTAssertEqual(entries[0].path, "hello.txt")
        XCTAssertEqual(entries[0].fileSize, 13)
        XCTAssertFalse(entries[0].isDirectory)
        XCTAssertEqual(entries[0].payloadOffset, 512)
        
        XCTAssertEqual(entries[1].path, "docs/")
        XCTAssertTrue(entries[1].isDirectory)
    }
    
    // MARK: - 4. Real Physical Microbenchmarks (基于真实 Silesia 黄金语料库的严格 A/B 对照实测)
    
    func testBenchmark_TLSStreamPoolVsStandard_OnSilesiaCorpus() throws {
        // 加载真实的 Silesia 工业标准语料：dickens (10.19MB 真实文本) 与 ooffice (6.15MB 真实二进制)
        let dickensData = try SilesiaFixtureLoader.mappedData(named: "dickens")
        let oofficeData = try SilesiaFixtureLoader.mappedData(named: "ooffice")
        let engine = LZ4LzoEngine()
        
        let workloads: [(name: String, data: Data)] = [
            ("Silesia/dickens (10.19MB 文本)", dickensData),
            ("Silesia/ooffice (6.15MB 二进制)", oofficeData)
        ]
        
        print("\n=========================================================================================================")
        print("         [真实物理实测] LZ4 TLS 线程局部状态池复用 vs 传统无状态单块压缩 (Silesia 真实语料)")
        print("=========================================================================================================")
        
        for (name, payload) in workloads {
            let iterations = 100
            let totalMB = (Double(payload.count * iterations)) / (1024.0 * 1024.0)
            
            // 预热
            _ = engine.compress(data: payload, acceleration: 1)
            _ = engine.compressWithTLS(data: payload, acceleration: 1)
            
            // 1. 基线 (Before)：传统单块压缩
            let startStandard = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations {
                _ = engine.compress(data: payload, acceleration: 1)
            }
            let elapsedStandardNs = DispatchTime.now().uptimeNanoseconds - startStandard
            let throughputStandard = totalMB / (Double(elapsedStandardNs) / 1_000_000_000.0)
            
            // 2. 优化后 (After)：TLS 状态池复用压缩
            let startTLS = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations {
                _ = engine.compressWithTLS(data: payload, acceleration: 1)
            }
            let elapsedTLSNs = DispatchTime.now().uptimeNanoseconds - startTLS
            let throughputTLS = totalMB / (Double(elapsedTLSNs) / 1_000_000_000.0)
            
            let deltaPercent = (throughputTLS - throughputStandard) / throughputStandard * 100.0
            print("  ▶ 载荷: \(name) [\(iterations) 轮平均]")
            print("    * 基线 (传统单块) : \(String(format: "%.1f", throughputStandard)) MB/s (耗时: \(String(format: "%.2f", Double(elapsedStandardNs)/1_000_000.0)) ms)")
            print("    * 优化 (TLS 状态池): \(String(format: "%.1f", throughputTLS)) MB/s (耗时: \(String(format: "%.2f", Double(elapsedTLSNs)/1_000_000.0)) ms)")
            print("    * 真实物理增益    : \(String(format: "%+.1f%%", deltaPercent))")
        }
        print("=========================================================================================================\n")
    }
    
    func testBenchmark_PartialDecompressVsFullDecompress_OnSilesiaCorpus() throws {
        // 使用真实 Silesia samba 语料 (21.61MB)
        let sambaData = try SilesiaFixtureLoader.mappedData(named: "samba")
        let engine = LZ4LzoEngine()
        let compressed = engine.compress(data: sambaData, acceleration: 1)
        
        let targetPrefixSizes = [64, 512, 4096] // 64B 元数据头, 512B TAR 头, 4KB 页面
        let iterations = 200
        
        print("\n=========================================================================================================")
        print("     [真实物理实测] LZ4 Partial 短前缀短路截断解压 vs 全量解压后截断 (Silesia/samba 21.61MB 真实载荷)")
        print("=========================================================================================================")
        
        // 1. 基线 (Before)：全量解压后截断前缀
        let startFull = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            let full = engine.decompress(data: compressed, originalSizeHint: sambaData.count)
            _ = full.prefix(512)
        }
        let elapsedFullNs = DispatchTime.now().uptimeNanoseconds - startFull
        let avgFullMs = (Double(elapsedFullNs) / Double(iterations)) / 1_000_000.0
        
        print("  * 基线 (全量解压 21.6MB 后截断): 单次平均耗时 \(String(format: "%.3f", avgFullMs)) ms (\(String(format: "%.2f", Double(elapsedFullNs)/1_000_000.0)) ms / \(iterations)轮)")
        
        for targetSize in targetPrefixSizes {
            // 2. 优化后 (After)：Partial 原生短路截断解压
            let startPartial = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations {
                _ = engine.decompressPartial(data: compressed, targetSize: targetSize)
            }
            let elapsedPartialNs = DispatchTime.now().uptimeNanoseconds - startPartial
            let avgPartialMs = (Double(elapsedPartialNs) / Double(iterations)) / 1_000_000.0
            let speedup = avgFullMs / avgPartialMs
            
            print("  ▶ 目标尺寸: \(targetSize) 字节前缀 (Partial 短路)")
            print("    * 单次平均耗时 : \(String(format: "%.4f", avgPartialMs)) ms (\(String(format: "%.2f", Double(elapsedPartialNs)/1_000_000.0)) ms / \(iterations)轮)")
            print("    * 真实探测加速比: \(String(format: "%.1fx", speedup)) (耗时削减 \(String(format: "%.1f%%", (1.0 - 1.0/speedup)*100.0)))")
        }
        print("=========================================================================================================\n")
    }
    
    func testBenchmark_VFSCachePoolThroughput_OnRealCorpus() throws {
        let pool = VFSLz4CachePool(maxRamBytes: 64 * 1024 * 1024) // 64MB RAM
        let sessionId = "silesia_vfs_session_\(UUID().uuidString)"
        
        // 加载 Silesia 真实文件并按 256KB 切分出 100 个真实数据块
        let dickens = try SilesiaFixtureLoader.mappedData(named: "dickens")
        let mozilla = try SilesiaFixtureLoader.mappedData(named: "mozilla")
        var combined = dickens
        combined.append(mozilla)
        
        let chunkSize = 256 * 1024 // 256 KB
        var chunks: [Data] = []
        var offset = 0
        while offset + chunkSize <= combined.count && chunks.count < 100 {
            chunks.append(combined.subdata(in: offset..<(offset + chunkSize)))
            offset += chunkSize
        }
        
        let iterations = chunks.count
        let totalRawMB = Double(iterations * chunkSize) / (1024.0 * 1024.0)
        
        // 1. 真实存入基准
        let startPut = DispatchTime.now().uptimeNanoseconds
        for (i, chunk) in chunks.enumerated() {
            pool.put(sessionId: sessionId, chunkIndex: i, rawData: chunk)
        }
        let elapsedPutNs = DispatchTime.now().uptimeNanoseconds - startPut
        let putMBs = totalRawMB / (Double(elapsedPutNs) / 1_000_000_000.0)
        let avgPutUs = Double(elapsedPutNs) / Double(iterations) / 1000.0
        
        // 2. 真实读取基准
        let startGet = DispatchTime.now().uptimeNanoseconds
        for i in 0..<iterations {
            _ = pool.get(sessionId: sessionId, chunkIndex: i)
        }
        let elapsedGetNs = DispatchTime.now().uptimeNanoseconds - startGet
        let getMBs = totalRawMB / (Double(elapsedGetNs) / 1_000_000_000.0)
        let avgGetUs = Double(elapsedGetNs) / Double(iterations) / 1000.0
        
        let stats = pool.getStats()
        let ramCompressionRatio = Double(iterations * chunkSize) / Double(max(stats.ramBytes, 1))
        
        print("\n=========================================================================================================")
        print("          [真实物理实测] VFS 两级 LZ4 缓存池 (100 块 x 256KB 真实 Silesia 语料数据)")
        print("=========================================================================================================")
        print("  * 原始载荷总计 : \(String(format: "%.2f", totalRawMB)) MB (256KB x \(iterations) 块)")
        print("  * 压缩暂存耗时 : \(String(format: "%.2f", Double(elapsedPutNs)/1_000_000.0)) ms | 吞吐: \(String(format: "%.1f", putMBs)) MB/s | 平均延迟: \(String(format: "%.2f", avgPutUs)) µs/块")
        print("  * 瞬时还原耗时 : \(String(format: "%.2f", Double(elapsedGetNs)/1_000_000.0)) ms | 吞吐: \(String(format: "%.1f", getMBs)) MB/s | 平均延迟: \(String(format: "%.2f", avgGetUs)) µs/块")
        print("  * 物理内存压缩比: \(String(format: "%.2fx", ramCompressionRatio)) (节省 \(String(format: "%.1f%%", (1.0 - 1.0/ramCompressionRatio)*100.0)) 物理内存)")
        print("=========================================================================================================\n")
        
        pool.clearSession(sessionId: sessionId)
    }
}
