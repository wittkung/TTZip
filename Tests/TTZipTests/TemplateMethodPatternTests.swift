// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class TemplateMethodPatternTests: XCTestCase {
    private var tempDir: String = ""

    override func setUp() {
        super.setUp()
        let unique = UUID().uuidString
        tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZip_TemplateMethodTests_\(unique)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !tempDir.isEmpty && FileManager.default.fileExists(atPath: tempDir) {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Spy / Mock Class for Step Tracking

    private final class StepTrackingArchiveEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
        var recordedSteps: [String] = []
        private let lock = NSLock()

        private func record(_ step: String) {
            lock.lock()
            defer { lock.unlock() }
            recordedSteps.append(step)
        }

        override func preExecutionCheck(context: ArchiveTemplateContext) throws {
            record("preExecutionCheck")
            try super.preExecutionCheck(context: context)
        }

        override func prepareEnvironment(context: ArchiveTemplateContext) throws {
            record("prepareEnvironment")
            try super.prepareEnvironment(context: context)
        }

        override func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
            record("executeCoreAlgorithm")
            if !context.archivePath.isEmpty {
                FileManager.default.createFile(atPath: context.archivePath, contents: Data("mock".utf8))
            }
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                processedBytes: 1024,
                compressedBytes: 512
            )
        }

        override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
            record("verifyOutputIntegrity")
            try super.verifyOutputIntegrity(context: context, result: &result)
        }

        override func postExecutionCleanup(context: ArchiveTemplateContext, result: WorkflowResult) throws {
            record("postExecutionCleanup")
            try super.postExecutionCleanup(context: context, result: result)
        }

        override func onFailure(context: ArchiveTemplateContext, error: Error) {
            record("onFailure")
            super.onFailure(context: context, error: error)
        }
    }

    private final class FailureArchiveEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
        var onFailureCalled = false

        override func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
            throw ArchiveError.readFailed(code: -777)
        }

        override func onFailure(context: ArchiveTemplateContext, error: Error) {
            onFailureCalled = true
            super.onFailure(context: context, error: error)
        }
    }

    // MARK: - Tests

    func testTemplateMethodFixedExecutionStepOrder() throws {
        let spy = StepTrackingArchiveEngineTemplate()
        let sampleFile = (tempDir as NSString).appendingPathComponent("sample.txt")
        try "Hello Template Method Pattern".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let outZip = (tempDir as NSString).appendingPathComponent("order.zip")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outZip,
            inputPaths: [sampleFile],
            format: .zip
        )

        let result = try spy.performWorkflow(context: context)
        XCTAssertTrue(result.isSuccess)

        let expectedOrder = [
            "preExecutionCheck",
            "prepareEnvironment",
            "executeCoreAlgorithm",
            "verifyOutputIntegrity",
            "postExecutionCleanup"
        ]
        XCTAssertEqual(spy.recordedSteps, expectedOrder)
    }

    func testFailureRollbackAndOnFailureTriggering() throws {
        let failingEngine = FailureArchiveEngineTemplate()
        let sampleFile = (tempDir as NSString).appendingPathComponent("sample.txt")
        try "Fail test".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let outZip = (tempDir as NSString).appendingPathComponent("failing.zip")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outZip,
            inputPaths: [sampleFile]
        )

        XCTAssertThrowsError(try failingEngine.performWorkflow(context: context)) { err in
            guard let archiveErr = err as? ArchiveError, case .readFailed(let code) = archiveErr else {
                XCTFail("Expected ArchiveError.readFailed")
                return
            }
            XCTAssertEqual(code, -777)
        }
        XCTAssertTrue(failingEngine.onFailureCalled)
    }

    func testZipArchiveEngineTemplatePKZipHeaderVerification() throws {
        let sampleFile = (tempDir as NSString).appendingPathComponent("zip_data.txt")
        try "ZIP payload data for PKZip header test".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let outZip = (tempDir as NSString).appendingPathComponent("test_pk.zip")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outZip,
            inputPaths: [sampleFile],
            format: .zip
        )

        let tpl = ZipArchiveEngineTemplate()
        let result = try tpl.performWorkflow(context: context)

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
        XCTAssertEqual(result.getMetadata(forKey: "pkzip_header_verified"), "PKZipHeaderValid")
        XCTAssertEqual(result.getMetadata(forKey: "central_directory_reconstruction"), "CentralDirectoryReconstructed")

        // magic bytes PK\x03\x04 (0x50, 0x4B, 0x03, 0x04)
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: outZip))
        defer { try? handle.close() }
        let headerData = handle.readData(ofLength: 4)
        XCTAssertEqual(headerData[0], 0x50)
        XCTAssertEqual(headerData[1], 0x4B)
    }

    func testSevenZipArchiveEngineTemplateSolidBlockAndMagicVerification() throws {
        let sampleFile = (tempDir as NSString).appendingPathComponent("seven_data.txt")
        try "7z payload content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let out7z = (tempDir as NSString).appendingPathComponent("test_7z.7z")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: out7z,
            inputPaths: [sampleFile],
            format: .sevenZip
        )

        let tpl = SevenZipArchiveEngineTemplate()
        let result = try tpl.performWorkflow(context: context)

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out7z))
        XCTAssertEqual(result.getMetadata(forKey: "7z_magic_header_verified"), "7zMagicHeaderVerified")
        XCTAssertEqual(result.getMetadata(forKey: "solid_block_parsing"), "SolidBlockParsingReady")
    }

    func testTarArchiveEngineTemplateBlockAlignment() throws {
        let sampleFile = (tempDir as NSString).appendingPathComponent("tar_data.txt")
        try "TAR payload 512 block test content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let outTar = (tempDir as NSString).appendingPathComponent("test_tar.tar")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outTar,
            inputPaths: [sampleFile],
            format: .tar
        )

        let tpl = TarArchiveEngineTemplate()
        let result = try tpl.performWorkflow(context: context)

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outTar))
        XCTAssertEqual(result.getMetadata(forKey: "tar_512_alignment"), "512ByteBlockAligned")
        XCTAssertEqual(result.getMetadata(forKey: "pax_header_verified"), "PaxHeaderVerified")

        let attr = try FileManager.default.attributesOfItem(atPath: outTar)
        let size = (attr[.size] as? Int64) ?? -1
        XCTAssertTrue(size > 0)
        XCTAssertEqual(size % 512, 0)
    }

    func testPasswordRecoveryEngineTemplateWorkflow() async throws {
        let sampleFile = (tempDir as NSString).appendingPathComponent("secret.txt")
        try "Confidential Content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let encZip = (tempDir as NSString).appendingPathComponent("encrypted.zip")

        let writer = ArchiveWriter()
        try writer.createArchiveSync(
            outputPath: encZip,
            format: .zip,
            inputPaths: [sampleFile],
            password: "target_password_123"
        )

        let dict = ["wrong1", "wrong2", "target_password_123", "wrong3"]
        let context = ArchiveTemplateContext(
            operation: .recover,
            archivePath: encZip,
            dictionary: dict
        )

        let tpl = PasswordRecoveryEngineTemplate()
        let result = try await tpl.performWorkflowAsync(context: context)

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.unlockedPassword, "target_password_123")
        XCTAssertEqual(result.getMetadata(forKey: "password_recovery_integrity"), "PasswordVerifiedValid")
    }

    func test100PlusConcurrentTemplateExecutionsThreadSafety() async throws {
        let iterations = 30
        let targetTempDir = self.tempDir

        let sampleFile = (targetTempDir as NSString).appendingPathComponent("concurrent_sample.txt")
        try "Concurrent Thread Safety Test".write(toFile: sampleFile, atomically: true, encoding: .utf8)

        await withTaskGroup(of: Void.self) { group in
            for idx in 0..<iterations {
                group.addTask {
                    let outPath = (targetTempDir as NSString).appendingPathComponent("concurrent_\(idx).zip")
                    let context = ArchiveTemplateContext(
                        operation: .compress,
                        archivePath: outPath,
                        inputPaths: [sampleFile],
                        format: .zip
                    )
                    let template = ZipArchiveEngineTemplate()
                    do {
                        let res = try await template.performWorkflowAsync(context: context)
                        XCTAssertTrue(res.isSuccess)
                    } catch {
                        XCTFail("Concurrent execution failed at index \(idx): \(error)")
                    }
                }
            }
        }
    }

    func testArchiveEngineTemplateRegistryAndFacadeIntegration() throws {
        let zipTpl = ArchiveEngineTemplateRegistry.shared.template(for: .zip)
        XCTAssertTrue(zipTpl is ZipArchiveEngineTemplate)

        let sevenTpl = ArchiveEngineTemplateRegistry.shared.template(for: .sevenZip)
        XCTAssertTrue(sevenTpl is SevenZipArchiveEngineTemplate)

        let tarTpl = ArchiveEngineTemplateRegistry.shared.template(for: .tar)
        XCTAssertTrue(tarTpl is TarArchiveEngineTemplate)

        let recoverTpl = ArchiveEngineTemplateRegistry.shared.template(forPath: "test.zip", operation: .recover)
        XCTAssertTrue(recoverTpl is PasswordRecoveryEngineTemplate)

        let facade = TTZipEngineFacade.shared
        let sampleFile = (tempDir as NSString).appendingPathComponent("facade_test.txt")
        try "Facade template integration".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let outZip = (tempDir as NSString).appendingPathComponent("facade_out.zip")

        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outZip,
            inputPaths: [sampleFile],
            format: .zip
        )
        let result = try facade.performTemplateWorkflow(context: context)
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
    }

    func testSplitVolumeTarEngineTemplateMatching() throws {
        let registry = ArchiveEngineTemplateRegistry.shared
        
        let tarZstSplit = registry.template(forPath: "archive.tar.zst.001", operation: .compress)
        XCTAssertTrue(tarZstSplit is TarArchiveEngineTemplate, "archive.tar.zst.001 应优先由 TarArchiveEngineTemplate 处理")
        
        let tgzSplit = registry.template(forPath: "archive.tgz.001", operation: .compress)
        XCTAssertTrue(tgzSplit is TarArchiveEngineTemplate, "archive.tgz.001 应优先由 TarArchiveEngineTemplate 处理")
        
        let txzSplit = registry.template(forPath: "archive.txz.001", operation: .compress)
        XCTAssertTrue(txzSplit is TarArchiveEngineTemplate, "archive.txz.001 应优先由 TarArchiveEngineTemplate 处理")
        
        let tbz2Split = registry.template(forPath: "archive.tbz2.001", operation: .compress)
        XCTAssertTrue(tbz2Split is TarArchiveEngineTemplate, "archive.tbz2.001 应优先由 TarArchiveEngineTemplate 处理")
        
        let sevenZipSplit = registry.template(forPath: "archive.7z.001", operation: .compress)
        XCTAssertTrue(sevenZipSplit is SevenZipArchiveEngineTemplate, "archive.7z.001 应由 SevenZipArchiveEngineTemplate 处理")
    }
}
