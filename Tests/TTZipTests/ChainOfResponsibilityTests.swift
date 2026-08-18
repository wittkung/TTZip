// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// Mock （ ）
final class MockAuditValidationHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    let name: String
    let shouldPass: Bool
    let failureError: ArchiveValidationError?
    
    private(set) var processedCount: Int = 0
    private let lock = NSLock()
    
    init(
        name: String,
        shouldPass: Bool = true,
        failureError: ArchiveValidationError? = nil,
        nextHandler: ArchiveValidationHandlerProtocol? = nil
    ) {
        self.name = name
        self.shouldPass = shouldPass
        self.failureError = failureError
        super.init(nextHandler: nextHandler)
    }
    
    override func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        lock.lock()
        processedCount += 1
        lock.unlock()
        
        if shouldPass {
            return .success
        } else {
            return .failure(failureError ?? .custom(message: "MockHandler \(name) 拦截"))
        }
    }
    
    var executionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return processedCount
    }
}

final class ChainOfResponsibilityTests: XCTestCase {
    private var tempDir: String!
    private var tempZipPath: String!
    private var tempTxtPath: String!
    
    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZip_ChainTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        tempTxtPath = (tempDir as NSString).appendingPathComponent("sample.txt")
        try? "Hello World TTZip Chain".write(toFile: tempTxtPath, atomically: true, encoding: .utf8)
        
