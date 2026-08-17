import XCTest
@testable import TTZipCore

final class EnterpriseFullFeatureTests: XCTestCase {
    
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
    
    func testHashCalculatorAllTypes() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("hash_sample.txt")
        try "TTZip Full Hash Test".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let calc = HashCalculator()
        let crc = try await calc.computeHash(filePath: sampleFile, type: .crc32)
        let sha256 = try await calc.computeHash(filePath: sampleFile, type: .sha256)
        let md5 = try await calc.computeHash(filePath: sampleFile, type: .md5)
        let sha1 = try await calc.computeHash(filePath: sampleFile, type: .sha1)
        
        XCTAssertEqual(crc.count, 8)
        XCTAssertEqual(sha256.count, 64)
        XCTAssertEqual(md5.count, 32)
        XCTAssertEqual(sha1.count, 40)
    }
    
    func testSecurityScannerDetectsDangerousFiles() {
        let safeEntry = ArchiveEntry(path: "docs/readme.txt", uncompressedSize: 100, isDirectory: false, detectedEncoding: "UTF-8")
        let dangerousEntry = ArchiveEntry(path: "bin/malware.exe", uncompressedSize: 200, isDirectory: false, detectedEncoding: "UTF-8")
        
        let scanner = SecurityScanner.shared
        let result = scanner.scanArchiveEntries([safeEntry, dangerousEntry])
        
        XCTAssertFalse(result.isSafe)
        XCTAssertEqual(result.suspiciousFileNames.count, 1)
        XCTAssertEqual(result.suspiciousFileNames.first, "bin/malware.exe")
    }
    
    func testArchiveRepairEngine() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("valid.txt")
        try "Valid Content for Repair".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let validZip = (tempDirPath as NSString).appendingPathComponent("source.zip")
        let repairedZip = (tempDirPath as NSString).appendingPathComponent("repaired.zip")
        
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: validZip, format: .zip, inputPaths: [sampleFile])
        
        let engine = ArchiveRepairEngine()
        let count = try await engine.repairArchive(damagedArchivePath: validZip, repairedOutputPath: repairedZip)
        
        XCTAssertGreaterThan(count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedZip))
    }
}
