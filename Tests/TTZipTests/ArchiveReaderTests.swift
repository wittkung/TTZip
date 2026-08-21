// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveReaderTests: XCTestCase {
    
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
    
    func testNonExistentFileThrowsError() async {
        let reader = ArchiveReader()
        let fakePath = "/non/existent/file_\(UUID().uuidString).zip"
        
        do {
            _ = try await reader.inspect(archivePath: fakePath)
            XCTFail("Should throw ArchiveError.fileNotFound")
        } catch let error as ArchiveError {
            if case .fileNotFound = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected fileNotFound error but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInvalidArchiveFormatThrowsError() async throws {
        let reader = ArchiveReader()
        let plainTextPath = (tempDirPath as NSString).appendingPathComponent("plain.txt")
        try "Hello World".write(toFile: plainTextPath, atomically: true, encoding: .utf8)
        
        do {
            _ = try await reader.inspect(archivePath: plainTextPath)
            XCTFail("Should throw ArchiveError.readFailed")
        } catch let error as ArchiveError {
            if case .readFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected readFailed error but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testInspectZipArchiveSuccess() async throws {
        let reader = ArchiveReader()
        
        // Process zip
        let sampleTxt = (tempDirPath as NSString).appendingPathComponent("sample.txt")
        try "Sample text content".write(toFile: sampleTxt, atomically: true, encoding: .utf8)
        
        let zipPath = (tempDirPath as NSString).appendingPathComponent("test.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-j", zipPath, sampleTxt]
        try process.run()
        process.waitUntilExit()
        
        XCTAssertEqual(process.terminationStatus, 0)
        
        let entries = try await reader.inspect(archivePath: zipPath)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "sample.txt")
        XCTAssertFalse(entries.first?.isDirectory ?? true)
    }
    
    func testInspectTarGzArchiveSuccess() async throws {
        let reader = ArchiveReader()
        
        let sampleTxt = (tempDirPath as NSString).appendingPathComponent("sample.txt")
        try "Sample text content".write(toFile: sampleTxt, atomically: true, encoding: .utf8)
        
        let tarPath = (tempDirPath as NSString).appendingPathComponent("test.tar.gz")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", tarPath, "-C", tempDirPath, "sample.txt"]
        try process.run()
        process.waitUntilExit()
        
        XCTAssertEqual(process.terminationStatus, 0)
        
        let entries = try await reader.inspect(archivePath: tarPath)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "sample.txt")
    }
    
    func testInspectEncryptedSplitArchiveDirectoryStructure() async throws {
        let reader = ArchiveReader()
        
        let folderPath = (tempDirPath as NSString).appendingPathComponent("5.12")
        let subFolderPath = (folderPath as NSString).appendingPathComponent("4k")
        try FileManager.default.createDirectory(atPath: subFolderPath, withIntermediateDirectories: true)
        
        let audio1 = (folderPath as NSString).appendingPathComponent("5.12-1.m4a")
        let video = (subFolderPath as NSString).appendingPathComponent("movie.mp4")
        try "audio_data".write(toFile: audio1, atomically: true, encoding: .utf8)
        try "video_data".write(toFile: video, atomically: true, encoding: .utf8)
        
        let splitBase = (tempDirPath as NSString).appendingPathComponent("split_test.7z")
        let process = Process()
        guard let binPath = SevenZipBinaryResolver.resolveBinaryPath() else { return }
        process.executableURL = URL(fileURLWithPath: binPath)
        process.arguments = ["a", "-t7z", "-p123456", "-mhe=on", "-v10k", splitBase, folderPath]
        try process.run()
        process.waitUntilExit()
        
        let vol1 = (tempDirPath as NSString).appendingPathComponent("split_test.7z.001")
        let volRaw = (tempDirPath as NSString).appendingPathComponent("split_test.7z")
        let targetVolume = FileManager.default.fileExists(atPath: vol1) ? vol1 : (FileManager.default.fileExists(atPath: volRaw) ? volRaw : splitBase)
        let entries = try await reader.inspect(archivePath: targetVolume, password: "123456")
        
        XCTAssertFalse(entries.isEmpty)
        let paths = entries.map { $0.path }
        XCTAssertTrue(paths.contains(where: { $0.contains("5.12") }))
        XCTAssertTrue(paths.contains(where: { $0.contains("5.12-1.m4a") }))
        XCTAssertTrue(paths.contains(where: { $0.contains("movie.mp4") }))
        
        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertFalse(tree.isEmpty)
    }
}
