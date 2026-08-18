// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class QuickLookPreviewTests: XCTestCase {
    
    func testQuickLookPreviewDataExtraction() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sampleFile1 = tempDir.appendingPathComponent("document.txt")
        let sampleFile2 = tempDir.appendingPathComponent("image.png")
        try "Document Text Content".write(to: sampleFile1, atomically: true, encoding: .utf8)
        try "Fake PNG Image Bytes Data Content".write(to: sampleFile2, atomically: true, encoding: .utf8)
        
        let outArchive = tempDir.appendingPathComponent("preview_test.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outArchive,
            format: .zip,
            level: .fast,
            inputPaths: [sampleFile1.path, sampleFile2.path]
        )
        
        let previewData = try await QuickLookPreviewEngine.inspectForPreview(archivePath: outArchive)
        XCTAssertEqual(previewData.archiveName, "preview_test.zip")
        XCTAssertEqual(previewData.format, .zip)
        XCTAssertEqual(previewData.totalEntriesCount, 2)
        XCTAssertGreaterThan(previewData.uncompressedSizeBytes, 0)
        XCTAssertFalse(previewData.isEncrypted)
        XCTAssertEqual(previewData.rootNodes.count, 2)
    }
    
    func testQuickLookHTMLGeneration() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sampleFile = tempDir.appendingPathComponent("readme.md")
        try "# TTZip QuickLook\nHigh performance".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let outArchive = tempDir.appendingPathComponent("html_test.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outArchive,
            format: .zip,
            level: .fast,
            inputPaths: [sampleFile.path]
        )
        
        let html = try await QuickLookPreviewEngine.generateHTMLPreview(for: outArchive)
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("html_test.zip"))
        XCTAssertTrue(html.contains("readme.md"))
        XCTAssertTrue(html.contains("TTZip ⚡️"))
    }
    
    func testFinderSyncContextMenuForArchivesAndFiles() {
        let archiveURL = URL(fileURLWithPath: "/tmp/sample.7z")
        let itemsForArchive = FinderSyncHelper.shared.getContextMenuItems(selectedURLs: [archiveURL])
        XCTAssertFalse(itemsForArchive.isEmpty)
        XCTAssertTrue(itemsForArchive.contains { $0.actionIdentifier == "extract_here" })
        XCTAssertTrue(itemsForArchive.contains { $0.actionIdentifier == "inspect_archive" })
        
        let plainFolderURL = URL(fileURLWithPath: "/Users/dev/Documents")
        let itemsForFolder = FinderSyncHelper.shared.getContextMenuItems(selectedURLs: [plainFolderURL])
        XCTAssertFalse(itemsForFolder.isEmpty)
        XCTAssertTrue(itemsForFolder.contains { $0.actionIdentifier == "compress_quick_7z" })
        XCTAssertTrue(itemsForFolder.contains { $0.actionIdentifier == "compress_quick_zip" })
    }
    
    func testFinderSyncAll16SupportedExtensions() {
        let allExtensions = [
            "zip", "7z", "tar", "gz", "bz2", "xz", "zst", "lz4",
            "lz", "lrz", "aar", "sz", "wim", "dmg", "iso", "rar"
        ]
        for ext in allExtensions {
            XCTAssertTrue(
                FinderSyncHelper.supportedArchiveExtensions.contains(ext),
                "FinderSyncHelper 必须识别 .\(ext) 为归档格式"
            )
        }
    }
    
    func testQuickLookPreviewPayloadJSONSerializationContract() throws {
        let treeNode = PreviewTreeNode(
            id: "folder/file.txt",
            name: "file.txt",
            relativePath: "folder/file.txt",
            isDirectory: false,
            uncompressedSizeBytes: 1024,
            isEncrypted: false,
            children: nil
        )
        
        let rootNode = PreviewTreeNode(
            id: "folder",
            name: "folder",
            relativePath: "folder",
            isDirectory: true,
            uncompressedSizeBytes: 1024,
            isEncrypted: false,
            children: [treeNode]
        )
        
        let payload = QuickLookPreviewPayload(
            archivePath: "/tmp/sample.zip",
            archiveName: "sample.zip",
            formatIdentifier: "zip",
            uncompressedSizeBytes: 2048,
            compressedSizeBytes: 1024,
            compressionRatioPercent: 50.0,
            totalEntriesCount: 2,
            isEncrypted: false,
            rootNodes: [rootNode]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(payload)
        
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["archivePath"] as? String, "/tmp/sample.zip")
        XCTAssertEqual(jsonObject?["archiveName"] as? String, "sample.zip")
        XCTAssertEqual(jsonObject?["formatIdentifier"] as? String, "zip")
        XCTAssertEqual(jsonObject?["uncompressedSizeBytes"] as? Int64, 2048)
        XCTAssertEqual(jsonObject?["compressedSizeBytes"] as? Int64, 1024)
        XCTAssertEqual(jsonObject?["compressionRatioPercent"] as? Double, 50.0)
        XCTAssertEqual(jsonObject?["totalEntriesCount"] as? Int, 2)
        XCTAssertEqual(jsonObject?["isEncrypted"] as? Bool, false)
        
        let rootNodesArray = jsonObject?["rootNodes"] as? [[String: Any]]
        XCTAssertEqual(rootNodesArray?.count, 1)
        XCTAssertEqual(rootNodesArray?[0]["name"] as? String, "folder")
        XCTAssertEqual(rootNodesArray?[0]["isDirectory"] as? Bool, true)
        
        let children = rootNodesArray?[0]["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        XCTAssertEqual(children?[0]["name"] as? String, "file.txt")
        XCTAssertEqual(children?[0]["relativePath"] as? String, "folder/file.txt")
        XCTAssertEqual(children?[0]["isDirectory"] as? Bool, false)
        XCTAssertEqual(children?[0]["uncompressedSizeBytes"] as? Int64, 1024)
        XCTAssertEqual(children?[0]["isEncrypted"] as? Bool, false)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QuickLookPreviewPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.format, .zip)
    }
    
    func testFinderSyncActionRequestJSONSerializationContract() throws {
        let request = FinderSyncActionRequest(
            action: .compressQuick7z,
            sourcePaths: ["/Users/dev/file1.txt", "/Users/dev/file2.txt"],
            destinationDirectory: "/Users/dev/output",
            sanitizeMacMetadata: true,
            password: "SecretPassword123"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(request)
        
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["actionIdentifier"] as? String, "compress_quick_7z")
        XCTAssertEqual(jsonObject?["sourcePaths"] as? [String], ["/Users/dev/file1.txt", "/Users/dev/file2.txt"])
        XCTAssertEqual(jsonObject?["destinationDirectory"] as? String, "/Users/dev/output")
        XCTAssertEqual(jsonObject?["sanitizeMacMetadata"] as? Bool, true)
        XCTAssertEqual(jsonObject?["password"] as? String, "SecretPassword123")
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FinderSyncActionRequest.self, from: data)
        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.typedAction, .compressQuick7z)
    }
    
    func testFinderSyncActionIdentifierAllCases() {
        let expectedCases: [FinderSyncActionIdentifier: String] = [
            .extractHere: "extract_here",
            .extractToSubfolder: "extract_to_subfolder",
            .inspectArchive: "inspect_archive",
            .compressQuick7z: "compress_quick_7z",
            .compressQuickZip: "compress_quick_zip",
            .compressSeparate: "compress_separate",
            .compressAndDeleteSource: "compress_and_delete_source",
            .compressModalAdvanced: "compress_modal_advanced",
            .autofillPassword: "autofill_password",
            .computeHash: "compute_hash"
        ]
        
        XCTAssertEqual(FinderSyncActionIdentifier.allCases.count, 10)
        for (action, raw) in expectedCases {
            XCTAssertEqual(action.rawValue, raw)
            XCTAssertEqual(FinderSyncActionIdentifier(rawValue: raw), action)
        }
    }
}
