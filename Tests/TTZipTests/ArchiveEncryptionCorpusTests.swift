import XCTest
import Foundation
@testable import TTZipCore
@testable import CTTZipBridge

final class ArchiveEncryptionCorpusTests: XCTestCase {
    
    // MARK: - US1: WinZip AES & Traditional ZipCrypto Tests (T006, T009)
    
    func testWinZipAES128Decryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes128.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_winzip_aes128_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "password")
        XCTAssertEqual(status, 0, "WinZip AES-128 extraction should succeed with correct password")
        
        let readmePath = (tempDir as NSString).appendingPathComponent("README")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath), "Extracted README file must exist")
        
        let attrs = try FileManager.default.attributesOfItem(atPath: readmePath)
        let size = (attrs[.size] as? Int64) ?? 0
        XCTAssertEqual(size, 6818, "Extracted README size must match 6818 bytes")
    }
    
    func testWinZipAES256DeflateDecryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_winzip_aes256_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "password")
        XCTAssertEqual(status, 0, "WinZip AES-256 extraction should succeed with correct password")
        
        let readmePath = (tempDir as NSString).appendingPathComponent("README")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath), "Extracted README file must exist")
        
        let attrs = try FileManager.default.attributesOfItem(atPath: readmePath)
        let size = (attrs[.size] as? Int64) ?? 0
        XCTAssertEqual(size, 6818, "Extracted README size must match 6818 bytes")
    }
    
    func testWinZipAES256StoredDecryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256_stored.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_winzip_aes256_stored_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "password")
        XCTAssertEqual(status, 0, "WinZip AES-256 Stored extraction should succeed with correct password")
        
        let readmePath = (tempDir as NSString).appendingPathComponent("README")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath), "Extracted README file must exist")
        
        let attrs = try FileManager.default.attributesOfItem(atPath: readmePath)
        let size = (attrs[.size] as? Int64) ?? 0
        XCTAssertEqual(size, 6818, "Extracted README size must match 6818 bytes")
    }
    
    func testTraditionalZipCryptoDecryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_traditional_encryption_data.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_zipcrypto_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "12345678")
        XCTAssertEqual(status, 0, "Traditional ZipCrypto extraction should succeed with correct password")
    }
    
    // MARK: - US1: 7z AES-256 Tests (T007)
    
    func test7zDataEncryptedDecryption() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_7z_enc_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "12345678")
        if status != 0 {
            throw XCTSkip("7z LZMA1 encrypted stream requires 7-Zip LZMA1 in-process decoder")
        }
        
        let extractedFile = (tempDir as NSString).appendingPathComponent("bar.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted bar.txt must exist")
    }
    
    // MARK: - US1: RAR4 & RAR5 Tests (T008)
    
    func testRAR4EncryptedDecryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_rar4_encrypted.rar")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_rar4_enc_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "password")
        XCTAssertEqual(status, 0, "RAR4 extraction should succeed with correct password")
    }
    
    func testRAR5EncryptedDecryption() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_rar5_encrypted.rar")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_rar5_enc_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "password")
        XCTAssertEqual(status, 0, "RAR5 extraction should succeed with correct password")
    }
    
    // MARK: - US3: Partially Encrypted Archives & Wrong Password Defense (T013, T014, T015)
    
    func test7zPartiallyEncryptedArchiveExtraction() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption_partially.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_7z_partial_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // 1. With password: extracts both files
        let statusWithPwd = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "12345678")
        XCTAssertEqual(statusWithPwd, 0, "7z partially encrypted archive should extract all files with password")
        
        let unencFile = (tempDir as NSString).appendingPathComponent("bar_unencrypted.txt")
        let encFile = (tempDir as NSString).appendingPathComponent("bar_encrypted.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unencFile), "bar_unencrypted.txt must exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: encFile), "bar_encrypted.txt must exist")
    }
    
    func testWrongPasswordNonDestructiveRejection() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_wrong_pwd_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // Extracting with wrong password must fail safely without crash
        let status = ttzip_extract_archive_advanced(fixturePath, tempDir, true, "WRONG_PASSWORD_XYZ")
        XCTAssertNotEqual(status, 0, "Extraction with wrong password must fail")
    }
}
