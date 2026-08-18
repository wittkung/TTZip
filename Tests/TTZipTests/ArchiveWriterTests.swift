// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveWriterTests: XCTestCase {
    
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
    
    func testCreateZipArchiveAndReadBack() async throws {
        let file1 = (tempDirPath as NSString).appendingPathComponent("file1.txt")
        let file2 = (tempDirPath as NSString).appendingPathComponent("file2.txt")
        
        try "Content 1".write(toFile: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(toFile: file2, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("output.zip")
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputZip,
            format: .zip,
            level: .normal,
            inputPaths: [file1, file2]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputZip)
        XCTAssertEqual(entries.count, 2)
        let fileNames = Set(entries.map { $0.name })
        XCTAssertTrue(fileNames.contains("file1.txt"))
        XCTAssertTrue(fileNames.contains("file2.txt"))
    }
    
    func testCreateTarGzArchiveSuccess() async throws {
        let file1 = (tempDirPath as NSString).appendingPathComponent("data.json")
        try "{\"key\": \"value\"}".write(toFile: file1, atomically: true, encoding: .utf8)
        
        let outputTar = (tempDirPath as NSString).appendingPathComponent("output.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputTar,
            format: .tarGz,
            level: .fast,
            inputPaths: [file1]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputTar))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputTar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "data.json")
    }
    
    func testStoreModeDirectoryArchiveAndExtractVerification() async throws {
        // "5.12"
        let sourceDir = (tempDirPath as NSString).appendingPathComponent("5.12")
        try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        
        let fileA = (sourceDir as NSString).appendingPathComponent("video1.bin")
        let fileB = (sourceDir as NSString).appendingPathComponent("doc2.txt")
        
        let chunkA = Data(repeating: 0xFF, count: 3 * 1024 * 1024) // 3MB
        let chunkB = "Hello TTZip 5.12 Store Verification Test".data(using: .utf8)!
        try chunkA.write(to: URL(fileURLWithPath: fileA))
        try chunkB.write(to: URL(fileURLWithPath: fileB))
        
        let outputBase = (tempDirPath as NSString).appendingPathComponent("5.12.7z")
        let writer = ArchiveWriter()
        
        // 7z store mode with 2MB split volume and password encryption
        try await writer.createArchive(
            outputPath: outputBase,
            format: .sevenZip,
            level: .store,
            inputPaths: [sourceDir],
            splitVolumeSizeBytes: 2 * 1024 * 1024, // 2MB split volume
            password: "VerifyPassword123"
        )
        
        // 1. Verify split volume generation
        let vol1 = "\(outputBase).001"
        let vol2 = "\(outputBase).002"
        XCTAssertTrue(FileManager.default.fileExists(atPath: vol1), "Split volume .001 must exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vol2), "Split volume .002 must exist")
        
        let attr1 = try FileManager.default.attributesOfItem(atPath: vol1)
        let size1 = (attr1[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size1, 1 * 1024 * 1024, "2MB split volume size must exceed 1MB")
        
        // 2. Verify extraction and password decryption
        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_out")
        try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: vol1,
            destinationDir: extractDir,
            password: "VerifyPassword123"
        )
        
        // 3. Verify extracted file content integrity
        var foundA: String? = nil
        var foundB: String? = nil
        if let enumerator = FileManager.default.enumerator(atPath: extractDir) {
            while let subpath = enumerator.nextObject() as? String {
                if subpath.hasSuffix("video1.bin") { foundA = (extractDir as NSString).appendingPathComponent(subpath) }
                if subpath.hasSuffix("doc2.txt") { foundB = (extractDir as NSString).appendingPathComponent(subpath) }
            }
        }
        
        XCTAssertNotNil(foundA, "Extracted destination must contain video1.bin")
        XCTAssertNotNil(foundB, "Extracted destination must contain doc2.txt")
        
        let extractedFileA = foundA!
        let extractedFileB = foundB!
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFileA), "Extracted video file must exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFileB), "Extracted document file must exist")
        
        let extractedDataA = try Data(contentsOf: URL(fileURLWithPath: extractedFileA))
        let extractedDataB = try Data(contentsOf: URL(fileURLWithPath: extractedFileB))
        
        XCTAssertEqual(extractedDataA.count, chunkA.count, "Extracted binary payload size must match exactly")
        XCTAssertEqual(extractedDataB.count, chunkB.count, "Extracted text payload size must match exactly")
    }
    
    func testAllFormatsCompressAndExtractVerification() async throws {
        let formats: [(ArchiveCompressionFormat, String)] = [
            (.sevenZip, "7z"),
            (.zip, "zip"),
            (.tar, "tar"),
            (.zst, "zst"),
            (.gz, "gz"),
            (.bz2, "bz2"),
            (.xz, "xz"),
            (.lzip, "lz"),
            (.lz4, "lz4"),
            (.wim, "wim")
        ]
        
        let baseTemp = tempDirPath!
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (fmt, ext) in formats {
                group.addTask {
                    let sourceDir = (baseTemp as NSString).appendingPathComponent("test_folder_\(ext)")
                    try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
                    
                    let fileBinary = (sourceDir as NSString).appendingPathComponent("media.bin")
                    let fileText = (sourceDir as NSString).appendingPathComponent("notes.txt")
                    
                    let binaryData = Data((0..<1024*1024).map { UInt8($0 % 256) }) // 1MB
                    let textData = "TTZip Verification Test Payload for \(ext)".data(using: .utf8)!
                    
                    try binaryData.write(to: URL(fileURLWithPath: fileBinary))
                    try textData.write(to: URL(fileURLWithPath: fileText))
                    
                    let archiveOutput = (baseTemp as NSString).appendingPathComponent("archive_\(ext).\(ext)")
                    let writer = ArchiveWriter()
                    try await writer.createArchive(
                        outputPath: archiveOutput,
                        format: fmt,
                        level: .normal,
                        inputPaths: [sourceDir]
                    )
                    
                    // 1. Verify archive creation
                    XCTAssertTrue(FileManager.default.fileExists(atPath: archiveOutput), "Format \(ext) must generate archive")
                    let attrs = try FileManager.default.attributesOfItem(atPath: archiveOutput)
                    let fileSize = (attrs[.size] as? Int64) ?? 0
                    XCTAssertGreaterThan(fileSize, 500, "Format \(ext) size must exceed 500 bytes")
                    
                    // 2. Verify extraction
                    let extractDir = (baseTemp as NSString).appendingPathComponent("extracted_\(ext)")
                    try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
                    
                    let extractor = ArchiveExtractor()
                    try await extractor.extract(archivePath: archiveOutput, destinationDir: extractDir)
                    
                    let subFolderName = "test_folder_\(ext)"
                    var restoredBinary = (extractDir as NSString).appendingPathComponent("\(subFolderName)/media.bin")
                    var restoredText = (extractDir as NSString).appendingPathComponent("\(subFolderName)/notes.txt")
                    if !FileManager.default.fileExists(atPath: restoredBinary) {
                        let directBinary = (extractDir as NSString).appendingPathComponent("media.bin")
                        if FileManager.default.fileExists(atPath: directBinary) {
                            restoredBinary = directBinary
                            restoredText = (extractDir as NSString).appendingPathComponent("notes.txt")
                        }
                    }
                    
                    XCTAssertTrue(FileManager.default.fileExists(atPath: restoredBinary), "Format \(ext) extracted media.bin must exist")
                    XCTAssertTrue(FileManager.default.fileExists(atPath: restoredText), "Format \(ext) extracted notes.txt must exist")
                    
                    let restoredBinaryData = try Data(contentsOf: URL(fileURLWithPath: restoredBinary))
                    let restoredTextData = try Data(contentsOf: URL(fileURLWithPath: restoredText))
                    
                    XCTAssertEqual(restoredBinaryData, binaryData, "Format \(ext) binary data must match exactly")
                    XCTAssertEqual(restoredTextData, textData, "Format \(ext) text data must match exactly")
                }
            }
            
            try await group.waitForAll()
        }
    }

    func testZipDifferentialWithSystemUnzip() async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: "/usr/bin/unzip") else {
            throw XCTSkip("/usr/bin/unzip not found")
        }

        let batchDir = (tempDirPath as NSString).appendingPathComponent("diff_batch")
        try fileManager.createDirectory(atPath: batchDir, withIntermediateDirectories: true)

        var expectedDataMap: [String: Data] = [:]
        for i in 0..<100 {
            let filename = "item_\(i).txt"
            let filePath = (batchDir as NSString).appendingPathComponent(filename)
            let content = "TTZip Cache-Aware Batch Diff Test Payload \(i) -- " + String(repeating: "ABC123_", count: 10)
            let data = content.data(using: .utf8)!
            try data.write(to: URL(fileURLWithPath: filePath))
            expectedDataMap[filename] = data
        }

        let outputZip = (tempDirPath as NSString).appendingPathComponent("diff_output.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputZip,
            format: .zip,
            level: .normal,
            inputPaths: [batchDir]
        )

        XCTAssertTrue(fileManager.fileExists(atPath: outputZip))

        // Run /usr/bin/unzip -t outputZip
        let testProcess = Process()
        testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        testProcess.arguments = ["-t", outputZip]
        let pipe = Pipe()
        testProcess.standardOutput = pipe
        testProcess.standardError = pipe
        try testProcess.run()
        testProcess.waitUntilExit()

        XCTAssertEqual(testProcess.terminationStatus, 0, "System unzip test (-t) must return 0 errors")

        // Extract using /usr/bin/unzip
        let destDir = (tempDirPath as NSString).appendingPathComponent("unzip_dest")
        try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)

        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        extractProcess.arguments = ["-q", outputZip, "-d", destDir]
        try extractProcess.run()
        extractProcess.waitUntilExit()

        XCTAssertEqual(extractProcess.terminationStatus, 0, "System unzip extraction must succeed")

        // Verify content bit-for-bit
        for (filename, expectedData) in expectedDataMap {
            var extractedPath = (destDir as NSString).appendingPathComponent("diff_batch/\(filename)")
            if !fileManager.fileExists(atPath: extractedPath) {
                extractedPath = (destDir as NSString).appendingPathComponent(filename)
            }
            XCTAssertTrue(fileManager.fileExists(atPath: extractedPath), "Extracted file \(filename) must exist")
            let actualData = try Data(contentsOf: URL(fileURLWithPath: extractedPath))
            XCTAssertEqual(actualData, expectedData, "Extracted content for \(filename) must match bit-for-bit")
        }
    }
}
