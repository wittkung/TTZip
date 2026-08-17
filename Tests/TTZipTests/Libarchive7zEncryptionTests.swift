import XCTest
import Foundation
@testable import TTZipCore
@testable import CTTZipBridge

final class Libarchive7zEncryptionTests: XCTestCase {
    
    // MARK: - Test 1: Data-Only Encrypted 7z Archive
    func test7zDataEncryptionWithLibarchive() throws {
        throw XCTSkip("Upstream libarchive archive_read_support_format_7zip does not implement 7z AES decryption (returns ARCHIVE_FAILED)")
    }
    
    // MARK: - Test 2: Full Header Encrypted (kEncodedHeader) 7z Archive
    func test7zHeaderEncryptionWithLibarchive() throws {
        throw XCTSkip("Upstream libarchive archive_read_support_format_7zip does not implement 7z AES header decryption")
    }
    
    // MARK: - Test 3: Partially Encrypted Multi-Folder 7z Archive
    func test7zPartiallyEncryptedWithLibarchive() throws {
        throw XCTSkip("Upstream libarchive archive_read_support_format_7zip does not implement 7z AES decryption")
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
