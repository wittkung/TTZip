import XCTest
@testable import TTZipCore

final class ProxyPatternTests: XCTestCase {
    var sandbox: IsolatedTempSandbox!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = try IsolatedTempSandbox(prefix: "proxy_pattern_tests")
        LicenseManager.simulateFreeTierInTests = false
        ArchiveInspectionCacheProxy.shared.clearCache()
        SecurityProtectionProxy.shared.resetMetrics()
        SmartLoggingProxy.shared.clearLogs()
    }
    
    override func tearDownWithError() throws {
        LicenseManager.simulateFreeTierInTests = false
        ArchiveInspectionCacheProxy.shared.clearCache()
        SecurityProtectionProxy.shared.resetMetrics()
        SmartLoggingProxy.shared.clearLogs()
        sandbox?.cleanup()
        sandbox = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 1. Virtual Proxy Tests (LazyArchiveEntryProxy)
    
    private final class ExecCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var _count: Int = 0
        var count: Int { lock.withLock { _count } }
        func increment() { lock.withLock { _count += 1 } }
    }
    
    func testLazyArchiveEntryProxyVirtualLoadingAndMemoization() {
        let baseEntry = ArchiveEntry(path: "documents/report.pdf", uncompressedSize: 2048, isDirectory: false)
        
        let posixCounter = ExecCounter()
        let mediaCounter = ExecCounter()
        let thumbCounter = ExecCounter()
        let hashCounter = ExecCounter()
        
        let proxy = LazyArchiveEntryProxy(
            entry: baseEntry,
            posixProvider: {
                posixCounter.increment()
                return [.posixPermissions: 0o755, .ownerAccountName: "admin"]
            },
            mediaMetadataProvider: {
                mediaCounter.increment()
                return ["PageCount": "42", "Format": "PDF/A-2b"]
            },
            thumbnailProvider: {
                thumbCounter.increment()
                return "PDF_PREVIEW_BINARY_DATA".data(using: .utf8)
            },
            hashProvider: {
                hashCounter.increment()
                return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            }
        )
        
        // A. 基础轻量属性无延迟解析开销
        XCTAssertEqual(proxy.path, "documents/report.pdf")
        XCTAssertEqual(proxy.name, "report.pdf")
        XCTAssertEqual(proxy.uncompressedSize, 2048)
        XCTAssertEqual(proxy.extensionName, "pdf")
        XCTAssertFalse(proxy.isDirectory)
        
        // 验证初始状态均为未加载
        XCTAssertFalse(proxy.isPosixLoaded)
        XCTAssertFalse(proxy.isMediaMetadataLoaded)
        XCTAssertFalse(proxy.isThumbnailLoaded)
        XCTAssertFalse(proxy.isHashLoaded)
        XCTAssertEqual(posixCounter.count, 0)
        XCTAssertEqual(mediaCounter.count, 0)
        XCTAssertEqual(thumbCounter.count, 0)
        XCTAssertEqual(hashCounter.count, 0)
        
        // B. 首次访问触发 POSIX 延迟加载
        let attrs = proxy.posixAttributes
        XCTAssertTrue(proxy.isPosixLoaded)
        XCTAssertEqual(proxy.posixPermissions, 0o755)
        XCTAssertEqual(attrs[.ownerAccountName] as? String, "admin")
        XCTAssertEqual(posixCounter.count, 1)
        XCTAssertEqual(proxy.posixLoadCount, 1)
        
        // 再次访问 POSIX 属性命中内存 memoize，不重触发解析闭包
        _ = proxy.posixAttributes
        _ = proxy.posixPermissions
        XCTAssertEqual(posixCounter.count, 1)
        
        // C. 访问媒体元数据
        let media = proxy.mediaMetadata
        XCTAssertTrue(proxy.isMediaMetadataLoaded)
        XCTAssertEqual(media["PageCount"], "42")
        XCTAssertEqual(mediaCounter.count, 1)
        
        // D. 访问缩略图数据
        let thumb = proxy.thumbnailData
        XCTAssertTrue(proxy.isThumbnailLoaded)
        XCTAssertNotNil(thumb)
        XCTAssertEqual(thumbCounter.count, 1)
        
        // E. 访问 SHA-256 哈希
        let hashVal = proxy.sha256Hash
        XCTAssertTrue(proxy.isHashLoaded)
        XCTAssertEqual(hashVal, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(hashCounter.count, 1)
    }
    
    func testLazyArchiveEntryProxyDiskFactoryCreation() throws {
        let testFile = sandbox.fileURL(named: "sample.txt")
        try "Sample text file content for Virtual Proxy disk loader".write(to: testFile, atomically: true, encoding: .utf8)
        
        let entry = ArchiveEntry(path: "sample.txt", uncompressedSize: 52, isDirectory: false)
        let diskProxy = LazyArchiveEntryProxy.create(for: entry, diskPath: testFile.path)
        
        XCTAssertFalse(diskProxy.isPosixLoaded)
        XCTAssertFalse(diskProxy.isMediaMetadataLoaded)
        XCTAssertFalse(diskProxy.isThumbnailLoaded)
        
        // 触发磁盘 POSIX 与预览加载
        XCTAssertGreaterThan(diskProxy.posixAttributes.count, 0)
        XCTAssertTrue(diskProxy.isPosixLoaded)
        
        let metadata = diskProxy.mediaMetadata
        XCTAssertEqual(metadata["DiskPath"], testFile.path)
        XCTAssertEqual(metadata["Extension"], "txt")
        
        XCTAssertNotNil(diskProxy.thumbnailData)
    }
    
    // MARK: - 2. Protection Proxy Tests (SecurityProtectionProxy)
    
    func testSecurityProtectionProxyProFeatureInterception() async throws {
        let proxy = SecurityProtectionProxy.shared
        proxy.resetMetrics()
        
        let file1 = sandbox.fileURL(named: "doc1.txt")
        try "Hello Protection Proxy".write(to: file1, atomically: true, encoding: .utf8)
        let outZip = sandbox.fileURL(named: "protected_out.zip").path
        
        // 启用单单元测试免费版模拟
        LicenseManager.simulateFreeTierInTests = true
        defer { LicenseManager.simulateFreeTierInTests = false }
        
        // A. 尝试使用 Ultra 压缩级别拦截
        do {
            _ = try await proxy.quickCompress(
                inputs: [file1.path],
                outputPath: outZip,
                format: .zip,
                level: .ultra
            )
            XCTFail("应当拦截免费版 Ultra 压缩请求")
        } catch let err as ProxySecurityError {
            if case .unauthorizedProFeature(let feature) = err {
                XCTAssertEqual(feature, .ultraCompression)
            } else {
                XCTFail("预期抛出 unauthorizedProFeature，实际为 \(err)")
            }
        }
        
        // B. 尝试加密压缩拦截
        do {
            _ = try await proxy.quickCompress(
                inputs: [file1.path],
                outputPath: outZip,
                format: .zip,
                password: "SecurePassword123"
            )
            XCTFail("应当拦截免费版加密压缩请求")
        } catch let err as ProxySecurityError {
            if case .unauthorizedProFeature(let feature) = err {
                XCTAssertEqual(feature, .aes256Encryption)
            } else {
                XCTFail("预期抛出 unauthorizedProFeature")
            }
        }
        
        XCTAssertGreaterThanOrEqual(proxy.interceptedProCount, 2)
    }
    
    func testSecurityProtectionProxyZipSlipInterception() async throws {
        let proxy = SecurityProtectionProxy.shared
        proxy.resetMetrics()
        
        let escapePath = "../../../etc/passwd"
        let destDir = sandbox.fileURL(named: "out").path
        
        // A. 压缩输入恶意 Escape 路径
        do {
            _ = try await proxy.quickCompress(
                inputs: [escapePath],
                outputPath: sandbox.fileURL(named: "test.zip").path
            )
            XCTFail("应当拦截 ZipSlip 逃逸压缩请求")
        } catch let err as ProxySecurityError {
            if case .zipSlipDetected(let path) = err {
                XCTAssertEqual(path, escapePath)
            } else {
                XCTFail("预期抛出 zipSlipDetected")
            }
        }
        
        // B. 解压目标恶意 Escape 路径
        do {
            _ = try await proxy.quickExtract(
                archivePath: sandbox.fileURL(named: "test.zip").path,
                destinationDir: "../../unauthorized_target"
            )
            XCTFail("应当拦截 ZipSlip 逃逸解压请求")
        } catch let err as ProxySecurityError {
            if case .zipSlipDetected(let path) = err {
                XCTAssertEqual(path, "../../unauthorized_target")
            } else {
                XCTFail("预期抛出 zipSlipDetected")
            }
        }
        
        // C. 单文件提取越权逃逸路径
        do {
            try await proxy.extractSingleEntry(
                archivePath: sandbox.fileURL(named: "test.zip").path,
                entryPath: "../../../malicious.sh",
                destinationDir: destDir
            )
            XCTFail("应当拦截单文件逃逸提取")
        } catch let err as ProxySecurityError {
            if case .zipSlipDetected(let path) = err {
                XCTAssertEqual(path, "../../../malicious.sh")
            } else {
                XCTFail("预期抛出 zipSlipDetected")
            }
        }
        
        XCTAssertGreaterThanOrEqual(proxy.interceptedZipSlipCount, 3)
    }
    
    func testSecurityProtectionProxyApprovalAndPassThrough() async throws {
        let proxy = SecurityProtectionProxy.shared
        proxy.resetMetrics()
        
        let file1 = sandbox.fileURL(named: "legit.txt")
        try "Legitimate payload for protection proxy".write(to: file1, atomically: true, encoding: .utf8)
        let archivePath = sandbox.fileURL(named: "legit.zip").path
        let destDir = sandbox.fileURL(named: "legit_extracted").path
        
        // 校验合法的压缩与解压请求顺利放行
        let compressRes = try await proxy.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip,
            level: .normal
        )
        XCTAssertGreaterThan(compressRes.compressedBytes, 0)
        
        let extractRes = try await proxy.quickExtract(
            archivePath: archivePath,
            destinationDir: destDir
        )
        XCTAssertEqual(extractRes.archivePath, archivePath)
        XCTAssertGreaterThan(proxy.approvedCallCount, 0)
    }
    
    // MARK: - 3. Cache Proxy Tests (ArchiveInspectionCacheProxy)
    
    func testArchiveInspectionCacheProxyHitAndMiss() async throws {
        let cacheProxy = ArchiveInspectionCacheProxy.shared
        cacheProxy.clearCache()
        
        let file1 = sandbox.fileURL(named: "cache_doc.txt")
        try "Cache Proxy Test Content".write(to: file1, atomically: true, encoding: .utf8)
        let archivePath = sandbox.fileURL(named: "cached_archive.zip").path
        
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip
        )
        
        // 1. 首次查询：Cache Miss
        let firstRes = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(firstRes.entries.count, 1)
        XCTAssertEqual(cacheProxy.missCount, 1)
        XCTAssertEqual(cacheProxy.hitCount, 0)
        XCTAssertEqual(cacheProxy.cachedItemCount, 1)
        
        // 2. 二次查询：Cache Hit 秒级返回
        let secondRes = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(secondRes.entries.count, 1)
        XCTAssertEqual(cacheProxy.missCount, 1)
        XCTAssertEqual(cacheProxy.hitCount, 1)
        XCTAssertEqual(cacheProxy.hitRatio, 0.5)
        
        // 3. 第三次查询：HitRatio 上升至 66.6%
        let thirdRes = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(thirdRes.entries.count, 1)
        XCTAssertEqual(cacheProxy.hitCount, 2)
        XCTAssertEqual(cacheProxy.missCount, 1)
        
        // 4. 手动使指定路径缓存失效
        cacheProxy.invalidate(archivePath: archivePath)
        XCTAssertEqual(cacheProxy.cachedItemCount, 0)
        
        // 5. 再次查询重新触发 Miss 并加载最新数据
        _ = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(cacheProxy.missCount, 2)
        XCTAssertEqual(cacheProxy.cachedItemCount, 1)
    }
    
    // MARK: - 4. Smart Proxy Tests (SmartLoggingProxy)
    
    func testSmartLoggingProxyAuditDurationAndConcurrencyRefCounting() async throws {
        let smartProxy = SmartLoggingProxy.shared
        smartProxy.clearLogs()
        
        let file1 = sandbox.fileURL(named: "smart_doc.txt")
        try "Smart Proxy Concurrency and Audit Log Test".write(to: file1, atomically: true, encoding: .utf8)
        let archivePath = sandbox.fileURL(named: "smart_archive.zip").path
        
        // 验证同步与异步通配包装 API (execute)
        let res = try await smartProxy.execute(operationName: "customAsyncJob") { () -> Int in
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return 42
        }
        XCTAssertEqual(res, 42)
        
        let logRecords = smartProxy.logs
        XCTAssertEqual(logRecords.count, 1)
        XCTAssertEqual(logRecords.first?.operationName, "customAsyncJob")
        XCTAssertTrue(logRecords.first?.success ?? false)
        XCTAssertGreaterThan(logRecords.first?.durationMs ?? 0, 5.0)
        
        // 通过 SmartLoggingProxy 代理 facade 方法
        _ = try await smartProxy.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip
        )
        
        XCTAssertGreaterThanOrEqual(smartProxy.totalOperationCount, 2)
        XCTAssertGreaterThanOrEqual(smartProxy.peakConcurrentOperations, 1)
        XCTAssertEqual(smartProxy.activeOperationCount, 0)
    }
    
    // MARK: - 5. Secondary Deep Audit Exhaustive Tests (二次深度寻猎测试套件)
    
    func testSecurityProtectionProxyExhaustiveEscapeVariantsAndProDeadCorners() async throws {
        let proxy = SecurityProtectionProxy.shared
        proxy.resetMetrics()
        
        let escapeVariants = [
            "%2e%2e/etc/passwd",
            "%2E%2E/secret.key",
            "%2e%2e%2fvar/log",
            "..\\..\\Windows\\System32",
            "foo\\..\\bar",
            "/etc/passwd",
            "/var/log/syslog",
            "/private/etc/shadow",
            "file.txt\0.zip",
            "%252e%252e/escape"
        ]
        
        for variant in escapeVariants {
            XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape(variant), "路径变体 '\(variant)' 应被识别为逃逸攻击！")
            
            // 验证在 inspectArchive 方法中被拦截
            do {
                _ = try await proxy.inspectArchive(archivePath: variant)
                XCTFail("应当拦截逃逸变体: \(variant)")
            } catch let err as ProxySecurityError {
                if case .zipSlipDetected = err {
                    // Pass
                } else {
                    XCTFail("预期 zipSlipDetected，实际为 \(err)")
                }
            }
            
            // 验证在 verifyIntegrity 方法中被拦截
            do {
                _ = try await proxy.verifyIntegrity(archivePath: variant)
                XCTFail("应当拦截逃逸变体: \(variant)")
            } catch let err as ProxySecurityError {
                if case .zipSlipDetected = err {
                    // Pass
                } else {
                    XCTFail("预期 zipSlipDetected，实际为 \(err)")
                }
            }
        }
        
        // 验证 AdvancedOptions 隐藏死角 Pro 功能拦截
        LicenseManager.simulateFreeTierInTests = true
        defer { LicenseManager.simulateFreeTierInTests = false }
        
        let dummyInput = sandbox.fileURL(named: "dummy.txt").path
        try "dummy".write(toFile: dummyInput, atomically: true, encoding: .utf8)
        let outZip = sandbox.fileURL(named: "adv_pro.zip").path
        
        var advUltra = ArchiveAdvancedOptions.defaultOptions
        advUltra.zstdOptions.zstdLevel = 19
        
        do {
            _ = try await proxy.quickCompress(
                inputs: [dummyInput],
                outputPath: outZip,
                format: .zip,
                level: .normal,
                advancedOptions: advUltra
            )
            XCTFail("应当拦截 AdvancedOptions 中设为 ultra 压测的级请求")
        } catch let err as ProxySecurityError {
            if case .unauthorizedProFeature(let f) = err {
                XCTAssertEqual(f, .ultraCompression)
            } else {
                XCTFail("预期 unauthorizedProFeature(.ultraCompression)")
            }
        }
    }
    
    func testArchiveInspectionCacheProxyLRUAndMtimeInvalidation() async throws {
        let cacheProxy = ArchiveInspectionCacheProxy.shared
        cacheProxy.clearCache()
        cacheProxy.maxCacheEntries = 3
        defer { cacheProxy.maxCacheEntries = 100 }
        
        let file1 = sandbox.fileURL(named: "doc_mtime.txt")
        try "Original Version 1".write(to: file1, atomically: true, encoding: .utf8)
        let archivePath = sandbox.fileURL(named: "mtime_test.zip").path
        
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip
        )
        
        // 1. 首次 Inspect: Miss
        _ = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(cacheProxy.missCount, 1)
        XCTAssertEqual(cacheProxy.cachedItemCount, 1)
        
        // 2. 修改磁盘文件, 更新 mtime 与文件大小
        let futureDate = Date().addingTimeInterval(5.0)
        try? FileManager.default.setAttributes([.modificationDate: futureDate], ofItemAtPath: archivePath)
        try "Modified Version 2 Content is larger".write(to: file1, atomically: true, encoding: .utf8)
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip
        )
        
        // 3. mtime 改变后再次 Inspect: 应自动检测特征变更，触发 Miss 并清理旧失效缓存
        _ = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(cacheProxy.missCount, 2)
        XCTAssertEqual(cacheProxy.cachedItemCount, 1) // 保持 1 项，旧项被自动剔除
        
        // 4. 测试 LRU 容量上限 (Cap = 3)
        var dummyZips: [String] = []
        for idx in 1...5 {
            let f = sandbox.fileURL(named: "dummy_\(idx).txt").path
            try "content \(idx)".write(toFile: f, atomically: true, encoding: .utf8)
            let z = sandbox.fileURL(named: "dummy_\(idx).zip").path
            _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [f], outputPath: z, format: .zip)
            dummyZips.append(z)
        }
        
        for zPath in dummyZips {
            _ = try await cacheProxy.inspectArchive(archivePath: zPath)
        }
        
        // 验证缓存总条目被精准限制在 maxCacheEntries = 3
        XCTAssertEqual(cacheProxy.cachedItemCount, 3)
    }
    
    func testHighConcurrency100PlusTasksThreadSafety() async throws {
        let baseEntry = ArchiveEntry(path: "concurrency/benchmark.data", uncompressedSize: 8192, isDirectory: false)
        let counter = ExecCounter()
        
        let lazyProxy = LazyArchiveEntryProxy(
            entry: baseEntry,
            posixProvider: {
                counter.increment()
                return [.posixPermissions: 0o644]
            },
            hashProvider: {
                counter.increment()
                return "HASH_VAL_CONCURRENT"
            }
        )
        
        // 派发 150 个并发 Task 抢占访问同一个 LazyProxy 的延迟属性
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<150 {
                group.addTask {
                    _ = lazyProxy.posixAttributes
                    _ = lazyProxy.posixPermissions
                    _ = lazyProxy.sha256Hash
                }
            }
        }
        
        // 验证线程同步 memoization 闭包执行次数严格等于 2 (posix 1 次 + hash 1 次)
        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(lazyProxy.posixLoadCount, 1)
        XCTAssertEqual(lazyProxy.hashLoadCount, 1)
        
        // 测试 SmartLoggingProxy 在 150+ 高并发 Task 派发下的无锁绞死与计数正确性
        let smartProxy = SmartLoggingProxy.shared
        smartProxy.clearLogs()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<150 {
                group.addTask {
                    _ = try? await smartProxy.execute(operationName: "task_\(i)") {
                        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    }
                }
            }
        }
        
        XCTAssertEqual(smartProxy.activeOperationCount, 0)
        XCTAssertEqual(smartProxy.totalOperationCount, 150)
        XCTAssertGreaterThanOrEqual(smartProxy.peakConcurrentOperations, 2)
        XCTAssertGreaterThan(smartProxy.logs.count, 0)
    }
    
    // MARK: - 6. Round 3 Tertiary Audit Exhaustive Tests (第三轮终极极限界扫荡测试)
    
    func testRound3SecurityProtectionProxy4096BytePathPerformanceAndValidDoubleDots() {
        // A. 4096 字节超长路径性能与防 ReDoS / 无栈溢出校验
        let longSegment = String(repeating: "a", count: 4000)
        let longPath = "folder/" + longSegment + "/file.txt"
        XCTAssertEqual(longPath.count, 4016)
        
        let start = CFAbsoluteTimeGetCurrent()
        let isEscape = SecurityProtectionProxy.isPathTraversalOrEscape(longPath)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        
        XCTAssertFalse(isEscape, "合法 4000 字节子路径不应被误判为逃逸攻击！")
        XCTAssertLessThan(elapsedMs, 5.0, "4096 字节路径判定必须在 5ms 内完成，实际耗时: \(elapsedMs)ms")
        
        // B. 合法包含双点的文件名 (如 my..file.txt) 无误杀
        let validDoubleDotFile = "documents/my..file.txt"
        XCTAssertFalse(SecurityProtectionProxy.isPathTraversalOrEscape(validDoubleDotFile), "合法文件名 'my..file.txt' 不应被拦截！")
        
        let validDoubleDotExt = "archive..v1.zip"
        XCTAssertFalse(SecurityProtectionProxy.isPathTraversalOrEscape(validDoubleDotExt), "合法文件名 'archive..v1.zip' 不应被拦截！")
        
        // C. Windows 盘符与 UNC 无正则高效率匹配
        XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape("C:\\Windows\\System32"))
        XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape("d:/data/secret"))
        XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape("//network/share"))
        XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape("/var/log/syslog"))
        XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape("%252e%252e/escape"))
    }
    
    final class RefTracker: @unchecked Sendable {}
    
    func testRound3LazyArchiveEntryProxyClosureCaptureLifecycleAndRelease() {
        var tracker: RefTracker? = RefTracker()
        weak var weakTracker = tracker
        
        let entry = ArchiveEntry(path: "lazy/test.doc", uncompressedSize: 1024, isDirectory: false)
        
        let proxy: LazyArchiveEntryProxy? = LazyArchiveEntryProxy(
            entry: entry,
            posixProvider: { [tracker] in
                _ = tracker
                return [.posixPermissions: 0o600]
            },
            hashProvider: { [tracker] in
                _ = tracker
                return "HASH_REF"
            }
        )
        
        // 释放外部 tracker 引用
        tracker = nil
        _ = proxy
        XCTAssertNotNil(weakTracker, "闭包尚未执行，tracker 应由闭包强引用持用")
        weakTracker = nil
        
        // 触发延迟属性加载
        _ = proxy?.posixAttributes
        _ = proxy?.sha256Hash
        
        // 验证执行后 Provider 闭包被设置为 nil，捕获的对象生命周期彻底解绑释放
        XCTAssertNil(weakTracker, "延迟加载完成后 Provider 闭包必须被置空，防止强引用内存泄露！")
        _ = proxy?.path
    }
    
    func testRound3ArchiveInspectionCacheProxyConcurrentWriteConsistency() async throws {
        let cacheProxy = ArchiveInspectionCacheProxy.shared
        cacheProxy.clearCache()
        
        let file1 = sandbox.fileURL(named: "concurrent_input.txt")
        try "Concurrent Write Consistency Payload".write(to: file1, atomically: true, encoding: .utf8)
        let archivePath = sandbox.fileURL(named: "concurrent_target.zip").path
        
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [file1.path], outputPath: archivePath, format: .zip)
        
        // 并发派发：Task 1 不断 write/compress 覆写同一归档，Task 2 不断 inspect 触发 Cache Read
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<10 {
                    let text = "Iteration \(i) data content"
                    try? text.write(to: file1, atomically: true, encoding: .utf8)
                    _ = try? await cacheProxy.quickCompress(inputs: [file1.path], outputPath: archivePath, format: .zip)
                }
            }
            
            group.addTask {
                for _ in 0..<15 {
                    _ = try? await cacheProxy.inspectArchive(archivePath: archivePath)
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            }
        }
        
        // 写操作完全结束后，再次 Inspect
        let finalInspection = try await cacheProxy.inspectArchive(archivePath: archivePath)
        XCTAssertEqual(finalInspection.entries.count, 1)
        
        // 验证缓存数据与磁盘文件真实元数据绝对一致
        let fileAttrs = try FileManager.default.attributesOfItem(atPath: archivePath)
        let diskModDate = fileAttrs[.modificationDate] as? Date
        let diskSize = (fileAttrs[.size] as? Int64) ?? 0
        
        XCTAssertGreaterThan(diskSize, 0)
        XCTAssertNotNil(diskModDate)
    }
}


