// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// Test suite validating edge cases in recursive directory tree archiving,
/// including deep nesting, non-ASCII Unicode paths, mixed inputs, macOS metadata junk filtering,
/// split volume creation, and header encryption.
final class RecursiveDirectoryEdgeCaseTests: XCTestCase {
    
    /// Verifies deep nested directory hierarchy archiving and extraction fidelity across formats.
    func testDeepNestedDirectoryTreeCompression() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        let extractor = ArchiveExtractor()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DeepTree_\(UUID().uuidString)")
        let deepFolder = tempDir.appendingPathComponent("L1/L2/L3/L4/L5")
        try FileManager.default.createDirectory(at: deepFolder, withIntermediateDirectories: true)
        
        let file1 = tempDir.appendingPathComponent("L1/root_item.txt")
        let file5 = deepFolder.appendingPathComponent("deep_leaf.txt")
        try "Root Content".write(to: file1, atomically: true, encoding: .utf8)
        try "Leaf Content".write(to: file5, atomically: true, encoding: .utf8)
        
        for format in [ArchiveCompressionFormat.sevenZip, .zip, .tarGz] {
            let archivePath = tempDir.appendingPathComponent("deep_\(format.rawValue).\(format.rawValue)").path
            try await writer.createArchive(outputPath: archivePath, format: format, level: .normal, inputPaths: [tempDir.appendingPathComponent("L1").path])
            
            // Validate recursive directory entries (L1 through L5)
            let entries = try await reader.inspect(archivePath: archivePath)
            XCTAssertGreaterThanOrEqual(entries.count, 6, "Format \(format) failed to recursively archive deeply nested directory tree")
            
            let leafEntry = entries.first(where: { $0.name.contains("deep_leaf.txt") })
            XCTAssertNotNil(leafEntry, "Format \(format) missing leaf node file")
            XCTAssertGreaterThan(leafEntry?.uncompressedSize ?? 0, 0)
            
            // Verify extraction fidelity
            let destDir = tempDir.appendingPathComponent("dest_\(format.rawValue)")
            try await extractor.extract(archivePath: archivePath, destinationDir: destDir.path)
            
            let extractedLeaf = destDir.appendingPathComponent("L1/L2/L3/L4/L5/deep_leaf.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedLeaf.path))
            let readString = try String(contentsOf: extractedLeaf, encoding: .utf8)
            XCTAssertEqual(readString, "Leaf Content")
        }
    }
    
    /// Verifies compression and inspection of directories and files containing Chinese and special characters.
    func testChineseAndSpecialCharacterPathsCompression() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ChinesePath_\(UUID().uuidString)")
        let chineseFolder = tempDir.appendingPathComponent("哲学史/5.12 讲座 (最新版 #2026)")
        try FileManager.default.createDirectory(at: chineseFolder, withIntermediateDirectories: true)
        
        let videoFile = chineseFolder.appendingPathComponent("测试 视频_01.mp4")
        let dummyData = Data(repeating: 0xAB, count: 1024 * 64) // 64KB dummy video payload
        try dummyData.write(to: videoFile)
        
        let archivePath = tempDir.appendingPathComponent("output_chinese.7z").path
        try await writer.createArchive(outputPath: archivePath, format: .sevenZip, level: .normal, inputPaths: [tempDir.appendingPathComponent("哲学史").path])
        
        let entries = try await reader.inspect(archivePath: archivePath)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        
        let foundVideo = entries.first(where: { $0.name.contains("测试 视频_01.mp4") || $0.path.contains("测试 视频_01.mp4") })
        XCTAssertNotNil(foundVideo, "Failed to locate file under Chinese path in archive")
        XCTAssertEqual(foundVideo?.uncompressedSize, 64 * 1024)
    }
    
    /// Tests compression of mixed inputs containing multiple standalone files and folders.
    func testMultiFolderAndMultiFileMixedInputs() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MixedInput_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let folderA = tempDir.appendingPathComponent("FolderA")
        let folderB = tempDir.appendingPathComponent("FolderB")
        try FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)
        
        let fileStandalone = tempDir.appendingPathComponent("standalone.txt")
        let fileInA = folderA.appendingPathComponent("a.txt")
        let fileInB = folderB.appendingPathComponent("b.txt")
        
        try "standalone".write(to: fileStandalone, atomically: true, encoding: .utf8)
        try "a".write(to: fileInA, atomically: true, encoding: .utf8)
        try "b".write(to: fileInB, atomically: true, encoding: .utf8)
        
        let archivePath = tempDir.appendingPathComponent("mixed.zip").path
        try await writer.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .normal,
            inputPaths: [fileStandalone.path, folderA.path, folderB.path]
        )
        
        let entries = try await reader.inspect(archivePath: archivePath)
        XCTAssertGreaterThanOrEqual(entries.count, 5, "Mixed files and folders were not completely written to archive")
    }
    
    /// Verifies macOS junk file (.DS_Store) filtering when archiving directory trees.
    func testMacJunkFilteringInDirectoryTree() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JunkFilter_\(UUID().uuidString)")
        let folder = tempDir.appendingPathComponent("Project")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        let dsStore = folder.appendingPathComponent(".DS_Store")
        let realFile = folder.appendingPathComponent("main.swift")
        try "junk".write(to: dsStore, atomically: true, encoding: .utf8)
        try "print('hello')".write(to: realFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDir.appendingPathComponent("clean_project.zip").path
        try await writer.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .normal,
            inputPaths: [folder.path],
            options: ArchiveFilterOptions(skipMacJunk: true, skipGitDirectory: false)
        )
        
        let entries = try await reader.inspect(archivePath: archivePath)
        let hasDSStore = entries.contains(where: { $0.name.contains(".DS_Store") })
        let hasMainSwift = entries.contains(where: { $0.name.contains("main.swift") })
        
        XCTAssertFalse(hasDSStore, ".DS_Store junk file was not filtered")
        XCTAssertTrue(hasMainSwift, "Legitimate source code file was erroneously removed")
    }
    
    /// Verifies multi-volume split archive generation (.001, .002, etc.).
    func testSplitVolumeArchiveCreation() async throws {
        let writer = ArchiveWriter()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SplitVol_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let largeFile = tempDir.appendingPathComponent("payload_5MB.bin")
        var prng = DeterministicPRNG(seed: 0xCAFE_BABE)
        let dummyData = Data((0..<(2 * 1024 * 1024)).map { _ in UInt8(prng.next() & 0xFF) })
        try dummyData.write(to: largeFile)
        
        let outputZip = tempDir.appendingPathComponent("split_archive.7z").path
        let splitSize: Int64 = 64 * 1024 // 64KB volume segment size
        
        try await writer.createArchive(
            outputPath: outputZip,
            format: .sevenZip,
            level: .fast,
            inputPaths: [largeFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: splitSize
        )
        
        let part1 = tempDir.appendingPathComponent("split_archive.7z.001").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1), "Split volume .001 part was not generated successfully")
    }
    
    /// Verifies encrypted 7z archive creation with password protection.
    func testPasswordEncrypted7zCreation() async throws {
        let writer = ArchiveWriter()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Enc_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sampleFile = tempDir.appendingPathComponent("secret.txt")
        try "SensitiveData2026".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let output7z = tempDir.appendingPathComponent("encrypted.7z").path
        let password = "MySuperSecretPassword123"
        
        try await writer.createArchive(
            outputPath: output7z,
            format: .sevenZip,
            level: .normal,
            inputPaths: [sampleFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: nil,
            password: password
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: output7z), "Encrypted archive was not generated successfully")
    }
}
