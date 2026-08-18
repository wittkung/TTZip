// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class InPlaceEditSessionTests: XCTestCase {
    
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_in_place_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testInPlaceEditSessionStateTransitions() {
        var session = InPlaceEditSession(
            sessionId: "test-session-123",
            archivePath: "/tmp/archive.zip",
            entryPath: "config.json",
            stagedFilePath: "/tmp/staged/config.json",
            stagedDirectoryPath: "/tmp/staged",
            state: .staged,
            initialHash: "hash123",
            lastKnownMtime: Date().timeIntervalSince1970,
            hasUnsavedChanges: false,
            errorMessage: nil
        )
        
        XCTAssertEqual(session.state, .staged)
        XCTAssertFalse(session.hasUnsavedChanges)
        
        session.state = .listening
        XCTAssertEqual(session.state, .listening)
        
        session.hasUnsavedChanges = true
        XCTAssertTrue(session.hasUnsavedChanges)
        
        session.state = .syncing
        XCTAssertEqual(session.state, .syncing)
        
        session.state = .saved
        XCTAssertEqual(session.state, .saved)
        
        session.state = .closed
        XCTAssertEqual(session.state, .closed)
    }
}

