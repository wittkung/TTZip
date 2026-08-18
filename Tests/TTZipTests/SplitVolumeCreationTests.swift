// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SplitVolumeCreationTests: XCTestCase {
    private var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip_SplitTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    func testMultiVolumeStreamSinkBoundaryRollover() throws {
        let baseArchive = tempDirectoryURL.appendingPathComponent("split_test.7z").path
        let volumeSize: Int64 = 65536 // 64 KB per volume
        
        let sink = try MultiVolumeStreamSink(
            baseOutputPath: baseArchive,
            volumeSizeBytes: volumeSize,
            namingPattern: .numberedExtension,
            cleanOnFailure: true
        )
        
        // Write 150 KB (should create 3 volumes: 64KB, 64KB, 22KB)
        let sampleData = Data(repeating: 0x5A, count: 150 * 1024)
        try sink.write(data: sampleData)
        let paths = try sink.close()
        
        XCTAssertEqual(paths.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: baseArchive + ".001"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: baseArchive + ".002"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: baseArchive + ".003"))
        
        let size1 = try FileManager.default.attributesOfItem(atPath: paths[0])[.size] as? Int64
        let size2 = try FileManager.default.attributesOfItem(atPath: paths[1])[.size] as? Int64
        let size3 = try FileManager.default.attributesOfItem(atPath: paths[2])[.size] as? Int64
        
        XCTAssertEqual(size1, 65536)
        XCTAssertEqual(size2, 65536)
        XCTAssertEqual(size3, 22528) // 150KB - 128KB = 22KB
    }
    
    func testPKZIPSpannedVolumeNaming() throws {
        let baseArchive = tempDirectoryURL.appendingPathComponent("archive.zip").path
        let volumeSize: Int64 = 65536
        
        let sink = try MultiVolumeStreamSink(
            baseOutputPath: baseArchive,
            volumeSizeBytes: volumeSize,
            namingPattern: .pkzipSpanned,
            cleanOnFailure: true
        )
        
        let sampleData = Data(repeating: 0x41, count: 140 * 1024)
        try sink.write(data: sampleData)
        let paths = try sink.close()
        
        XCTAssertEqual(paths.count, 3)
        let baseDir = tempDirectoryURL.path
        XCTAssertTrue(FileManager.default.fileExists(atPath: (baseDir as NSString).appendingPathComponent("archive.z01")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (baseDir as NSString).appendingPathComponent("archive.z02")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (baseDir as NSString).appendingPathComponent("archive.zip")))
    }
    
    func testCreateAndExtract7zSplitArchive() async throws {
        let sourceFile = tempDirectoryURL.appendingPathComponent("payload.bin").path
        // Create 300 KB binary data (incompressible enough so compressed 7z > 120 KB)
        var prng = DeterministicPRNG(seed: 0x12345678)
        var buffer = [UInt8](repeating: 0, count: 300 * 1024)
        for i in 0..<buffer.count {
            buffer[i] = UInt8(prng.next() & 0xFF)
        }
        let sampleData = Data(buffer)
        try sampleData.write(to: URL(fileURLWithPath: sourceFile))
        
        let out7z = tempDirectoryURL.appendingPathComponent("payload.7z").path
        let writer = ArchiveWriter()
        
        // 64 KB split
        try await writer.createArchive(
            outputPath: out7z,
            format: .sevenZip,
            level: .fast,
            inputPaths: [sourceFile],
            splitVolumeSizeBytes: 65536
        )
        
        let part1 = out7z + ".001"
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1))
        
        // Extract split archive
        let extractDest = tempDirectoryURL.appendingPathComponent("extracted_7z").path
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: part1, destinationDir: extractDest)
        
        let extractedFile = (extractDest as NSString).appendingPathComponent("payload.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        let extractedData = try Data(contentsOf: URL(fileURLWithPath: extractedFile))
        XCTAssertEqual(extractedData, sampleData)
    }
}

