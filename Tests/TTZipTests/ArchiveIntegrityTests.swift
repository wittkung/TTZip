import XCTest
@testable import TTZipCore

final class ArchiveIntegrityTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    func testCRC32Computation() throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("test.txt")
        let content = "123456789"
        try content.write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let checker = ArchiveIntegrityChecker()
        let crc = checker.computeCRC32(filePath: sampleFile)
        
        // "123456789" 的标准 CRC32 校验和为 CBF43926
        XCTAssertEqual(crc, "CBF43926")
    }
    
    func testSHA256Computation() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("test_sha.txt")
        let content = "TTZip SHA256 Verification"
        try content.write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let checker = ArchiveIntegrityChecker()
        let sha256 = try await checker.computeSHA256(filePath: sampleFile)
        
        XCTAssertEqual(sha256.count, 64)
        XCTAssertFalse(sha256.isEmpty)
    }
}
