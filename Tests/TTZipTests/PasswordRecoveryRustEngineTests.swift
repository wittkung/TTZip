// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class PasswordRecoveryRustEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_pwd_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    func testZipCryptoPasswordRecoveryFastInMemory() async throws {
        let archivePath = tempDirectory.appendingPathComponent("test_zipcrypto.zip").path
        let testPassword = "ZipCryptoPassword2026"
        
        let sampleFile = tempDirectory.appendingPathComponent("sample.txt")
        try "Confidential Payload".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .fastest,
            inputPaths: [sampleFile.path],
            password: testPassword
        )
        
        let candidates = ["123456", "admin", testPassword, "guest"]
        let found = PasswordRecoveryEngine.recoverFastInMemory(passwords: candidates, archivePath: archivePath)
        XCTAssertEqual(found, testPassword)
        
        let wrongCandidates = ["wrong1", "wrong2", "wrong3"]
        let notFound = PasswordRecoveryEngine.recoverFastInMemory(passwords: wrongCandidates, archivePath: archivePath)
        XCTAssertNil(notFound)
    }

    func testPasswordRecoveryEngineFullWorkflowWithState() async throws {
        let archivePath = tempDirectory.appendingPathComponent("test_recovery_wf.zip").path
        let testPassword = "TargetSecretKey42"
        
        let sampleFile = tempDirectory.appendingPathComponent("sample_wf.txt")
        try "Top Secret In-Memory Data".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .fastest,
            inputPaths: [sampleFile.path],
            password: testPassword
        )
        
        let engine = PasswordRecoveryEngine()
        let dict = ["dummy1", "dummy2", testPassword, "dummy3"]
        let result = try await engine.recoverPassword(archivePath: archivePath, dictionary: dict)
        
        XCTAssertEqual(result.foundPassword, testPassword)
        XCTAssertGreaterThan(result.totalAttempts, 0)
        XCTAssertGreaterThanOrEqual(result.durationSeconds, 0)
    }

    func testBruteForceStrategyWithRustEngine() async throws {
        let strategy = BruteForceRecoveryStrategy()
        let context = PasswordRecoveryContext(
            archivePath: "mock_archive.zip",
            charset: "ab",
            maxBruteForceLength: 2
        )
        XCTAssertTrue(strategy.canExecute(context: context))
        
        let (found, attempts) = try await strategy.recover(context: context) { candidate in
            return candidate == "ba"
        }
        XCTAssertEqual(found, "ba")
        XCTAssertGreaterThan(attempts, 0)
    }

    func testStrategyExecutorWithPipeline() async throws {
        let executor = PasswordRecoveryStrategyExecutor(registerDefaults: true)
        let context = PasswordRecoveryContext(
            archivePath: "mock_pipeline.zip",
            dictionary: ["wrongA", "target123", "wrongB"]
        )
        let result = try await executor.recoverPassword(context: context) { candidate in
            return candidate == "target123"
        }
        XCTAssertEqual(result.foundPassword, "target123")
        XCTAssertGreaterThan(result.totalAttempts, 0)
    }
}