        // Zip PK\x03\x04
        tempZipPath = (tempDir as NSString).appendingPathComponent("sample.zip")
        var zipBytes: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x0A, 0x00, 0x00, 0x00]
        let zipData = Data(bytes: &zipBytes, count: zipBytes.count)
        try? zipData.write(to: URL(fileURLWithPath: tempZipPath))
    }
    
    override func tearDown() {
        if let dir = tempDir {
            try? FileManager.default.removeItem(atPath: dir)
        }
        super.tearDown()
    }
    
    // MARK: - 1. 、 setNext
    
    func testChainAssemblyAndTraversal() throws {
        let h1 = MockAuditValidationHandler(name: "Step1", shouldPass: true)
        let h2 = MockAuditValidationHandler(name: "Step2", shouldPass: true)
        let h3 = MockAuditValidationHandler(name: "Step3", shouldPass: true)
        
        h1.setNext(handler: h2).setNext(handler: h3)
        
        let ctx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        let result = try h1.handle(context: ctx)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(h1.executionCount, 1)
        XCTAssertEqual(h2.executionCount, 1)
        XCTAssertEqual(h3.executionCount, 1)
    }
    
    // MARK: - 2. Short-Circuit Interception
    
    func testShortCircuitInterception() throws {
        let h1 = MockAuditValidationHandler(name: "Step1", shouldPass: true)
        let h2 = MockAuditValidationHandler(name: "Step2", shouldPass: false, failureError: .custom(message: "Step2 拒绝放行"))
        let h3 = MockAuditValidationHandler(name: "Step3", shouldPass: true)
        
        h1.setNext(handler: h2).setNext(handler: h3)
        
        let ctx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        let result = try h1.handle(context: ctx)
        
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error, .custom(message: "Step2 拒绝放行"))
        
        XCTAssertEqual(h1.executionCount, 1)
        XCTAssertEqual(h2.executionCount, 1)
        XCTAssertEqual(h3.executionCount, 0, "Step2 发生拦截后，Step3 绝不应该被执行")
    }
    
    // MARK: - 3. Custom Handler Insertion
    
    func testCustomHandlerInsertionIntoPipeline() throws {
        class FileExtensionGatekeeperHandler: BaseArchiveValidationHandler, @unchecked Sendable {
            let forbiddenExt: String
            init(forbiddenExt: String) { self.forbiddenExt = forbiddenExt }
            
            override func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
                for p in context.sourcePaths {
                    if p.lowercased().hasSuffix("." + forbiddenExt.lowercased()) {
                        return .failure(.custom(message: "禁止打包 .\(forbiddenExt) 类型文件"))
                    }
                }
                return .success
            }
        }
        
        let pipeline = ArchiveValidationPipeline.buildDefaultCompressPipeline()
        let initialCount = pipeline.count
        
        let customGatekeeper = FileExtensionGatekeeperHandler(forbiddenExt: "exe")
        pipeline.addHandler(customGatekeeper)
        
        XCTAssertEqual(pipeline.count, initialCount + 1)
        
        let exePath = (tempDir as NSString).appendingPathComponent("bad.exe")
        try? "malware".write(toFile: exePath, atomically: true, encoding: .utf8)
        
        let ctx = ArchiveValidationContext.forCompress(sourcePaths: [exePath], destinationPath: tempZipPath)
        let res = try pipeline.validate(context: ctx)
        
        XCTAssertFalse(res.isSuccess)
        XCTAssertEqual(res.error, .custom(message: "禁止打包 .exe 类型文件"))
    }
    
    // MARK: - 4. FileExistenceHandler
    
    func testFileExistenceHandler() throws {
        let handler = FileExistenceHandler()
        
        // Verify expected invariant
        let validCtx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        let validRes = try handler.handle(context: validCtx)
        XCTAssertTrue(validRes.isSuccess)
        
        // Verify expected invariant
        let fakePath = (tempDir as NSString).appendingPathComponent("does_not_exist.txt")
        let invalidCtx = ArchiveValidationContext.forCompress(sourcePaths: [fakePath], destinationPath: tempZipPath)
        let invalidRes = try handler.handle(context: invalidCtx)
        
        XCTAssertFalse(invalidRes.isSuccess)
        XCTAssertEqual(invalidRes.error, .fileNotFound(path: fakePath))
        
        // Verify expected invariant
        let emptyCtx = ArchiveValidationContext.forCompress(sourcePaths: [], destinationPath: tempZipPath)
        let emptyRes = try handler.handle(context: emptyCtx)
        XCTAssertFalse(emptyRes.isSuccess)
    }
    
    // MARK: - 5. ZipSlipSecurityHandler Path Traversal & Symlink Escape
    
    func testZipSlipSecurityHandler() throws {
        let handler = ZipSlipSecurityHandler()
        
        // Verify expected invariant
        let safeCtx = ArchiveValidationContext.forExtract(archivePath: tempZipPath, destinationDir: tempDir)
        let safeRes = try handler.handle(context: safeCtx)
        XCTAssertTrue(safeRes.isSuccess)
        
        // ../
        let maliciousPath = (tempDir as NSString).appendingPathComponent("../../../etc/passwd")
        let badCtx = ArchiveValidationContext.forExtract(archivePath: maliciousPath, destinationDir: tempDir)
        let badRes = try handler.handle(context: badCtx)
        
        XCTAssertFalse(badRes.isSuccess)
        if case .failure(let err) = badRes {
            if case .zipSlipDetected(let p, _) = err {
                XCTAssertEqual(p, maliciousPath)
            } else {
                XCTFail("应匹配 zipSlipDetected 错误，实际: \(err)")
            }
        } else {
            XCTFail("应该拦截 ZipSlip")
        }
    }
    
    // MARK: - 6. DiskSpaceHandler
    
    func testDiskSpaceHandler() throws {
        let handler = DiskSpaceHandler()
        
        // Verify expected invariant
        let reasonableCtx = ArchiveValidationContext.forExtract(
            archivePath: tempZipPath,
            destinationDir: tempDir,
            estimatedSize: 1024 * 1024 // 1MB
        )
        let okRes = try handler.handle(context: reasonableCtx)
        XCTAssertTrue(okRes.isSuccess)
        
        // (10,000 TB)
        let hugeCtx = ArchiveValidationContext.forExtract(
            archivePath: tempZipPath,
            destinationDir: tempDir,
            estimatedSize: 10_000_000_000_000_000
        )
        let hugeRes = try handler.handle(context: hugeCtx)
        XCTAssertFalse(hugeRes.isSuccess)
        if case .failure(let err) = hugeRes {
            if case .insufficientDiskSpace(let req, _) = err {
                XCTAssertEqual(req, 10_000_000_000_000_000)
            } else {
                XCTFail("应匹配 insufficientDiskSpace 错误，实际: \(err)")
            }
        }
    }
    
    // MARK: - 7. ArchiveHeaderMagicHandler
    
    func testArchiveHeaderMagicHandler() throws {
        let handler = ArchiveHeaderMagicHandler()
        
        // Zip ( 4 PK\x03\x04)
        let validZipCtx = ArchiveValidationContext.forExtract(archivePath: tempZipPath, destinationDir: tempDir)
        let zipRes = try handler.handle(context: validZipCtx)
        XCTAssertTrue(zipRes.isSuccess)
        
        // Verify expected invariant
        let corruptPath = (tempDir as NSString).appendingPathComponent("corrupted.bin")
        var dummyBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x00]
        try? Data(bytes: &dummyBytes, count: dummyBytes.count).write(to: URL(fileURLWithPath: corruptPath))
        
        let corruptCtx = ArchiveValidationContext.forExtract(archivePath: corruptPath, destinationDir: tempDir)
        let corruptRes = try handler.handle(context: corruptCtx)
        
        XCTAssertFalse(corruptRes.isSuccess)
        if case .failure(let err) = corruptRes {
            if case .invalidHeaderMagic = err {
                // Verify expected invariant
            } else {
                XCTFail("应匹配 invalidHeaderMagic 错误，实际: \(err)")
            }
        }
    }
    
    // MARK: - 8. LicenseGatekeeperHandler Pro
    
    func testLicenseGatekeeperHandler() throws {
        let handler = LicenseGatekeeperHandler()
        
        // License
        LicenseManager.simulateFreeTierInTests = true
        defer { LicenseManager.simulateFreeTierInTests = false }
        
        // 1. Split-volume gating
        let splitCtx = ArchiveValidationContext.forCompress(
            sourcePaths: [tempTxtPath],
            destinationPath: tempZipPath,
            splitSize: 10 * 1024 * 1024
        )
        let splitRes = try handler.handle(context: splitCtx)
        XCTAssertFalse(splitRes.isSuccess)
        if case .failure(let err) = splitRes {
            XCTAssertEqual(err, .licenseRequired(feature: "Volume Splitting"))
        }
        
        // 2. Encryption gating
        let pwdCtx = ArchiveValidationContext.forCompress(
            sourcePaths: [tempTxtPath],
            destinationPath: tempZipPath,
            password: "SecretPassword123"
        )
        let pwdRes = try handler.handle(context: pwdCtx)
        XCTAssertFalse(pwdRes.isSuccess)
        if case .failure(let err) = pwdRes {
            XCTAssertEqual(err, .licenseRequired(feature: "AES-256 Encryption"))
        }
        
        // 3. Ultra level gating
        let ultraCtx = ArchiveValidationContext.forCompress(
            sourcePaths: [tempTxtPath],
            destinationPath: tempZipPath,
            level: .ultra
        )
        let ultraRes = try handler.handle(context: ultraCtx)
        XCTAssertFalse(ultraRes.isSuccess)
        if case .failure(let err) = ultraRes {
            XCTAssertEqual(err, .licenseRequired(feature: "Ultra Compression Level"))
        }
    }
    
    // MARK: - 9. ArchiveValidationPipeline
    
    func testValidationPipelines() throws {
        // 1.
        let compressPipeline = ArchiveValidationPipeline.buildDefaultCompressPipeline()
        let compressCtx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        let cRes = try compressPipeline.validate(context: compressCtx)
        XCTAssertTrue(cRes.isSuccess)
        
        // 2.
        let extractPipeline = ArchiveValidationPipeline.buildDefaultExtractPipeline()
        let extractCtx = ArchiveValidationContext.forExtract(archivePath: tempZipPath, destinationDir: tempDir)
        let eRes = try extractPipeline.validate(context: extractCtx)
        XCTAssertTrue(eRes.isSuccess)
        
        // 3.
        let inspectPipeline = ArchiveValidationPipeline.buildDefaultInspectPipeline()
        let inspectCtx = ArchiveValidationContext.forInspect(archivePath: tempZipPath)
        let iRes = try inspectPipeline.validate(context: inspectCtx)
        XCTAssertTrue(iRes.isSuccess)
        
        // 4.
        let repairPipeline = ArchiveValidationPipeline.buildDefaultRepairPipeline()
        let repairCtx = ArchiveValidationContext.forRepair(damagedPath: tempZipPath, outputPath: (tempDir as NSString).appendingPathComponent("fixed.zip"))
        let rRes = try repairPipeline.validate(context: repairCtx)
        XCTAssertTrue(rRes.isSuccess)
    }
    
    // MARK: - 10. Concurrent Safety & Edge Cases
    
    func testHighConcurrencyThreadSafety() async throws {
        let pipeline = ArchiveValidationPipeline.buildDefaultCompressPipeline()
        let ctx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let mock = MockAuditValidationHandler(name: "Parallel_\(i)")
                    pipeline.addHandler(mock)
                    let res = (try? pipeline.validate(context: ctx)) ?? .failure(.custom(message: "Failed"))
                    return res.isSuccess
                }
            }
            
            var successCount = 0
            for await ok in group {
                if ok { successCount += 1 }
            }
            XCTAssertEqual(successCount, 100, "100 个并发校验任务必须全部安全且无数据竞争地完成")
        }
    }
    
    // MARK: - 11. setNext
    
    func testSelfReferenceCyclePreventionAndConcurrentSetNext() throws {
        let h1 = MockAuditValidationHandler(name: "H1")
        // safe guard
        let ret = h1.setNext(handler: h1)
        XCTAssertTrue(ret === h1)
        XCTAssertNil(h1.nextHandler)
        
        // nextHandler handle
        let h2 = MockAuditValidationHandler(name: "H2")
        let ctx = ArchiveValidationContext.forCompress(sourcePaths: [tempTxtPath], destinationPath: tempZipPath)
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            if i % 2 == 0 {
                h1.setNext(handler: h2)
            } else {
                _ = try? h1.handle(context: ctx)
            }
        }
    }
    
    // MARK: - 12. 20+ 、 SFX
    
    func testArchiveHeaderMagicExtremeBoundariesAndSFX() throws {
        let handler = ArchiveHeaderMagicHandler()
        
        // 1. 0
        let emptyPath = (tempDir as NSString).appendingPathComponent("empty.bin")
        FileManager.default.createFile(atPath: emptyPath, contents: Data())
        let emptyCtx = ArchiveValidationContext.forExtract(archivePath: emptyPath, destinationDir: tempDir)
        let emptyRes = try handler.handle(context: emptyCtx)
        XCTAssertFalse(emptyRes.isSuccess)
        if case .failure(let err) = emptyRes {
            XCTAssertEqual(err, .invalidHeaderMagic(expected: "Non-empty Archive File", actual: "0 bytes (Empty File)"))
        }
        
        // 2. 4 (1, 2, 3 )
        for len in 1...3 {
            let smallPath = (tempDir as NSString).appendingPathComponent("small_\(len).bin")
            let bytes = [UInt8](repeating: 0x50, count: len)
            FileManager.default.createFile(atPath: smallPath, contents: Data(bytes))
            let smallCtx = ArchiveValidationContext.forExtract(archivePath: smallPath, destinationDir: tempDir)
            let smallRes = try handler.handle(context: smallCtx)
            XCTAssertFalse(smallRes.isSuccess, "\(len) 字节文件应校验失败但绝对不能发生 Out of Range 崩溃")
        }
        
        // 3. Self-Extracting (.exe) 7z
        let sfx7zPath = (tempDir as NSString).appendingPathComponent("installer.exe")
        var sfx7zBytes: [UInt8] = [0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00] // MZ header stub
        // 64 stub 7z 37 7A BC AF 27 1C
        sfx7zBytes.append(contentsOf: [UInt8](repeating: 0x00, count: 64))
        sfx7zBytes.append(contentsOf: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        FileManager.default.createFile(atPath: sfx7zPath, contents: Data(sfx7zBytes))
        
        let sfx7zCtx = ArchiveValidationContext(sourcePaths: [sfx7zPath], operation: .extract, format: .sevenZip)
        let sfx7zRes = try handler.handle(context: sfx7zCtx)
        XCTAssertTrue(sfx7zRes.isSuccess, "SFX 7z 自解压包魔数扫描必须成功放行")
        
        // 4. Tar.gz
        let tarGzPath = (tempDir as NSString).appendingPathComponent("archive.tar.gz")
        let gzipHeaderBytes: [UInt8] = [0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00]
        FileManager.default.createFile(atPath: tarGzPath, contents: Data(gzipHeaderBytes))
        
        let tarCtx = ArchiveValidationContext(sourcePaths: [tarGzPath], operation: .extract, format: .tar)
        let tarRes = try handler.handle(context: tarCtx)
        XCTAssertTrue(tarRes.isSuccess, "Tar 校验应识别内含 Gzip 魔数的 .tar.gz 文件")
    }
    
    // MARK: - 13. DiskSpaceHandler
    
    func testDiskSpaceHandlerNonExistentTargetDeepAncestorLookup() throws {
        let handler = DiskSpaceHandler()
        
        // 3
        let deepNonExistentPath = (tempDir as NSString).appendingPathComponent("NonExistent_L1/NonExistent_L2/NonExistent_L3/output.zip")
        
        let ctx = ArchiveValidationContext.forExtract(
            archivePath: tempZipPath,
            destinationDir: deepNonExistentPath,
            estimatedSize: 1024 * 1024 // 1MB
        )
        
        let res = try handler.handle(context: ctx)
        XCTAssertTrue(res.isSuccess, "不存在深层目标目录时，DiskSpaceHandler 应向上寻找已存在的祖先目录并获取可用空间")
    }
    
    // MARK: - 14. ZipSlip 、URL 、Windows NUL
    
    func testZipSlipAdvancedAttacksInterception() throws {
        let handler = ZipSlipSecurityHandler()
        
        // 1. URL (%2e%2e/)
        let urlEncodedPath = "%2e%2e/%2e%2e/etc/passwd"
        let ctx1 = ArchiveValidationContext.forExtract(archivePath: urlEncodedPath, destinationDir: tempDir)
        let res1 = try handler.handle(context: ctx1)
        XCTAssertFalse(res1.isSuccess)
        
        // 2. Windows (..\..\system32)
        let winPath = "..\\..\\Windows\\System32\\cmd.exe"
        let ctx2 = ArchiveValidationContext.forExtract(archivePath: winPath, destinationDir: tempDir)
        let res2 = try handler.handle(context: ctx2)
        XCTAssertFalse(res2.isSuccess)
        
        // 3. NUL (\0)
        let nulPath = "archive.zip\0/etc/passwd"
        let ctx3 = ArchiveValidationContext.forExtract(archivePath: nulPath, destinationDir: tempDir)
        let res3 = try handler.handle(context: ctx3)
        XCTAssertFalse(res3.isSuccess)
        
        // 4. POSIX / (/etc/passwd)
        let posixPath = "/etc/passwd"
        let ctx4 = ArchiveValidationContext.forExtract(archivePath: tempZipPath, destinationDir: posixPath)
        let res4 = try handler.handle(context: ctx4)
        XCTAssertFalse(res4.isSuccess)
    }
    
    // MARK: - 15. DiskSpaceHandler `/`
    
    func testDiskSpaceHandlerRootBoundaryAndRelativeLookup() throws {
        let handler = DiskSpaceHandler()
        
        // 1. /nonexistent1/nonexistent2/nonexistent3/out.zip
        let deepRootPath = "/nonexistent1/nonexistent2/nonexistent3/out.zip"
        let rootCtx = ArchiveValidationContext.forExtract(
            archivePath: tempZipPath,
            destinationDir: deepRootPath,
            estimatedSize: 1024
        )
        let rootRes = try handler.handle(context: rootCtx)
        XCTAssertTrue(rootRes.isSuccess, "深层不存在绝对路径应安全终止于根节点 / 并读取根卷可用空间")
        
        // 2. nonexistent1/nonexistent2/out.zip
        let relativePath = "nonexistent1/nonexistent2/out.zip"
        let relCtx = ArchiveValidationContext.forExtract(
            archivePath: tempZipPath,
            destinationDir: relativePath,
            estimatedSize: 1024
        )
        let relRes = try handler.handle(context: relCtx)
        XCTAssertTrue(relRes.isSuccess, "深层不存在相对路径应终止于当前目录 . 并成功检索空间")
    }
    
    // MARK: - 16. ArchiveHeaderMagicHandler 2000 Zero FD
    
    func testArchiveHeaderMagicZeroFDLeakSweep() throws {
        let handler = ArchiveHeaderMagicHandler()
        let extractCtx = ArchiveValidationContext.forExtract(archivePath: tempZipPath, destinationDir: tempDir)
        
        // 2000 ， FD Too many open files
        for _ in 0..<2000 {
            let res = try handler.handle(context: extractCtx)
            XCTAssertTrue(res.isSuccess)
        }
    }
    
    // MARK: - 17. ArchiveValidationPipeline Handler
    
    func testPipelineDuplicateRegistrationPreventionAndHighConcurrency() async throws {
        let pipeline = ArchiveValidationPipeline()
        let handlerA = FileExistenceHandler()
        let handlerB = DiskSpaceHandler()
        
        // Handler
        pipeline.addHandler(handlerA)
        pipeline.addHandler(handlerB)
        pipeline.addHandler(handlerA) // 应自动被 deduplicate
        
        XCTAssertEqual(pipeline.count, 2, "重复注册同一 Handler 实例必须被安全防重机制过滤")
        
        let zipPath = self.tempZipPath!
        let targetDir = self.tempDir!
        
        // 100+ validate
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<150 {
                group.addTask {
                    let p = ArchiveValidationPipeline.buildDefaultExtractPipeline()
                    let ctx = ArchiveValidationContext.forExtract(archivePath: zipPath, destinationDir: targetDir)
                    return (try? p.validate(context: ctx))?.isSuccess ?? false
                }
            }
            
            var okCount = 0
            for await ok in group {
                if ok { okCount += 1 }
            }
            XCTAssertEqual(okCount, 150, "150 个并发建链与校验任务必须 100% 成功且线程隔离")
        }
    }
}

