import XCTest
import Foundation
@testable import TTZipCore
@testable import CTTZipBridge

final class Libarchive7zEncryptionTests: XCTestCase {
    
    // MARK: - Test 1: Data-Only Encrypted 7z Archive
    func test7zDataEncryptionWithLibarchive() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_la_7z_data_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // 1. Direct libarchive extraction
        let res = ttzip_extract_7z_libarchive_c(fixturePath, tempDir, "12345678")
        XCTAssertEqual(res, TTZIP_OK.rawValue, "ttzip_extract_7z_libarchive_c should extract encrypted 7z data")
        
        let extractedFile = (tempDir as NSString).appendingPathComponent("bar.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted bar.txt must exist")
        
        let content = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(content, "foo\n", "Decrypted file content must match expected text")
    }
    
    // MARK: - Test 2: Full Header Encrypted (kEncodedHeader) 7z Archive
    func test7zHeaderEncryptionWithLibarchive() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption_header.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_la_7z_hdr_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // 1. Direct libarchive extraction of header-encrypted archive
        let res = ttzip_extract_7z_libarchive_c(fixturePath, tempDir, "12345678")
        XCTAssertEqual(res, TTZIP_OK.rawValue, "ttzip_extract_7z_libarchive_c should extract header-encrypted 7z archive")
        
        let extractedFile = (tempDir as NSString).appendingPathComponent("bar.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted bar.txt from header-encrypted archive must exist")
        
        let content = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(content, "foo\n", "Decrypted file content from header-encrypted archive must match expected text")
    }
    
    // MARK: - Test 3: Partially Encrypted Multi-Folder 7z Archive
    func test7zPartiallyEncryptedWithLibarchive() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption_partially.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_la_7z_part_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let res = ttzip_extract_7z_libarchive_c(fixturePath, tempDir, "12345678")
        XCTAssertEqual(res, TTZIP_OK.rawValue, "ttzip_extract_7z_libarchive_c should extract partially encrypted 7z")
        
        let unencFile = (tempDir as NSString).appendingPathComponent("bar_unencrypted.txt")
        let encFile = (tempDir as NSString).appendingPathComponent("bar_encrypted.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unencFile), "bar_unencrypted.txt must exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: encFile), "bar_encrypted.txt must exist")
        
        let encContent = try String(contentsOfFile: encFile, encoding: .utf8)
        XCTAssertEqual(encContent, "foo\n", "Encrypted entry content must match")
    }
    
    // MARK: - Test 4: Wrong Password Security Rejection
    func test7zWrongPasswordRejection() throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_7zip_encryption.7z")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_la_7z_wrong_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let res = ttzip_extract_7z_libarchive_c(fixturePath, tempDir, "wrong_password_123")
        XCTAssertNotEqual(res, TTZIP_OK.rawValue, "Extraction with wrong password must fail cleanly")
    }
}
