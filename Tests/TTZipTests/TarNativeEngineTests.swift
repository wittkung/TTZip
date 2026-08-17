import XCTest
import CTTZipBridge
@testable import TTZipCore

final class TarNativeEngineTests: XCTestCase {
    
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
    
    func testTarNativeCreateAndExtract() throws {
        let sampleDir = tempDirURL.appendingPathComponent("SampleDir")
        try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        
        let file1URL = sampleDir.appendingPathComponent("file1.txt")
        let file2URL = sampleDir.appendingPathComponent("file2.log")
        let subDir = sampleDir.appendingPathComponent("SubFolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file3URL = subDir.appendingPathComponent("file3.json")
        
        try "Hello Native TAR 1".write(to: file1URL, atomically: true, encoding: .utf8)
        try "Hello Native TAR 2 Log Data".write(to: file2URL, atomically: true, encoding: .utf8)
        try "{\"key\": \"value\"}".write(to: file3URL, atomically: true, encoding: .utf8)
        
        let tarOutputPath = tempDirURL.appendingPathComponent("archive.tar").path
        let inputPaths = [sampleDir.path]
        
        let createStatus = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { buf in
            ttzip_create_tar_native_c(tarOutputPath, "tar", buf, inputPaths.count, true, 1)
        }
        XCTAssertEqual(createStatus, 0, "ttzip_create_tar_native_c should return 0 for tar format")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tarOutputPath))
        
        let destExtractDir = tempDirURL.appendingPathComponent("ExtractTar")
        let extractStatus = ttzip_extract_tar_native_c(tarOutputPath, destExtractDir.path, true)
        XCTAssertEqual(extractStatus, 0, "ttzip_extract_tar_native_c should return 0")
        
        let extFile1 = destExtractDir.appendingPathComponent("SampleDir/file1.txt")
        let extFile2 = destExtractDir.appendingPathComponent("SampleDir/file2.log")
        let extFile3 = destExtractDir.appendingPathComponent("SampleDir/SubFolder/file3.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile3.path))
        
        XCTAssertEqual(try String(contentsOf: extFile1, encoding: .utf8), "Hello Native TAR 1")
        XCTAssertEqual(try String(contentsOf: extFile3, encoding: .utf8), "{\"key\": \"value\"}")
    }
    
    func testTarGzNativeCreateAndExtract() throws {
        let sampleDir = tempDirURL.appendingPathComponent("SampleGzDir")
        try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        let file1URL = sampleDir.appendingPathComponent("data.txt")
        try "Compressed GZ Content Stream".write(to: file1URL, atomically: true, encoding: .utf8)
        
        let tgzOutputPath = tempDirURL.appendingPathComponent("archive.tar.gz").path
        let inputPaths = [sampleDir.path]
        
        let createStatus = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { buf in
            ttzip_create_tar_native_c(tgzOutputPath, "tar.gz", buf, inputPaths.count, true, 1)
        }
        XCTAssertEqual(createStatus, 0, "ttzip_create_tar_native_c should return 0 for tar.gz format")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tgzOutputPath))
        
        let destExtractDir = tempDirURL.appendingPathComponent("ExtractTgz")
        let extractStatus = ttzip_extract_tar_native_c(tgzOutputPath, destExtractDir.path, true)
        XCTAssertEqual(extractStatus, 0, "ttzip_extract_tar_native_c should return 0 for tar.gz")
        
        let extFile1 = destExtractDir.appendingPathComponent("SampleGzDir/data.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile1.path))
        XCTAssertEqual(try String(contentsOf: extFile1, encoding: .utf8), "Compressed GZ Content Stream")
    }
}
