import XCTest
@testable import TTZipCore

final class MockPasswordVaultManager: PasswordVaultManaging, @unchecked Sendable {
    var autoUnlockArchives: Bool = true
    var entries: [PasswordVaultEntry]
    var recordedIds: [UUID] = []
    
    init(entries: [PasswordVaultEntry] = []) {
        self.entries = entries
    }
    
    func getEntries() -> [PasswordVaultEntry] {
        return entries
    }
    
    func recordUsage(id: UUID) {
        recordedIds.append(id)
    }
}

final class StrategyPatternTests: XCTestCase {
    var sandbox: IsolatedTempSandbox!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = try IsolatedTempSandbox(prefix: "strategy_pattern_tests")
    }
    
    override func tearDownWithError() throws {
        sandbox?.cleanup()
        sandbox = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 1. Archive Compression Strategy Family Tests (压缩策略族测试)
    
    func testCompressionStrategyDynamicSelection() throws {
        let context = CompressionStrategyContext.shared
        
        // 1.1 测试显式 Store 级别
        let storeSel = context.selectOptimalStrategy(inputPaths: ["test.txt"], targetFormat: .zip, level: .store)
        XCTAssertTrue(storeSel is StoreStrategy, "Level = .store 时应选择 StoreStrategy")
        
        // 1.2 测试 7z 专属格式
        let sevenZipSel = context.selectOptimalStrategy(inputPaths: ["data.bin"], targetFormat: .sevenZip, level: .normal)
        XCTAssertTrue(sevenZipSel is SevenZipStrategy, "TargetFormat = .sevenZip 时应选择 SevenZipStrategy")
        
        // 1.3 测试 Zstd 专属格式
        let zstdSel = context.selectOptimalStrategy(inputPaths: ["log.txt"], targetFormat: .zst, level: .normal)
        XCTAssertTrue(zstdSel is ZstdStrategy, "TargetFormat = .zst 时应选择 ZstdStrategy")
        
        // 1.4 测试 POSIX Tar 格式
        let tarSel = context.selectOptimalStrategy(inputPaths: ["archive.tar"], targetFormat: .tar, level: .store)
        XCTAssertTrue(tarSel is StoreStrategy || tarSel is POSIXTarStrategy)
        
        // 1.5 测试预压缩文件 (如 .mp4, .png)
        let preCompressedSel = context.selectOptimalStrategy(inputPaths: ["video.mp4", "photo.png"], targetFormat: .zip, level: .normal)
        XCTAssertTrue(preCompressedSel is StoreStrategy, "预压缩媒体文件应自动命中 StoreStrategy 免重复压缩")
    }
    
    func testCompressionPerformanceEstimation() throws {
        let topology = AppleSiliconTuner.shared.topology
        
        let libdeflate = LibdeflateCompressionStrategy()
        let libEstimate = libdeflate.estimatePerformance(payloadBytes: 10 * 1024 * 1024, topology: topology)
        XCTAssertGreaterThan(libEstimate.estimatedThroughputMBs, 0)
        XCTAssertEqual(libEstimate.expectedRatioPercent, 45.0)
        
        let lzfse = AppleSiliconLZFSEStrategy()
        let lzfseEstimate = lzfse.estimatePerformance(payloadBytes: 50 * 1024 * 1024, topology: topology)
        XCTAssertGreaterThan(lzfseEstimate.estimatedThroughputMBs, 0)
        
        let zstd = ZstdStrategy()
        let zstdEstimate = zstd.estimatePerformance(payloadBytes: 100 * 1024 * 1024, topology: topology)
        XCTAssertGreaterThan(zstdEstimate.estimatedThroughputMBs, 0)
        
        let sevenZip = SevenZipStrategy()
        let szEstimate = sevenZip.estimatePerformance(payloadBytes: 200 * 1024 * 1024, topology: topology)
        XCTAssertEqual(szEstimate.expectedRatioPercent, 28.0)
        
        let tar = POSIXTarStrategy()
        let tarEstimate = tar.estimatePerformance(payloadBytes: 500 * 1024 * 1024, topology: topology)
        XCTAssertEqual(tarEstimate.expectedRatioPercent, 100.0)
        
        let store = StoreStrategy()
        let storeEstimate = store.estimatePerformance(payloadBytes: 1000 * 1024 * 1024, topology: topology)
        XCTAssertEqual(storeEstimate.expectedRatioPercent, 99.5)
    }
    
    func testCompressionStrategyExecution() throws {
        let inputDir = try sandbox.createSubdirectory("inputs")
        let file1 = inputDir.appendingPathComponent("file1.txt")
        try "TTZip Compression Strategy Pattern Unit Test Payload".write(to: file1, atomically: true, encoding: .utf8)
        
        let outputPath = sandbox.fileURL(named: "strategy_out.zip").path
        let success = try CompressionStrategyContext.shared.executeCompress(
            inputPaths: [file1.path],
            outputPath: outputPath,
            targetFormat: .zip,
            level: .normal,
            options: .defaultClean,
            password: nil
        )
        
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }
    
    // MARK: - 2. Password Recovery Strategy Family Tests (密码恢复策略族测试)
    
    func testPasswordVaultHistoryStrategy() async throws {
        let mockId = UUID()
        let mockVault = MockPasswordVaultManager(entries: [
            PasswordVaultEntry(id: mockId, label: "Work Vault", password: "SecretPassword123")
        ])
        
        let strategy = PasswordVaultHistoryStrategy(vaultProvider: { mockVault })
        let context = PasswordRecoveryContext(archivePath: "mock.zip")
        
        XCTAssertTrue(strategy.canExecute(context: context))
        
        let result = try await strategy.recover(context: context) { pwd in
            return pwd == "SecretPassword123"
        }
        
        XCTAssertEqual(result.foundPassword, "SecretPassword123")
        XCTAssertEqual(result.attempts, 1)
        XCTAssertEqual(mockVault.recordedIds, [mockId])
    }
    
    func testDictionaryRecoveryStrategy() async throws {
        let strategy = DictionaryRecoveryStrategy()
        let dictionary = ["123456", "admin", "CorrectHorseBatteryStaple", "password"]
        let context = PasswordRecoveryContext(archivePath: "mock.zip", dictionary: dictionary)
        
        XCTAssertTrue(strategy.canExecute(context: context))
        
        let result = try await strategy.recover(context: context) { pwd in
            return pwd == "CorrectHorseBatteryStaple"
        }
        
        XCTAssertEqual(result.foundPassword, "CorrectHorseBatteryStaple")
        XCTAssertGreaterThan(result.attempts, 0)
    }
    
    func testBruteForceRecoveryStrategy() async throws {
        let strategy = BruteForceRecoveryStrategy()
        let context = PasswordRecoveryContext(archivePath: "mock.zip", charset: "ab", maxBruteForceLength: 2)
        
        XCTAssertTrue(strategy.canExecute(context: context))
        
        let result = try await strategy.recover(context: context) { pwd in
            return pwd == "ba"
        }
        
        XCTAssertEqual(result.foundPassword, "ba")
        XCTAssertGreaterThan(result.attempts, 0)
    }
    
    func testPasswordRecoveryExecutorPipeline() async throws {
        let archivePath = sandbox.fileURL(named: "pipeline_test.zip").path
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: URL(fileURLWithPath: archivePath))
        
        let executor = PasswordRecoveryStrategyExecutor(registerDefaults: false)
        let mockVault = MockPasswordVaultManager(entries: [
            PasswordVaultEntry(id: UUID(), label: "History", password: "vault_pass_99")
        ])
        executor.register(strategy: PasswordVaultHistoryStrategy(vaultProvider: { mockVault }))
        executor.register(strategy: DictionaryRecoveryStrategy())
        
        let context = PasswordRecoveryContext(archivePath: archivePath, dictionary: ["wrong1", "target_pwd", "wrong2"])
        
        let recoveryRes = try await executor.recoverPassword(context: context) { pwd in
            return pwd == "target_pwd"
        }
        
        XCTAssertEqual(recoveryRes.foundPassword, "target_pwd")
        XCTAssertGreaterThan(recoveryRes.totalAttempts, 0)
        XCTAssertGreaterThan(recoveryRes.durationSeconds, 0)
    }
    
    // MARK: - 3. Archive Repair Strategy Family Tests (损坏归档修复策略族测试)
    
    func testArchiveRepairStrategySelection() async throws {
        let zipPath = sandbox.fileURL(named: "damaged.zip").path
        let tarPath = sandbox.fileURL(named: "damaged.tar").path
        let sevenZipPath = sandbox.fileURL(named: "damaged.7z").path
        
        // 创建带有 PK Header 的伪造 Zip
        try Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]).write(to: URL(fileURLWithPath: zipPath))
        try Data(repeating: 0, count: 512).write(to: URL(fileURLWithPath: tarPath))
        try Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]).write(to: URL(fileURLWithPath: sevenZipPath))
        
        let zipStrategy = await ArchiveRepairStrategyContext.shared.selectStrategy(for: zipPath)
        XCTAssertTrue(zipStrategy is ZipCentralDirectoryReconstructionStrategy)
        
        let tarStrategy = await ArchiveRepairStrategyContext.shared.selectStrategy(for: tarPath)
        XCTAssertTrue(tarStrategy is TarTruncatedSalvageStrategy)
        
        let sevenZipStrategy = await ArchiveRepairStrategyContext.shared.selectStrategy(for: sevenZipPath)
        XCTAssertTrue(sevenZipStrategy is SevenZipMagicHeaderRepairStrategy)
    }
    
    func testArchiveRepairEngineIntegration() async throws {
        let inputDir = try sandbox.createSubdirectory("repair_input")
        let file1 = inputDir.appendingPathComponent("document.txt")
        try "Content to be repaired".write(to: file1, atomically: true, encoding: .utf8)
        
        let validZipPath = sandbox.fileURL(named: "valid.zip").path
        let writer = ArchiveEngineFactory.makeWriter(for: .zip)
        try writer.createArchiveSync(outputPath: validZipPath, format: .zip, level: .normal, inputPaths: [file1.path], options: .defaultClean, password: nil)
        
        let repairedPath = sandbox.fileURL(named: "repaired_output.zip").path
        let engine = ArchiveRepairEngine()
        let count = try await engine.repairArchive(damagedArchivePath: validZipPath, repairedOutputPath: repairedPath)
        
        XCTAssertGreaterThanOrEqual(count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedPath))
    }
    
    // MARK: - 4. Autonomous Extension Strategy Tests (自主寻猎字符集策略测试)
    
    func testCharsetDetectionStrategies() throws {
        let asciiData = "Hello World".data(using: .utf8)!
        let sanitizedAscii = CharsetDetector.sanitizeFilename(bytes: asciiData)
        XCTAssertEqual(sanitizedAscii, "Hello World")
        
        let utf8Data = "测试中文文档.txt".data(using: .utf8)!
        let sanitizedUtf8 = CharsetDetector.sanitizeFilename(bytes: utf8Data)
        XCTAssertEqual(sanitizedUtf8, "测试中文文档.txt")
    }
    
    // MARK: - 5. Secondary Audit Deep Edge Case Tests (二次寻猎漏洞审查测试)
    
    func testDirectoryTreePreCompressedExtensionSelection() throws {
        let subDir = try sandbox.createSubdirectory("media_folder")
        let videoFile = subDir.appendingPathComponent("movie.mp4")
        let imageFile = subDir.appendingPathComponent("picture.png")
        try Data(repeating: 0xAB, count: 1024).write(to: videoFile)
        try Data(repeating: 0xCD, count: 1024).write(to: imageFile)
        
        let strategy = CompressionStrategyContext.shared.selectOptimalStrategy(inputPaths: [subDir.path], targetFormat: .zip, level: .normal)
        XCTAssertTrue(strategy is StoreStrategy, "包含预压缩媒体文件的目录应深度探查并选定 StoreStrategy")
    }
    
    func testLarge10kDictionaryRecoveryStrategyConcurrency() async throws {
        let strategy = DictionaryRecoveryStrategy()
        let largeDict = (0..<12000).map { "password_candidate_\($0)" }
        let targetPwd = "password_candidate_11999"
        
        let context = PasswordRecoveryContext(archivePath: "mock.zip", dictionary: largeDict)
        XCTAssertTrue(strategy.canExecute(context: context))
        
        let result = try await strategy.recover(context: context) { pwd in
            return pwd == targetPwd
        }
        
        XCTAssertEqual(result.foundPassword, targetPwd)
        XCTAssertGreaterThanOrEqual(result.attempts, 1)
    }
    
    func testMultiCoreBruteForceRecoveryStrategyTaskCancellation() async throws {
        let strategy = BruteForceRecoveryStrategy()
        let context = PasswordRecoveryContext(archivePath: "mock.zip", charset: "0123456789abcdef", maxBruteForceLength: 3)
        
        XCTAssertTrue(strategy.canExecute(context: context))
        
        // 1. 验证目标匹配
        let result = try await strategy.recover(context: context) { pwd in
            return pwd == "abc"
        }
        XCTAssertEqual(result.foundPassword, "abc")
        
        // 2. 验证 Task 取消响应
        let cancelTask = Task {
            try await strategy.recover(context: context) { pwd in
                try? await Task.sleep(nanoseconds: 10_000_000)
                return false
            }
        }
        cancelTask.cancel()
        let cancelResult = try await cancelTask.value
        XCTAssertNil(cancelResult.foundPassword)
    }
    
    func testTruncatedZipCentralDirectoryReconstructionSalvage() async throws {
        let tempZipPath = sandbox.fileURL(named: "truncated_eocd.zip").path
        let repairedPath = sandbox.fileURL(named: "salvaged_out.zip").path
        
        let inputDir = try sandbox.createSubdirectory("raw_input")
        let docFile = inputDir.appendingPathComponent("salvage_doc.txt")
        try "Crucial Salvage Data Payload".write(to: docFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveEngineFactory.makeWriter(for: .zip)
        try writer.createArchiveSync(outputPath: tempZipPath, format: .zip, level: .store, inputPaths: [docFile.path], options: .defaultClean, password: nil)
        
        // 模拟物理截断：把 End of Central Directory (EOCD) 截断丢弃，仅保留 Local Header 与 Payload
        if let originalData = try? Data(contentsOf: URL(fileURLWithPath: tempZipPath)) {
            let truncatedLen = max(30, originalData.count - 60)
            let truncatedData = originalData.subdata(in: 0..<truncatedLen)
            try truncatedData.write(to: URL(fileURLWithPath: tempZipPath))
        }
        
        let repairStrategy = ZipCentralDirectoryReconstructionStrategy()
        let count = try await repairStrategy.repair(damagedArchivePath: tempZipPath, repairedOutputPath: repairedPath)
        
        XCTAssertGreaterThanOrEqual(count, 1, "应该能从本地 Local Header 扫描中拯救至少 1 个条目")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedPath))
    }
    
    // MARK: - 6. Round 3 Tertiary Audit Extreme Boundary & Performance Tests (第三轮终极极限审计测试)
    
    func testRound3SalvageZipLocalHeadersAndTarBlocksBoundaryProtectionAndCorruptBlockAudit() async throws {
        _ = try sandbox.createSubdirectory("salvage_audit_out").path
        
        // 1. 0 字节全空破坏文件测试
        let zeroData = Data()
        let zipStrategy = ZipCentralDirectoryReconstructionStrategy()
        let tarStrategy = TarTruncatedSalvageStrategy()
        
        let zipZeroPath = sandbox.fileURL(named: "zero.zip").path
        try zeroData.write(to: URL(fileURLWithPath: zipZeroPath))
        let zipZeroCount = try await zipStrategy.repair(damagedArchivePath: zipZeroPath, repairedOutputPath: sandbox.fileURL(named: "zero_out.zip").path)
        XCTAssertEqual(zipZeroCount, 0)
        
        // 2. 100KB 全 0 字节文件测试
        let zerosData = Data(repeating: 0x00, count: 100 * 1024)
        let zipZerosPath = sandbox.fileURL(named: "zeros.zip").path
        try zerosData.write(to: URL(fileURLWithPath: zipZerosPath))
        let zipZerosCount = try await zipStrategy.repair(damagedArchivePath: zipZerosPath, repairedOutputPath: sandbox.fileURL(named: "zeros_out.zip").path)
        XCTAssertEqual(zipZerosCount, 0)
        
        // 3. 随机乱码破坏文件与伪造 Header (如 compSize = 4GB 巨大非法跳跃)
        var garbageBytes = (0..<50_000).map { _ in UInt8.random(in: 0...255) }
        // 注入 Zip signature
        garbageBytes[100] = 0x50; garbageBytes[101] = 0x4B; garbageBytes[102] = 0x03; garbageBytes[103] = 0x04
        // 注入 4GB compSize (0xFF, 0xFF, 0xFF, 0xFF)
        garbageBytes[118] = 0xFF; garbageBytes[119] = 0xFF; garbageBytes[120] = 0xFF; garbageBytes[121] = 0xFF
        let garbageData = Data(garbageBytes)
        
        let garbageZipPath = sandbox.fileURL(named: "garbage.zip").path
        try garbageData.write(to: URL(fileURLWithPath: garbageZipPath))
        let garbageCount = try await zipStrategy.repair(damagedArchivePath: garbageZipPath, repairedOutputPath: sandbox.fileURL(named: "garbage_out.zip").path)
        XCTAssertGreaterThanOrEqual(garbageCount, 0)
        
        // 4. 多块 Tar 归档扫频 (验证 offset > 0 时的 subdata 索引越界防护)
        var multiBlockTarBytes = Data(repeating: 0, count: 512 * 5)
        // 第一块：有效文件名 file1.txt
        let file1Name = "file1.txt".data(using: .utf8)!
        multiBlockTarBytes.replaceSubrange(0..<file1Name.count, with: file1Name)
        // 第一块 filesize = 10 字节 (8进制 "00000000012")
        let file1Size = "00000000012 ".data(using: .ascii)!
        multiBlockTarBytes.replaceSubrange(124..<124 + file1Size.count, with: file1Size)
        
        // 第三块 (offset = 1024)：有效文件名 file2.txt
        let file2Name = "file2.txt".data(using: .utf8)!
        multiBlockTarBytes.replaceSubrange(1024..<1024 + file2Name.count, with: file2Name)
        let file2Size = "00000000012 ".data(using: .ascii)!
        multiBlockTarBytes.replaceSubrange(1024 + 124..<1024 + 124 + file2Size.count, with: file2Size)
        
        let tarPath = sandbox.fileURL(named: "multiblock.tar").path
        try multiBlockTarBytes.write(to: URL(fileURLWithPath: tarPath))
        
        let tarOutPath = sandbox.fileURL(named: "multiblock_out.tar").path
        let tarCount = try await tarStrategy.repair(damagedArchivePath: tarPath, repairedOutputPath: tarOutPath)
        XCTAssertGreaterThanOrEqual(tarCount, 1, "多块 Tar 扫频在 offset > 0 时应无 index out of range 崩溃并挽救有效块")
        
        // 5. 非 0 startIndex 的 Data 切片 (Subdata slice) 越界测试
        let sliceData = garbageData.subdata(in: 50..<4000)
        let sliceZipPath = sandbox.fileURL(named: "slice.zip").path
        try sliceData.write(to: URL(fileURLWithPath: sliceZipPath))
        let sliceCount = try await zipStrategy.repair(damagedArchivePath: sliceZipPath, repairedOutputPath: sandbox.fileURL(named: "slice_out.zip").path)
        XCTAssertGreaterThanOrEqual(sliceCount, 0)
    }
    
    func testRound3MultiCoreBruteForce100PlusTasksGroupCancellationSafety() async throws {
        let strategy = BruteForceRecoveryStrategy()
        let dictStrategy = DictionaryRecoveryStrategy()
        let context = PasswordRecoveryContext(
            archivePath: "mock.zip",
            dictionary: (0..<5000).map { "pwd_\($0)" },
            charset: "0123456789abcdef",
            maxBruteForceLength: 3
        )
        
        // 启动 100+ 高并发分片 TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let task = Task {
                        if i % 2 == 0 {
                            _ = try await strategy.recover(context: context) { pwd in
                                try? await Task.sleep(nanoseconds: 1_000_000)
                                return pwd == "target_pass"
                            }
                        } else {
                            _ = try await dictStrategy.recover(context: context) { pwd in
                                try? await Task.sleep(nanoseconds: 1_000_000)
                                return pwd == "pwd_4999"
                            }
                        }
                    }
                    
                    // 频繁在 100+ TaskGroup 执行过程中 trigger cancel()
                    if i % 3 == 0 {
                        task.cancel()
                    }
                    _ = await task.result
                }
            }
        }
    }
    
    func testRound3SuperLargeDirectoryTreeSamplingPerformance() throws {
        let root = ArchiveCompositeDirectory(name: "LargeFolder", path: "LargeFolder")
        
        // 构造包含 50,000+ 个叶子节点的超大目录树
        let mediaExtensions = [".mp4", ".png", ".jpg", ".mov", ".zip"]
        for i in 0..<50_000 {
            let ext = mediaExtensions[i % mediaExtensions.count]
            let leaf = ArchiveLeafFile(name: "file_\(i)\(ext)", path: "LargeFolder/file_\(i)\(ext)", sizeBytes: 1024)
            root.add(component: leaf)
        }
        
        let start = Date()
        let (totalCount, preCount) = root.sampleLeafExtensions(maxSamples: 2000, preCompressedSet: StoreStrategy.preCompressedExtensions)
        let elapsed = Date().timeIntervalSince(start)
        
        XCTAssertEqual(totalCount, 2000)
        XCTAssertEqual(preCount, 2000)
        XCTAssertLessThan(elapsed, 0.05, "50,000+ 节点采样探查应在 50ms 内完成且内存 0 膨胀")
    }
}

