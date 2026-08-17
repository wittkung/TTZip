import XCTest
@testable import TTZipCore

final class FormatSupportTests: XCTestCase {
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
    
    func testZipFormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("zip_payload.txt")
        try "ZIP Format Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .zip, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "zip_payload.txt")
    }
    
    func testSevenZipFormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("sevenzip_payload.txt")
        try "7Z Format Native Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.7z")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .sevenZip, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "sevenzip_payload.txt")
    }
    
    func testTarGzFormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("targz_payload.txt")
        try "TAR.GZ Format Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarGz, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "targz_payload.txt")
    }
    
    func testTarZstFormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("zst_payload.txt")
        try "ZSTD Format Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.tar.zst")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarZst, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "zst_payload.txt")
    }
    
    func testTarBz2FormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("bz2_payload.txt")
        try "BZIP2 Format Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.tar.bz2")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarBz2, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "bz2_payload.txt")
    }
    
    func testTarXzFormatSupport() async throws {
        let sample = (tempDirPath as NSString).appendingPathComponent("xz_payload.txt")
        try "XZ Format Test Payload".write(toFile: sample, atomically: true, encoding: .utf8)
        
        let out = (tempDirPath as NSString).appendingPathComponent("test.tar.xz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarXz, inputPaths: [sample])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "xz_payload.txt")
    }
}
