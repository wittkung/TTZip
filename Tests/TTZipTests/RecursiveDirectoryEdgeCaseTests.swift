// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class RecursiveDirectoryEdgeCaseTests: XCTestCase {
    
    /// 1. 5
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
            
            // ( L1, L2, L3, L4, L5 )
            let entries = try await reader.inspect(archivePath: archivePath)
            XCTAssertGreaterThanOrEqual(entries.count, 6, "格式 \(format) 未能完整递归压入深层目录树")
            
            let leafEntry = entries.first(where: { $0.name.contains("deep_leaf.txt") })
            XCTAssertNotNil(leafEntry, "格式 \(format) 缺失叶子节点文件")
            XCTAssertGreaterThan(leafEntry?.uncompressedSize ?? 0, 0)
            
            // Verify expected invariant
            let destDir = tempDir.appendingPathComponent("dest_\(format.rawValue)")
            try await extractor.extract(archivePath: archivePath, destinationDir: destDir.path)
            
            let extractedLeaf = destDir.appendingPathComponent("L1/L2/L3/L4/L5/deep_leaf.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedLeaf.path))
            let readString = try String(contentsOf: extractedLeaf, encoding: .utf8)
            XCTAssertEqual(readString, "Leaf Content")
        }
    }
    
    /// 2. 、
    func testChineseAndSpecialCharacterPathsCompression() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ChinesePath_\(UUID().uuidString)")
        let chineseFolder = tempDir.appendingPathComponent("哲学史/5.12 讲座 (最新版 #2026)")
        try FileManager.default.createDirectory(at: chineseFolder, withIntermediateDirectories: true)
        
        let videoFile = chineseFolder.appendingPathComponent("测试 视频_01.mp4")
        let dummyData = Data(repeating: 0xAB, count: 1024 * 64) // 64KB 模拟视频数据
        try dummyData.write(to: videoFile)
        
        let archivePath = tempDir.appendingPathComponent("output_chinese.7z").path
        try await writer.createArchive(outputPath: archivePath, format: .sevenZip, level: .normal, inputPaths: [tempDir.appendingPathComponent("哲学史").path])
        
        let entries = try await reader.inspect(archivePath: archivePath)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        
        let foundVideo = entries.first(where: { $0.name.contains("测试 视频_01.mp4") || $0.path.contains("测试 视频_01.mp4") })
        XCTAssertNotNil(foundVideo, "未能在压缩包中找到中文路径下的文件")
        XCTAssertEqual(foundVideo?.uncompressedSize, 64 * 1024)
    }
    
    /// Validates expected behavior and invariants.
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
        XCTAssertGreaterThanOrEqual(entries.count, 5, "混合多文件与多文件夹未被完整写入包中")
    }
    
    /// 4. macOS (.DS_Store / __MACOSX)
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
        
        XCTAssertFalse(hasDSStore, ".DS_Store 垃圾文件未被过滤")
        XCTAssertTrue(hasMainSwift, "正常源码文件误遭剔除")
    }
    
    /// 5. (7z / Zip .001, .002...)
    func testSplitVolumeArchiveCreation() async throws {
        let writer = ArchiveWriter()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SplitVol_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let largeFile = tempDir.appendingPathComponent("payload_5MB.bin")
        let dummyData = Data(repeating: 0x5A, count: 5 * 1024 * 1024)
        try dummyData.write(to: largeFile)
        
        let outputZip = tempDir.appendingPathComponent("split_archive.7z").path
        let splitSize: Int64 = 1 * 1024 * 1024 // 1MB 切片
        
        try await writer.createArchive(
            outputPath: outputZip,
            format: .sevenZip,
            level: .fast,
            inputPaths: [largeFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: splitSize
        )
        
        let part1 = tempDir.appendingPathComponent("split_archive.7z.001").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1), "分卷压缩包 .001 卷未成功生成")
    }
    
    /// 6. Header (-p -mhe=on)
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
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: output7z), "加密压缩包未成功生成")
    }
}
