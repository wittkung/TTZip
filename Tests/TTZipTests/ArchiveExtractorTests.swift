import XCTest
@testable import TTZipCore

final class ArchiveExtractorTests: XCTestCase {
    
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
    
    func testPackAndExtractRoundtrip() async throws {
        let srcFile = (tempDirPath as NSString).appendingPathComponent("hello.txt")
        let originalContent = "Hello TTZip Commercial Engine 2026"
        try originalContent.write(toFile: srcFile, atomically: true, encoding: .utf8)
        
        let zipPath = (tempDirPath as NSString).appendingPathComponent("bundle.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipPath,
            format: .zip,
            level: .normal,
            inputPaths: [srcFile]
        )
        
        let extractTargetDir = (tempDirPath as NSString).appendingPathComponent("Extracted")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: zipPath, destinationDir: extractTargetDir)
        
        let extractedFile = (extractTargetDir as NSString).appendingPathComponent("hello.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        
        let readBack = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(readBack, originalContent)
    }
}
