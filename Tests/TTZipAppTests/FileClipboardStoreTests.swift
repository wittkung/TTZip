// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class FileClipboardStoreTests: XCTestCase {
    
    var tempDirURL: URL!
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("FileClipboardTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    @MainActor
    func testFileClipboardStore() throws {
        let store = FileClipboardStore.shared
        let file1 = tempDirURL.appendingPathComponent("clip_1.txt")
        try "Clip 1".write(to: file1, atomically: true, encoding: .utf8)
        
        store.copy(urls: [file1])
        XCTAssertTrue(store.canPaste)
        XCTAssertFalse(store.isCutOperation)
        
        let pasteTargetDir = tempDirURL.appendingPathComponent("pasted_target")
        try FileManager.default.createDirectory(at: pasteTargetDir, withIntermediateDirectories: true)
        
        store.paste(to: pasteTargetDir)
        let pastedFile = pasteTargetDir.appendingPathComponent("clip_1.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pastedFile.path))
    }
}
