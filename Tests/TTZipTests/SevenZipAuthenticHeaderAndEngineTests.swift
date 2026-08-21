// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

private final class ProgressRecorder: @unchecked Sendable {
    var isCalled = false
}

final class SevenZipAuthenticHeaderAndEngineTests: XCTestCase {
    
    private var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZipSevenZipTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }
    
    // MARK: - 1. Signature Header Verification
    
    func testSevenZipSignatureHeaderParsing() throws {
        let file1 = tempDirectory.appendingPathComponent("file1.txt")
        try "Hello SevenZip World".write(to: file1, atomically: true, encoding: .utf8)
        
        let out7z = tempDirectory.appendingPathComponent("test_sig.7z").path
        let success = try NativeSevenZipEngine.shared.createSevenZipParallel(
            outputPath: out7z,
            inputPaths: [file1.path],
            level: .normal
        )
        XCTAssertTrue(success, "Archive creation must succeed")
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: out7z))
        XCTAssertGreaterThanOrEqual(fileData.count, 32, "7z archive must be at least 32 bytes")
        
        fileData.withUnsafeBytes { rawBuffer in
            let bytePtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let header = SevenZipHeaderReader.shared.parseSignatureHeader(from: bytePtr, fileSize: fileData.count)
            XCTAssertNotNil(header, "Valid 7z archive must have a valid signature header")
            guard let header = header else { return }
            
            XCTAssertEqual(header.majorVersion, 0)
            XCTAssertGreaterThanOrEqual(header.minorVersion, 2)
            XCTAssertNotEqual(header.startHeaderCRC, 0)
            XCTAssertGreaterThanOrEqual(header.nextHeaderSize, 0)
        }
    }
    
    func testSevenZipSignatureHeaderRejectsInvalidData() {
        let invalidData = Data(repeating: 0x00, count: 64)
        invalidData.withUnsafeBytes { rawBuffer in
            let bytePtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let header = SevenZipHeaderReader.shared.parseSignatureHeader(from: bytePtr, fileSize: invalidData.count)
            XCTAssertNil(header, "All-zero buffer must not parse as valid 7z header")
        }
        
        let tooShortData = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        tooShortData.withUnsafeBytes { rawBuffer in
            let bytePtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let header = SevenZipHeaderReader.shared.parseSignatureHeader(from: bytePtr, fileSize: tooShortData.count)
            XCTAssertNil(header, "Buffer under 32 bytes must return nil")
        }
    }
    
    // MARK: - 2. Authentic Descriptors Reading
    
    func testSevenZipAuthenticHeaderDescriptorsReading() throws {
        let subDir = tempDirectory.appendingPathComponent("nested_folder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let fileA = subDir.appendingPathComponent("alpha.txt")
        let fileB = subDir.appendingPathComponent("beta.bin")
        let fileC = tempDirectory.appendingPathComponent("root.txt")
        
        let contentA = "Alpha text content 12345"
        let contentB = Data((0..<256).map { UInt8($0 & 0xFF) })
        let contentC = "Root level content string"
        
        try contentA.write(to: fileA, atomically: true, encoding: .utf8)
        try contentB.write(to: fileB)
        try contentC.write(to: fileC, atomically: true, encoding: .utf8)
        
        let out7z = tempDirectory.appendingPathComponent("authentic_descriptors.7z").path
        let success = try NativeSevenZipEngine.shared.createSevenZipParallel(
            outputPath: out7z,
            inputPaths: [fileA.path, fileB.path, fileC.path],
            level: .maximum
        )
        XCTAssertTrue(success, "7z archive creation must succeed")
        
        // 1. Test reading descriptors from file path
        let descriptorsFromPath = SevenZipHeaderReader.shared.readDescriptors(archivePath: out7z)
        XCTAssertNotNil(descriptorsFromPath, "Must successfully read authentic descriptors from path")
        guard let descriptors = descriptorsFromPath else { return }
        
        XCTAssertEqual(descriptors.count, 3, "Must contain exactly 3 authentic entry descriptors")
        
        // Verify authentic entries without dummy content
        for desc in descriptors {
            XCTAssertFalse(desc.path.contains("archive_content_"), "Must NOT contain mock dummy path")
            XCTAssertFalse(desc.path.isEmpty, "Entry path must not be empty")
        }
        
        let alphaDesc = descriptors.first(where: { $0.path.contains("alpha.txt") })
        let betaDesc = descriptors.first(where: { $0.path.contains("beta.bin") })
        let rootDesc = descriptors.first(where: { $0.path.contains("root.txt") })
        
        XCTAssertNotNil(alphaDesc, "alpha.txt descriptor must exist")
        XCTAssertNotNil(betaDesc, "beta.bin descriptor must exist")
        XCTAssertNotNil(rootDesc, "root.txt descriptor must exist")
        
        XCTAssertEqual(alphaDesc?.uncompressedSize, Int64(contentA.utf8.count))
        XCTAssertEqual(betaDesc?.uncompressedSize, Int64(contentB.count))
        XCTAssertEqual(rootDesc?.uncompressedSize, Int64(contentC.utf8.count))
        
        // 2. Test reading descriptors from mapped memory buffer
        let fileData = try Data(contentsOf: URL(fileURLWithPath: out7z))
        fileData.withUnsafeBytes { rawBuffer in
            let bytePtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let descriptorsFromBuffer = SevenZipHeaderReader.shared.readDescriptors(from: bytePtr, fileSize: fileData.count)
            XCTAssertNotNil(descriptorsFromBuffer, "Must successfully read authentic descriptors from memory buffer")
            XCTAssertEqual(descriptorsFromBuffer?.count, 3)
        }
    }
    
    // MARK: - 3. Direct NativeSevenZipEngine Operations
    
    func testNativeSevenZipEngineDirectCreateExtractInspect() throws {
        let file1 = tempDirectory.appendingPathComponent("doc.txt")
        let content = "Document content for NativeSevenZipEngine direct test."
        try content.write(to: file1, atomically: true, encoding: .utf8)
        
        let out7z = tempDirectory.appendingPathComponent("direct_engine.7z").path
        let destDir = tempDirectory.appendingPathComponent("extracted_direct").path
        try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        
        // Create
        let createSuccess = try NativeSevenZipEngine.shared.createSevenZipParallel(
            outputPath: out7z,
            inputPaths: [file1.path],
            level: .normal
        )
        XCTAssertTrue(createSuccess)
        
        // Inspect
        let entries = NativeSevenZipEngine.shared.inspectSevenZip(archivePath: out7z)
        XCTAssertNotNil(entries)
        XCTAssertEqual(entries?.count, 1)
        XCTAssertTrue(entries?.first?.path.contains("doc.txt") ?? false)
        XCTAssertEqual(entries?.first?.uncompressedSize, Int64(content.utf8.count))
        
        // Extract
        let extractSuccess = try NativeSevenZipEngine.shared.extractSevenZipParallel(
            archivePath: out7z,
            destinationDir: destDir
        )
        XCTAssertTrue(extractSuccess)
        
        let extractedItems = try FileManager.default.contentsOfDirectory(atPath: destDir)
        XCTAssertFalse(extractedItems.isEmpty, "Destination directory must contain extracted files")
    }
    
    // MARK: - 4. SevenZipParallelWriter and SevenZipParallelExtractor
    
    func testSevenZipParallelWriterAndExtractorRoundTrip() throws {
        let file1 = tempDirectory.appendingPathComponent("item1.txt")
        let file2 = tempDirectory.appendingPathComponent("item2.txt")
        try "Content Item 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content Item 2".write(to: file2, atomically: true, encoding: .utf8)
        
        let out7z = tempDirectory.appendingPathComponent("parallel_roundtrip.7z").path
        let destDir = tempDirectory.appendingPathComponent("extracted_parallel").path
        try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        
        let recorder = ProgressRecorder()
        let createOk = try SevenZipParallelWriter.shared.createArchive(
            outputPath: out7z,
            inputPaths: [file1.path, file2.path],
            level: .fast,
            password: nil,
            useZstd: false,
            solidBlockSizeMb: 64,
            progressHandler: { _ in recorder.isCalled = true }
        )
        XCTAssertTrue(createOk, "SevenZipParallelWriter createArchive must succeed")
        XCTAssertTrue(recorder.isCalled, "Progress callback should be invoked on completion")
        
        let extractOk = try SevenZipParallelExtractor.shared.extract(
            archivePath: out7z,
            destinationDir: destDir,
            password: nil,
            skipMacJunk: true
        )
        XCTAssertTrue(extractOk, "SevenZipParallelExtractor extract must succeed")
        
        let items = try FileManager.default.contentsOfDirectory(atPath: destDir)
        XCTAssertEqual(items.count, 2, "Must extract 2 items")
    }
}
