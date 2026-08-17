import XCTest
import Foundation
@testable import TTZipCore

final class CLICommandE2ETests: XCTestCase {
    private var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        TTZipEngineFacade.initializeSubsystems()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let temp = tempDirectory, FileManager.default.fileExists(atPath: temp.path) {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }
    
    func testCLI_CreateAndExtract_RoundTrip_Zip() async throws {
        let sampleFile = tempDirectory.appendingPathComponent("sample.txt")
        let sampleContent = "TTZip CLI Roundtrip Verification Data - 2026"
        try sampleContent.write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let archiveFile = tempDirectory.appendingPathComponent("test_archive.zip")
        let extractDir = tempDirectory.appendingPathComponent("extracted_zip")
        
        // 1. Create ZIP archive via Engine Facade
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [sampleFile.path],
            outputPath: archiveFile.path,
            format: .zip,
            level: .level1
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveFile.path), "ZIP archive should be created")
        
        // 2. Extract ZIP archive via Engine Facade
        _ = try await TTZipEngineFacade.shared.quickExtract(
            archivePath: archiveFile.path,
            destinationDir: extractDir.path
        )
        
        let extractedFile = extractDir.appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "Extracted file should exist")
        
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, sampleContent, "Extracted content must match original exactly")
    }
    
    func testCLI_CreateAndExtract_RoundTrip_SevenZip() async throws {
        let sampleFile = tempDirectory.appendingPathComponent("sevenzip_sample.txt")
        let sampleContent = "TTZip CLI 7Z Verification Payload"
        try sampleContent.write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let archiveFile = tempDirectory.appendingPathComponent("test_archive.7z")
        let extractDir = tempDirectory.appendingPathComponent("extracted_7z")
        
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [sampleFile.path],
            outputPath: archiveFile.path,
            format: .sevenZip,
            level: .level1
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveFile.path), "7Z archive should be created")
        
        _ = try await TTZipEngineFacade.shared.quickExtract(
            archivePath: archiveFile.path,
            destinationDir: extractDir.path
        )
        
        let extractedFile = extractDir.appendingPathComponent("sevenzip_sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "Extracted 7Z file should exist")
        
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, sampleContent)
    }
    
    func testCLI_Inspect_Archive() async throws {
        let sampleFile = tempDirectory.appendingPathComponent("inspect_me.txt")
        try "Content to inspect".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let archiveFile = tempDirectory.appendingPathComponent("inspect_test.zip")
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [sampleFile.path],
            outputPath: archiveFile.path,
            format: .zip,
            level: .store
        )
        
        let metadata = try await SmartLoggingProxy.shared.inspectArchive(archivePath: archiveFile.path, password: nil)
        XCTAssertEqual(metadata.entries.count, 1)
        XCTAssertEqual(metadata.entries.first?.path, "inspect_me.txt")
    }
}
