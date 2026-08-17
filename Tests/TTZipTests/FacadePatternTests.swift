import XCTest
@testable import TTZipCore

final class TestPasswordVaultManager: PasswordVaultManaging, @unchecked Sendable {
    var autoUnlockArchives: Bool = true
    var entries: [PasswordVaultEntry]
    init(entries: [PasswordVaultEntry] = []) {
        self.entries = entries
    }
    func getEntries() -> [PasswordVaultEntry] { return entries }
    func recordUsage(id: UUID) {}
}

final class FacadePatternTests: XCTestCase {
    var sandbox: IsolatedTempSandbox!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = try IsolatedTempSandbox(prefix: "facade_tests")
    }
    
    override func tearDownWithError() throws {
        sandbox?.cleanup()
        sandbox = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 1. TTZipEngineFacade Single-API Compress & Extract Tests
    
    func testTTZipEngineFacadeQuickCompressAndQuickExtract() async throws {
        let inputDir = try sandbox.createSubdirectory("inputs")
        let file1 = inputDir.appendingPathComponent("document.txt")
        let file2 = inputDir.appendingPathComponent("data.json")
        
        try "TTZip Facade Pattern High Level API Test Data".write(to: file1, atomically: true, encoding: .utf8)
        try "{\"status\": \"OK\", \"engine\": \"TTZipEngineFacade\"}".write(to: file2, atomically: true, encoding: .utf8)
        
        let archivePath = sandbox.fileURL(named: "facade_quick.zip").path
        let destDir = sandbox.fileURL(named: "facade_extracted").path
        
        // 1. 测试统一快捷压缩 API
        let compressResult = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path, file2.path],
            outputPath: archivePath,
            format: .zip,
            level: .normal
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath))
        XCTAssertGreaterThan(compressResult.compressedBytes, 0)
        XCTAssertGreaterThan(compressResult.durationSeconds, 0)
        
        // 2. 测试统一快捷解压 API
        let extractResult = try await TTZipEngineFacade.shared.quickExtract(
            archivePath: archivePath,
            destinationDir: destDir,
            autoVaultUnlock: false
        )
        
        XCTAssertEqual(extractResult.archivePath, archivePath)
        XCTAssertEqual(extractResult.destinationDir, destDir)
        XCTAssertGreaterThan(extractResult.durationSeconds, 0)
        
        let extractedFile1 = (destDir as NSString).appendingPathComponent("document.txt")
        let extractedFile2 = (destDir as NSString).appendingPathComponent("data.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile2))
        
        let readText = try String(contentsOfFile: extractedFile1, encoding: .utf8)
        XCTAssertEqual(readText, "TTZip Facade Pattern High Level API Test Data")
    }
    
    // MARK: - 2. TTZipEngineFacade Inspect Archive Test
    
    func testTTZipEngineFacadeInspectArchive() async throws {
        let inputDir = try sandbox.createSubdirectory("inspect_inputs")
        let file1 = inputDir.appendingPathComponent("hello.swift")
        try "print(\"Hello Facade\")".write(to: file1, atomically: true, encoding: .utf8)
        
        let archivePath = sandbox.fileURL(named: "inspect_archive.zip").path
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip
        )
        
        let inspection = try await TTZipEngineFacade.shared.inspectArchive(
            archivePath: archivePath,
            autoVaultUnlock: false
        )
        
        XCTAssertEqual(inspection.archivePath, archivePath)
        XCTAssertFalse(inspection.entries.isEmpty)
        XCTAssertTrue(inspection.securityReport.isSafe)
        XCTAssertEqual(inspection.securityReport.riskLevel, .safe)
    }
    
    // MARK: - 3. TTZipEngineFacade Auto Password Vault Unlock Test
    
    func testTTZipEngineFacadeAutoVaultUnlock() async throws {
        let inputDir = try sandbox.createSubdirectory("vault_inputs")
        let file1 = inputDir.appendingPathComponent("secret.txt")
        try "Top Secret Data Content".write(to: file1, atomically: true, encoding: .utf8)
        
        let archivePath = sandbox.fileURL(named: "encrypted_vault.zip").path
        let destDir = sandbox.fileURL(named: "vault_extracted").path
        let vaultPassword = "VaultSecretPwd123"
        
        // 压缩生成包含密码的归档
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path],
            outputPath: archivePath,
            format: .zip,
            password: vaultPassword
        )
        
        // 清除全局密码缓存以验证独立 MockPasswordVault 依赖注入接管流程
        ArchivePasswordStore.shared.clearAll()
        
        // 使用依赖注入模拟密码库条目
        let mockVault = TestPasswordVaultManager(entries: [
            PasswordVaultEntry(label: "自动化测试密码", password: vaultPassword)
        ])
        let facade = TTZipEngineFacade(passwordVault: mockVault)
        
        // 尝试无需显式输入密码的 autoVaultUnlock 极速解压
        let extractResult = try await facade.quickExtract(
            archivePath: archivePath,
            destinationDir: destDir,
            password: nil,
            autoVaultUnlock: true
        )
        
        XCTAssertTrue(extractResult.isVaultUnlocked)
        XCTAssertEqual(extractResult.unlockedPassword, vaultPassword)
        
        let extractedSecret = (destDir as NSString).appendingPathComponent("secret.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedSecret))
    }
    
    // MARK: - 4. TTZipEngineFacade Integrity & Repair & Recovery Tests
    
    func testTTZipEngineFacadeIntegrityAndRepair() async throws {
        let sampleFile = sandbox.fileURL(named: "hash_sample.bin")
        let data = Data(repeating: 0xAB, count: 1024)
        try data.write(to: sampleFile)
        
        // 测试 verifyIntegrity API
        let hashRes = try await TTZipEngineFacade.shared.verifyIntegrity(archivePath: sampleFile.path)
        XCTAssertEqual(hashRes.filePath, sampleFile.path)
        XCTAssertFalse(hashRes.crc32.isEmpty)
        XCTAssertFalse(hashRes.sha256.isEmpty)
        
        // 测试 repairArchive API
        let damagedZip = sandbox.fileURL(named: "damaged.zip").path
        let repairedZip = sandbox.fileURL(named: "repaired.zip").path
        try data.write(to: URL(fileURLWithPath: damagedZip))
        
        let repairedCount = try await TTZipEngineFacade.shared.repairArchive(damagedPath: damagedZip, outputPath: repairedZip)
        XCTAssertGreaterThanOrEqual(repairedCount, 0)
    }
    
    // MARK: - 5. ArchiveSecurityFacade Audit & ZipSlip Defense Tests
    
    func testArchiveSecurityFacadeAuditAndZipSlipDefense() throws {
        let securityFacade = ArchiveSecurityFacade.shared
        
        // 校验合法路径
        let validPath = securityFacade.validateExtractPath(entryPath: "subfolder/file.txt", destinationDir: "/tmp/extract")
        XCTAssertTrue(validPath)
        
        // 校验 ZipSlip 攻击路径 (包含 ../)
        let maliciousPath1 = securityFacade.validateExtractPath(entryPath: "../../etc/passwd", destinationDir: "/tmp/extract")
        XCTAssertFalse(maliciousPath1)
        
        // 校验绝对路径逃逸
        let maliciousPath2 = securityFacade.validateExtractPath(entryPath: "/etc/shadow", destinationDir: "/tmp/extract")
        XCTAssertFalse(maliciousPath2)
        
        // 校验 entries 扫描
        let safeEntry = ArchiveEntry(path: "docs/readme.txt", uncompressedSize: 100, isDirectory: false)
        let unsafeEntry = ArchiveEntry(path: "script.bat", uncompressedSize: 50, isDirectory: false)
        let zipSlipEntry = ArchiveEntry(path: "../../../var/log/system.log", uncompressedSize: 200, isDirectory: false)
        
        let safeReport = securityFacade.scanEntries([safeEntry])
        XCTAssertTrue(safeReport.isSafe)
        XCTAssertEqual(safeReport.riskLevel, .safe)
        
        let warningReport = securityFacade.scanEntries([unsafeEntry])
        XCTAssertFalse(warningReport.isSafe)
        XCTAssertEqual(warningReport.riskLevel, .warning)
        XCTAssertTrue(warningReport.suspiciousFileNames.contains("script.bat"))
        
        let criticalReport = securityFacade.scanEntries([zipSlipEntry])
        XCTAssertFalse(criticalReport.isSafe)
        XCTAssertTrue(criticalReport.hasZipSlipRisk)
        XCTAssertEqual(criticalReport.riskLevel, .critical)
    }
    
    // MARK: - 6. ArchiveBatchFacade Concurrent Processing Test
    
    func testArchiveBatchFacadeConcurrentCompressAndExtract() async throws {
        let batchFacade = ArchiveBatchFacade.shared
        
        // 创建 3 个独立的待压缩输入目录
        var compressTasks: [BatchCompressTask] = []
        var expectedArchives: [String] = []
        var expectedDestDirs: [String] = []
        
        for i in 1...3 {
            let taskDir = try sandbox.createSubdirectory("batch_input_\(i)")
            let f = taskDir.appendingPathComponent("item_\(i).txt")
            try "Batch Content \(i)".write(to: f, atomically: true, encoding: .utf8)
            
            let outPath = sandbox.fileURL(named: "batch_archive_\(i).zip").path
            let destDir = sandbox.fileURL(named: "batch_dest_\(i)").path
            
            compressTasks.append(BatchCompressTask(
                inputs: [f.path],
                outputPath: outPath,
                format: .zip
            ))
            expectedArchives.append(outPath)
            expectedDestDirs.append(destDir)
        }
        
        // 1. 执行并发批量压缩
        let compressResults = await batchFacade.batchCompress(tasks: compressTasks, maxConcurrent: 2)
        XCTAssertEqual(compressResults.count, 3)
        for res in compressResults {
            XCTAssertTrue(res.success)
            XCTAssertNil(res.errorMessage)
            XCTAssertTrue(FileManager.default.fileExists(atPath: res.targetPath))
        }
        
        // 2. 构建并发批量解压任务
        var extractTasks: [BatchExtractTask] = []
        for i in 0..<3 {
            extractTasks.append(BatchExtractTask(
                archivePath: expectedArchives[i],
                destinationDir: expectedDestDirs[i]
            ))
        }
        
        // 3. 执行并发批量解压
        let extractResults = await batchFacade.batchExtract(tasks: extractTasks, maxConcurrent: 2)
        XCTAssertEqual(extractResults.count, 3)
        for res in extractResults {
            XCTAssertTrue(res.success, "Extract task failed with error: \(res.errorMessage ?? "none")")
            XCTAssertNil(res.errorMessage)
            XCTAssertTrue(FileManager.default.fileExists(atPath: res.targetPath))
        }
    }
    
    // MARK: - 7. TTZipEngineFacade Single Entry Extract & Advanced Options Test
    
    func testTTZipEngineFacadeExtractSingleEntryAndAdvancedOptions() async throws {
        let inputDir = try sandbox.createSubdirectory("single_entry_inputs")
        let file1 = inputDir.appendingPathComponent("single_target.txt")
        let file2 = inputDir.appendingPathComponent("ignored.txt")
        
        try "Target Single File Content".write(to: file1, atomically: true, encoding: .utf8)
        try "Ignored File Content".write(to: file2, atomically: true, encoding: .utf8)
        
        let archivePath = sandbox.fileURL(named: "single_entry_archive.zip").path
        let destDir = sandbox.fileURL(named: "single_entry_extracted").path
        
        let advOpts = ArchiveAdvancedOptions.builder()
            .withZipEncodingUTF8(true)
            .withPreservePosixAttributes(true)
            .build()
            
        let compRes = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path, file2.path],
            outputPath: archivePath,
            format: .zip,
            level: .normal,
            filterOptions: .defaultClean,
            advancedOptions: advOpts
        )
        XCTAssertGreaterThan(compRes.compressedBytes, 0)
        
        // 单项文件提取
        try await TTZipEngineFacade.shared.extractSingleEntry(
            archivePath: archivePath,
            entryPath: "single_target.txt",
            destinationDir: destDir
        )
        
        let extractedTarget = (destDir as NSString).appendingPathComponent("single_target.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedTarget))
        let text = try String(contentsOfFile: extractedTarget, encoding: .utf8)
        XCTAssertEqual(text, "Target Single File Content")
    }
    
    // MARK: - 8. Facade Edge Cases & Error Handling Test
    
    func testTTZipEngineFacadeEdgeCasesAndErrorHandling() async {
        // 1. 不存在的归档路径提取应该抛出 fileNotFound 异常
        do {
            _ = try await TTZipEngineFacade.shared.quickExtract(
                archivePath: "/non_existent_path_ttzip/fake.zip",
                destinationDir: "/tmp"
            )
            XCTFail("Should fail with fileNotFound")
        } catch let err as ArchiveError {
            XCTAssertEqual(err, .fileNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // 2. 空路径单项提取抛出 fileNotFound 异常
        do {
            try await TTZipEngineFacade.shared.extractSingleEntry(
                archivePath: "",
                entryPath: "file.txt",
                destinationDir: "/tmp"
            )
            XCTFail("Should fail with fileNotFound")
        } catch let err as ArchiveError {
            XCTAssertEqual(err, .fileNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - 9. ArchivePasswordStore LRU Capacity & Sensitive Erasure Test
    
    func testArchivePasswordStoreLRUAndErasure() {
        let store = ArchivePasswordStore(maxCapacity: 3)
        store.setPassword("pwd1", for: "/path/1.zip")
        store.setPassword("pwd2", for: "/path/2.zip")
        store.setPassword("pwd3", for: "/path/3.zip")
        
        XCTAssertEqual(store.getPassword(for: "/path/1.zip"), "pwd1")
        XCTAssertEqual(store.getPassword(for: "/path/2.zip"), "pwd2")
        XCTAssertEqual(store.getPassword(for: "/path/3.zip"), "pwd3")
        
        // 访问 /path/1.zip 提升其 LRU 优先级，最久未调用的将变成 /path/2.zip
        _ = store.getPassword(for: "/path/1.zip")
        
        // 插入第 4 个密码，触发 LRU 淘汰掉 /path/2.zip
        store.setPassword("pwd4", for: "/path/4.zip")
        
        XCTAssertNil(store.getPassword(for: "/path/2.zip"))
        XCTAssertEqual(store.getPassword(for: "/path/1.zip"), "pwd1")
        XCTAssertEqual(store.getPassword(for: "/path/3.zip"), "pwd3")
        XCTAssertEqual(store.getPassword(for: "/path/4.zip"), "pwd4")
        
        // 清理与移除测试
        store.removePassword(for: "/path/1.zip")
        XCTAssertNil(store.getPassword(for: "/path/1.zip"))
        
        store.clearAll()
        XCTAssertNil(store.getPassword(for: "/path/3.zip"))
        XCTAssertNil(store.getPassword(for: "/path/4.zip"))
    }
    
    // MARK: - 10. ArchiveBatchFacade High Concurrency Cancellation & Exception Isolation Test
    
    func testArchiveBatchFacadeHighConcurrencyCancellationAndIsolation() async throws {
        let inputDir = try sandbox.createSubdirectory("batch_inputs")
        let file1 = inputDir.appendingPathComponent("batch_1.txt")
        try "Batch Content 1".write(to: file1, atomically: true, encoding: .utf8)
        
        let out1 = sandbox.fileURL(named: "batch_out_1.zip").path
        let out2 = sandbox.fileURL(named: "batch_out_2.zip").path
        
        let task1 = BatchCompressTask(inputs: [file1.path], outputPath: out1, format: .zip)
        // 故意传入非法的输入文件路径测试单任务失败异常隔离
        let task2 = BatchCompressTask(inputs: ["/non_existent_path_file_ttzip.txt"], outputPath: out2, format: .zip)
        
        let batchFacade = ArchiveBatchFacade.shared
        let results = await batchFacade.batchCompress(tasks: [task1, task2], maxConcurrent: 16)
        
        XCTAssertEqual(results.count, 2)
        let res1 = results.first { $0.id == task1.id }
        let res2 = results.first { $0.id == task2.id }
        
        XCTAssertNotNil(res1)
        XCTAssertTrue(res1?.success == true)
        
        XCTAssertNotNil(res2)
        XCTAssertFalse(res2?.success == true)
        XCTAssertNotNil(res2?.errorMessage)
    }
    
    // MARK: - 11. Mock Facades & Protocol Extensions Decoupling Test
    
    func testMockFacadesAndProtocolDecoupling() async throws {
        // 1. 测试 MockTTZipEngineFacade & Protocol Extension 默认参数调用
        let mockEngine: TTZipEngineFacading = MockTTZipEngineFacade()
        let compRes = try await mockEngine.quickCompress(inputs: ["/tmp/a.txt"], outputPath: "/tmp/a.zip")
        XCTAssertEqual(compRes.outputPath, "/tmp/a.zip")
        
        let extRes = try await mockEngine.quickExtract(archivePath: "/tmp/a.zip", destinationDir: "/tmp/out")
        XCTAssertEqual(extRes.destinationDir, "/tmp/out")
        
        try await mockEngine.extractSingleEntry(archivePath: "/tmp/a.zip", entryPath: "a.txt", destinationDir: "/tmp/out")
        
        let inspectRes = try await mockEngine.inspectArchive(archivePath: "/tmp/a.zip")
        XCTAssertEqual(inspectRes.archivePath, "/tmp/a.zip")
        XCTAssertTrue(inspectRes.securityReport.isSafe)
        
        // 2. 测试 MockArchiveSecurityFacade & Protocol Extension 默认参数调用
        let mockSecurity: ArchiveSecurityFacading = MockArchiveSecurityFacade()
        let auditReport = try await mockSecurity.auditArchive(archivePath: "/tmp/a.zip")
        XCTAssertTrue(auditReport.isSafe)
        XCTAssertTrue(mockSecurity.validateExtractPath(entryPath: "file.txt", destinationDir: "/tmp"))
        
        // 3. 测试 MockArchiveBatchFacade & Protocol Extension 默认参数调用
        let mockBatch: ArchiveBatchFacading = MockArchiveBatchFacade()
        let compressTasks = [BatchCompressTask(inputs: ["/tmp/a.txt"], outputPath: "/tmp/a.zip")]
        let batchCompRes = await mockBatch.batchCompress(tasks: compressTasks)
        XCTAssertEqual(batchCompRes.count, 1)
        XCTAssertTrue(batchCompRes[0].success)
        
        let extractTasks = [BatchExtractTask(archivePath: "/tmp/a.zip", destinationDir: "/tmp/out")]
        let batchExtRes = await mockBatch.batchExtract(tasks: extractTasks)
        XCTAssertEqual(batchExtRes.count, 1)
        XCTAssertTrue(batchExtRes[0].success)
        
        // 4. 测试 MockArchiveBenchmarkFacade & Protocol Extension 默认参数调用
        let mockBenchmark: ArchiveBenchmarkFacading = MockArchiveBenchmarkFacade()
        let benchRes = try await mockBenchmark.runQuickBenchmark()
        XCTAssertGreaterThan(benchRes.throughputMBs, 0)
        mockBenchmark.cleanCache()
        XCTAssertTrue((mockBenchmark as? MockArchiveBenchmarkFacade)?.cleanCacheCalled == true)
    }

}

