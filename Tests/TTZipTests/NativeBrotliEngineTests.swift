import XCTest
@testable import TTZipCore

final class NativeBrotliEngineTests: XCTestCase {
    
    private var tempDirURL: URL!
    
    override func setUp() {
        super.setUp()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDirURL = tempDirURL {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        super.tearDown()
    }
    
    func testBrotliRawFileCompressionAndDecompression() throws {
        let originalContent = "Brotli native acceleration on Apple Silicon using Compression.framework! " + String(repeating: "Web assets text payload\n", count: 1000)
        let srcFile = tempDirURL.appendingPathComponent("sample.txt")
        try originalContent.write(to: srcFile, atomically: true, encoding: .utf8)
        
        let brFile = tempDirURL.appendingPathComponent("sample.txt.br")
        let ok = try NativeBrotliEngine.shared.compressFile(srcPath: srcFile.path, dstPath: brFile.path, level: .level6)
        XCTAssertTrue(ok, "compressFile should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: brFile.path))
        
        let decompFile = tempDirURL.appendingPathComponent("sample_decomp.txt")
        let decOk = try NativeBrotliEngine.shared.decompressFile(srcPath: brFile.path, dstPath: decompFile.path)
        XCTAssertTrue(decOk, "decompressFile should succeed")
        
        let decompContent = try String(contentsOf: decompFile, encoding: .utf8)
        XCTAssertEqual(decompContent, originalContent)
    }
    
    func testBrotliTarArchiveCreateAndExtract() throws {
        let sampleDir = tempDirURL.appendingPathComponent("BrotliSampleDir")
        try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        
        let file1 = sampleDir.appendingPathComponent("file1.txt")
        let file2 = sampleDir.appendingPathComponent("file2.json")
        try "Content 1 for brotli archive".write(to: file1, atomically: true, encoding: .utf8)
        try "{\"brotli\": true, \"speed\": \"fast\"}".write(to: file2, atomically: true, encoding: .utf8)
        
        let arcPath = tempDirURL.appendingPathComponent("archive.tar.br").path
        let writer = ArchiveWriter()
        try writer.createArchiveSync(
            outputPath: arcPath,
            format: .brotli,
            level: .level1,
            inputPaths: [sampleDir.path]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: arcPath))
        let arcSize = (try? FileManager.default.attributesOfItem(atPath: arcPath)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(arcSize, 0)
        
        let extractDir = tempDirURL.appendingPathComponent("ExtractedBrotli").path
        let extractor = ArchiveExtractor()
        try extractor.extractSync(
            archivePath: arcPath,
            destinationDir: extractDir
        )
        
        let extFile1 = URL(fileURLWithPath: extractDir).appendingPathComponent("BrotliSampleDir/file1.txt")
        let extFile2 = URL(fileURLWithPath: extractDir).appendingPathComponent("BrotliSampleDir/file2.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile2.path))
        XCTAssertEqual(try String(contentsOf: extFile1, encoding: .utf8), "Content 1 for brotli archive")
        XCTAssertEqual(try String(contentsOf: extFile2, encoding: .utf8), "{\"brotli\": true, \"speed\": \"fast\"}")
    }
}
