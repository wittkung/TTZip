// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ArchiveEncryptionIntrospectionTests: XCTestCase {
    
    // MARK: - US2: 3-Tier Encryption Introspection & Header Protection (T010, T011, T012)
    
    func testDataOnlyEncryptedArchiveAllowsInspectionWithoutPassword() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let reader = ArchiveReader()
        
        let tier = try await reader.probeEncryption(archivePath: fixturePath)
        XCTAssertEqual(tier, .dataOnly, "WinZip AES archive without header encryption must be identified as .dataOnly")
        
        let entries = try await reader.inspect(archivePath: fixturePath)
        XCTAssertFalse(entries.isEmpty, "Data-only encrypted archive must allow entry listing without password")
        
        let readmeEntry = entries.first(where: { $0.name == "README" })
        XCTAssertNotNil(readmeEntry, "README entry must be listed")
        XCTAssertTrue(readmeEntry?.isEncrypted ?? false, "README entry must be marked isEncrypted")
    }
    
    func testHeaderEncryptedArchiveProbing() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption_header.7z")
        let reader = ArchiveReader()
        
        let tier = try await reader.probeEncryption(archivePath: fixturePath)
        XCTAssertEqual(tier, .headerAndData, "7z archive with encoded headers must be identified as .headerAndData")
    }
    
    func testHeaderEncryptedArchiveRequiresPasswordToInspect() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption_header.7z")
        let reader = ArchiveReader()
        
        // Inspecting header-encrypted archive without password must throw error
        do {
            _ = try await reader.inspect(archivePath: fixturePath, password: nil)
            XCTFail("Must require password")
        } catch {
            XCTAssertTrue(error is ArchiveError)
        }
    }
    
    func testRAR5EncryptedFilenamesProbing() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_rar5_encrypted_filenames.rar")
        let reader = ArchiveReader()
        
        let tier = try await reader.probeEncryption(archivePath: fixturePath)
        XCTAssertEqual(tier, .headerAndData, "RAR5 archive with encrypted filenames must be identified as .headerAndData")
    }
    
    func testSevenZipZeroCopyInspectionSpeedAndAccuracy() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_7z_inspect_\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let fileA = tempDir.appendingPathComponent("fileA.txt")
        let fileB = tempDir.appendingPathComponent("fileB.txt")
        try "Content of file A".write(to: fileA, atomically: true, encoding: .utf8)
        try "Content of file B with more data 123456789".write(to: fileB, atomically: true, encoding: .utf8)
        
        let out7z = tempDir.appendingPathComponent("test_archive.7z").path
        let success = try SevenZipEngine.shared.createArchive(
            outputPath: out7z,
            inputPaths: [fileA.path, fileB.path],
            level: .fast
        )
        XCTAssertTrue(success, "7z archive creation must succeed")
        
        let reader = ArchiveReader()
        let t0 = CFAbsoluteTimeGetCurrent()
        let entries = try await reader.inspect(archivePath: out7z)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
        
        XCTAssertEqual(entries.count, 2, "Must return exactly 2 entries")
        XCTAssertTrue(entries.contains(where: { $0.path.contains("fileA.txt") }))
        XCTAssertTrue(entries.contains(where: { $0.path.contains("fileB.txt") }))
        XCTAssertLessThan(elapsedMs, 15.0, "Zero-copy inspection must complete in < 15ms (actual: \(elapsedMs)ms)")
    }
}
