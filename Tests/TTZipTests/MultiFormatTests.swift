import XCTest
@testable import TTZipCore

final class MultiFormatTests: XCTestCase {
    
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
    
    func testTarZstCreateAndInspect() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("zstd_data.txt")
        try "Zstandard High Speed Compression Test".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let outputZst = (tempDirPath as NSString).appendingPathComponent("test.tar.zst")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputZst,
            format: .tarZst,
            level: .normal,
            inputPaths: [sampleFile]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZst))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputZst)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "zstd_data.txt")
    }
    
    func testTarBz2CreateAndInspect() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("bzip_data.txt")
        try "Bzip2 High Ratio Compression Test".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let outputBz2 = (tempDirPath as NSString).appendingPathComponent("test.tar.bz2")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputBz2,
            format: .tarBz2,
            level: .normal,
            inputPaths: [sampleFile]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputBz2))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputBz2)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "bzip_data.txt")
    }
}
