// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveIntegrityCheckerTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZipIntegrityCheck_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }
    
    func testValidArchiveIntegrityCheck() async throws {
        let sampleA = tempDir.appendingPathComponent("file1.txt")
        let sampleB = tempDir.appendingPathComponent("file2.txt")
        try "Content 1 for integrity test".write(to: sampleA, atomically: true, encoding: .utf8)
        try "Content 2 for integrity test".write(to: sampleB, atomically: true, encoding: .utf8)
        
        let outZip = tempDir.appendingPathComponent("valid.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outZip,
            format: .zip,
            inputPaths: [sampleA.path, sampleB.path]
        )
        
        let checker = ArchiveIntegrityChecker()
        let report = try await checker.checkArchiveIntegrity(archivePath: outZip)
        
        XCTAssertEqual(report.archivePath, outZip)
        XCTAssertEqual(report.overallStatus, .passed)
        XCTAssertEqual(report.totalEntriesCount, 2)
        XCTAssertEqual(report.verifiedEntriesCount, 2)
        XCTAssertEqual(report.corruptedEntriesCount, 0)
        XCTAssertTrue(report.corruptedEntries.isEmpty)
        XCTAssertGreaterThan(report.verificationDurationSeconds, 0)
    }
    
    func testTruncatedArchiveIntegrityCheck() async throws {
        let corruptFile = tempDir.appendingPathComponent("truncated.zip")
        // Write 10 random bytes to simulate corrupted / truncated archive
        try Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00]).write(to: corruptFile)
        
        let checker = ArchiveIntegrityChecker()
        let report = try await checker.checkArchiveIntegrity(archivePath: corruptFile.path)
        
        XCTAssertNotEqual(report.overallStatus, .passed)
        XCTAssertGreaterThan(report.corruptedEntriesCount, 0)
        XCTAssertFalse(report.corruptedEntries.isEmpty)
    }
    
    func testArchiveRepairEngineSalvage() async throws {
        let sampleA = tempDir.appendingPathComponent("salvage.txt")
        try "Critical data to salvage".write(to: sampleA, atomically: true, encoding: .utf8)
        
        let outZip = tempDir.appendingPathComponent("original.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outZip,
            format: .zip,
            inputPaths: [sampleA.path]
        )
        
        let repairedZip = tempDir.appendingPathComponent("repaired.zip").path
        let repairEngine = ArchiveRepairEngine()
        let salvagedCount = try await repairEngine.repairArchive(
            damagedArchivePath: outZip,
            repairedOutputPath: repairedZip
        )
        
        XCTAssertGreaterThanOrEqual(salvagedCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedZip))
    }
}
