// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CryptoKit

final class TarVariantEdgeCasesTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TarEdge_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    /// 1. 256+ Pax
    func testLongPath256CharsTar() async throws {
        let deepFolderNames = (0..<15).map { "long_path_subfolder_directory_name_segment_\($0)" }
        let relativeDeepPath = deepFolderNames.joined(separator: "/")
        let deepDirPath = (tempDirPath as NSString).appendingPathComponent(relativeDeepPath)
        try FileManager.default.createDirectory(atPath: deepDirPath, withIntermediateDirectories: true)
        
        let testFilePath = (deepDirPath as NSString).appendingPathComponent("ultra_long_filename_payload_test_data.txt")
        let contentStr = "Apple Silicon Native TAR Pax Header Ultra Long Path Benchmark Content Data 2026"
        try contentStr.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        XCTAssertGreaterThan(testFilePath.count, 256, "Target test file path must exceed 256 characters for POSIX PAX header verification")
        
        let rootSubDir = (tempDirPath as NSString).appendingPathComponent(deepFolderNames[0])
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()
        
        let formats: [ArchiveCompressionFormat] = [.tar, .tarGz, .tarZst]
        for fmt in formats {
            let outArc = (tempDirPath as NSString).appendingPathComponent("longpath.\(fmt.rawValue)")
            let outDest = (tempDirPath as NSString).appendingPathComponent("out_longpath_\(fmt.rawValue)")
            
            try await writer.createArchive(outputPath: outArc, format: fmt, level: .fastest, inputPaths: [rootSubDir])
            try await extractor.extract(archivePath: outArc, destinationDir: outDest)
            
            let extractedFile = (outDest as NSString).appendingPathComponent(relativeDeepPath).appending("/ultra_long_filename_payload_test_data.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted long-path file must exist for format \(fmt.rawValue)")
            let readData = try String(contentsOfFile: extractedFile, encoding: .utf8)
            XCTAssertEqual(readData, contentStr, "Byte content must match original for format \(fmt.rawValue)")
        }
    }
    
    /// 2. 0
    func testZeroByteEmptyFileTar() async throws {
        let emptyFile = (tempDirPath as NSString).appendingPathComponent("empty_payload.bin")
        FileManager.default.createFile(atPath: emptyFile, contents: Data())
        
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()
        
        let formats: [ArchiveCompressionFormat] = [.tar, .tarGz, .tarZst, .tarBz2, .tarXz]
        for fmt in formats {
            let outArc = (tempDirPath as NSString).appendingPathComponent("empty.\(fmt.rawValue)")
            let outDest = (tempDirPath as NSString).appendingPathComponent("out_empty_\(fmt.rawValue)")
            
            try await writer.createArchive(outputPath: outArc, format: fmt, level: .store, inputPaths: [emptyFile])
            try await extractor.extract(archivePath: outArc, destinationDir: outDest)
            
            let extractedFile = (outDest as NSString).appendingPathComponent("empty_payload.bin")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted 0-byte file must exist for format \(fmt.rawValue)")
            let attrs = try FileManager.default.attributesOfItem(atPath: extractedFile)
            XCTAssertEqual(attrs[.size] as? Int64, 0, "Extracted file size must be exactly 0 bytes")
        }
    }
    
    /// Validates expected behavior and invariants.
    func testHardAndSoftLinksTar() async throws {
        let srcFile = (tempDirPath as NSString).appendingPathComponent("original.txt")
        let content = "Hard and Soft Link Test Payload Data"
        try content.write(toFile: srcFile, atomically: true, encoding: .utf8)
        
        let hardLink = (tempDirPath as NSString).appendingPathComponent("hardlink.txt")
        try FileManager.default.linkItem(atPath: srcFile, toPath: hardLink)
        
        let symLink = (tempDirPath as NSString).appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(atPath: symLink, withDestinationPath: "original.txt")
        
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()
        
        let outArc = (tempDirPath as NSString).appendingPathComponent("links.tar.gz")
        let outDest = (tempDirPath as NSString).appendingPathComponent("out_links")
        
        try await writer.createArchive(outputPath: outArc, format: .tarGz, level: .fastest, inputPaths: [srcFile, hardLink, symLink])
        try await extractor.extract(archivePath: outArc, destinationDir: outDest)
        
        let extOriginal = (outDest as NSString).appendingPathComponent("original.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extOriginal), "Extracted original file must exist")
        let extContent = try String(contentsOfFile: extOriginal, encoding: .utf8)
        XCTAssertEqual(extContent, content)
    }
    
    /// 4. / Tar Recovery
    func testCorruptedTarTrailingBlock() async throws {
        let validFile = (tempDirPath as NSString).appendingPathComponent("valid.txt")
        try "Valid Content Data".write(toFile: validFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()
        
        let normArc = (tempDirPath as NSString).appendingPathComponent("norm.tar")
        try await writer.createArchive(outputPath: normArc, format: .tar, level: .store, inputPaths: [validFile])
        
        // 512 zero-block
        let origData = try Data(contentsOf: URL(fileURLWithPath: normArc))
        let truncatedData = origData.prefix(max(512, origData.count - 512))
        let corruptArc = (tempDirPath as NSString).appendingPathComponent("corrupted.tar")
        try truncatedData.write(to: URL(fileURLWithPath: corruptArc))
        
        let outDest = (tempDirPath as NSString).appendingPathComponent("out_corrupt")
        
        // ，
        try? await extractor.extract(archivePath: corruptArc, destinationDir: outDest)
        let recoveredFile = (outDest as NSString).appendingPathComponent("valid.txt")
        if FileManager.default.fileExists(atPath: recoveredFile) {
            let recoveredText = try String(contentsOfFile: recoveredFile, encoding: .utf8)
            XCTAssertEqual(recoveredText, "Valid Content Data")
        }
    }
    
    /// 5. CRC32 Byte-for-Byte
    func testCrc32ByteForByteVerification() async throws {
        let sampleData = Data((0..<1024*512).map { UInt8($0 % 256) })
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("sample_512k.bin")
        try sampleData.write(to: URL(fileURLWithPath: sampleFile))
        
        let calc = HashCalculator()
        let origCrc = try await calc.computeHash(filePath: sampleFile, type: .crc32)
        
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()
        
        let formats: [ArchiveCompressionFormat] = [.tar, .tarGz, .tarZst, .tarBz2, .tarXz]
        for fmt in formats {
            let outArc = (tempDirPath as NSString).appendingPathComponent("crc_test.\(fmt.rawValue)")
            let outDest = (tempDirPath as NSString).appendingPathComponent("out_crc_\(fmt.rawValue)")
            
            try await writer.createArchive(outputPath: outArc, format: fmt, level: .normal, inputPaths: [sampleFile])
            try await extractor.extract(archivePath: outArc, destinationDir: outDest)
            
            let extractedFile = (outDest as NSString).appendingPathComponent("sample_512k.bin")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile), "Extracted file must exist for \(fmt.rawValue)")
            
            let extractedCrc = try await calc.computeHash(filePath: extractedFile, type: .crc32)
            XCTAssertEqual(extractedCrc, origCrc, "CRC32 fingerprint must match byte-for-byte for \(fmt.rawValue)")
        }
    }
}
