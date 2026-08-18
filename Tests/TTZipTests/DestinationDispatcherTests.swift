// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipApp
@testable import TTZipCore

final class DestinationDispatcherTests: XCTestCase {
    
    private var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DestinationDispatcherTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let dir = tempDirectoryURL, FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - Classification Tests
    
    func testClassifyDirectory() throws {
        let subDir = tempDirectoryURL.appendingPathComponent("TestSubFolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let result = DestinationDispatcher.classify(path: subDir.path)
        
        XCTAssertEqual(result.destinationType, .directory)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(result.isDirectory)
        XCTAssertFalse(result.isArchive)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.sanitizedPath, subDir.path)
    }
    
    func testClassifyArchiveExtensions() throws {
        let archiveExtensions = [
            "zip",
            "7z",
            "tar.gz",
            "zst",
            "tar.xz",
            "rar",
            "dmg",
            "iso",
            "wim",
            "lz4",
            "tar.bz2"
        ]
        
        for ext in archiveExtensions {
            let filename = "sample_\(ext.replacingOccurrences(of: ".", with: "_")).\(ext)"
            let archiveURL = tempDirectoryURL.appendingPathComponent(filename)
            try "dummy content".data(using: .utf8)?.write(to: archiveURL)
            
            let result = DestinationDispatcher.classify(path: archiveURL.path)
            
            XCTAssertEqual(
                result.destinationType,
                .archive,
                "Expected \(ext) to be classified as .archive"
            )
            XCTAssertTrue(result.exists)
            XCTAssertFalse(result.isDirectory)
            XCTAssertTrue(result.isArchive)
            XCTAssertNil(result.errorMessage)
            XCTAssertEqual(result.sanitizedPath, archiveURL.path)
        }
    }
    
    func testClassifyRegularFile() throws {
        let fileExtensions = ["txt", "png", "json", "pdf", "sh", "swift"]
        
        for ext in fileExtensions {
            let filename = "sample.\(ext)"
            let fileURL = tempDirectoryURL.appendingPathComponent(filename)
            try "dummy text".data(using: .utf8)?.write(to: fileURL)
            
            let result = DestinationDispatcher.classify(path: fileURL.path)
            
            XCTAssertEqual(
                result.destinationType,
                .file,
                "Expected \(ext) to be classified as .file"
            )
            XCTAssertTrue(result.exists)
            XCTAssertFalse(result.isDirectory)
            XCTAssertFalse(result.isArchive)
            XCTAssertNil(result.errorMessage)
            XCTAssertEqual(result.sanitizedPath, fileURL.path)
        }
    }
    
    func testClassifyNonExistentPath() {
        let nonExistentPath = tempDirectoryURL.appendingPathComponent("non_existent_file_98765.zip").path
        
        let result = DestinationDispatcher.classify(path: nonExistentPath)
        
        XCTAssertEqual(result.destinationType, .notFound)
        XCTAssertFalse(result.exists)
        XCTAssertFalse(result.isDirectory)
        XCTAssertFalse(result.isArchive)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertEqual(result.sanitizedPath, nonExistentPath)
    }
    
    func testClassifyURLConvenience() throws {
        let subDir = tempDirectoryURL.appendingPathComponent("URLDir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let dirResult = DestinationDispatcher.classify(url: subDir)
        XCTAssertEqual(dirResult.destinationType, .directory)
        XCTAssertTrue(dirResult.isDirectory)
        
        let archiveURL = tempDirectoryURL.appendingPathComponent("test.zip")
        try "data".data(using: .utf8)?.write(to: archiveURL)
        
        let archiveResult = DestinationDispatcher.classify(url: archiveURL)
        XCTAssertEqual(archiveResult.destinationType, .archive)
        XCTAssertTrue(archiveResult.isArchive)
    }
    
    // MARK: - Dispatch Routing Tests
    
    @MainActor
    func testDispatchDirectoryRouting() throws {
        let targetDir = tempDirectoryURL.appendingPathComponent("TargetDirectory")
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let appViewState = AppViewState()
        let initialURL = tempDirectoryURL!
        appViewState.currentDirectory = initialURL
        appViewState.selectedDiskItem = DiskItemInfo(url: tempDirectoryURL)
        
        let result = DestinationDispatcher.classify(path: targetDir.path)
        let success = DestinationDispatcher.dispatch(result: result, appViewState: appViewState)
        
        XCTAssertTrue(success)
        XCTAssertEqual(appViewState.currentDirectory.path, targetDir.path)
        XCTAssertNil(appViewState.selectedDiskItem)
    }
    
    @MainActor
    func testDispatchArchiveRouting() throws {
        let archiveURL = tempDirectoryURL.appendingPathComponent("BundleArchive.zip")
        try "archive payload".data(using: .utf8)?.write(to: archiveURL)
        
        let appViewState = AppViewState()
        let result = DestinationDispatcher.classify(path: archiveURL.path)
        let success = DestinationDispatcher.dispatch(result: result, appViewState: appViewState)
        
        XCTAssertTrue(success)
        XCTAssertEqual(appViewState.currentDirectory.path, tempDirectoryURL.path)
        XCTAssertEqual(appViewState.selectedDiskItem?.path, archiveURL.path)
        XCTAssertEqual(appViewState.selectedDiskItem?.isArchive, true)
        XCTAssertEqual(appViewState.activeTab, .home)
    }
    
    @MainActor
    func testDispatchFileRouting() throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("Readme.txt")
        try "text content".data(using: .utf8)?.write(to: fileURL)
        
        let appViewState = AppViewState()
        let result = DestinationDispatcher.classify(path: fileURL.path)
        let success = DestinationDispatcher.dispatch(result: result, appViewState: appViewState)
        
        XCTAssertTrue(success)
        XCTAssertEqual(appViewState.currentDirectory.path, tempDirectoryURL.path)
        XCTAssertEqual(appViewState.selectedDiskItem?.path, fileURL.path)
        XCTAssertEqual(appViewState.selectedDiskItem?.isArchive, false)
    }
    
    @MainActor
    func testDispatchNotFoundRouting() {
        let appViewState = AppViewState()
        let initialDir = tempDirectoryURL!
        appViewState.currentDirectory = initialDir
        appViewState.selectedDiskItem = nil
        
        let nonExistentPath = tempDirectoryURL.appendingPathComponent("missing_archive.7z").path
        let result = DestinationDispatcher.classify(path: nonExistentPath)
        let success = DestinationDispatcher.dispatch(result: result, appViewState: appViewState)
        
        XCTAssertFalse(success)
        XCTAssertEqual(appViewState.currentDirectory.path, initialDir.path)
        XCTAssertNil(appViewState.selectedDiskItem)
    }
    
    @MainActor
    func testDirectPathDispatchConvenience() throws {
        let targetDir = tempDirectoryURL.appendingPathComponent("ConvenienceDir")
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let appViewState = AppViewState()
        let success = DestinationDispatcher.dispatch(path: targetDir.path, appViewState: appViewState)
        
        XCTAssertTrue(success)
        XCTAssertEqual(appViewState.currentDirectory.path, targetDir.path)
        XCTAssertNil(appViewState.selectedDiskItem)
    }
}
