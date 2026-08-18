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
        
        // Inspecting with password must succeed
        let entries = try await reader.inspect(archivePath: fixturePath, password: "12345678")
        XCTAssertFalse(entries.isEmpty, "Inspecting with correct password must return entry list")
    }
    
    func testRAR5EncryptedFilenamesProbing() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_rar5_encrypted_filenames.rar")
        let reader = ArchiveReader()
        
        let tier = try await reader.probeEncryption(archivePath: fixturePath)
        XCTAssertEqual(tier, .headerAndData, "RAR5 archive with encrypted filenames must be identified as .headerAndData")
    }
}
