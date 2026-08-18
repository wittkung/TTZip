// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class InteractiveTUITests: XCTestCase {
    
    // MARK: - 1. TUI Key Parser Tests
    
    func testSingleCharacterKeyParsing() {
        let actionQ = TUIKeyParser.parse(bytes: [UInt8(ascii: "q")])
        XCTAssertEqual(actionQ, .exit)
        
        let actionK = TUIKeyParser.parse(bytes: [UInt8(ascii: "k")])
        XCTAssertEqual(actionK, .up)
        
        let actionJ = TUIKeyParser.parse(bytes: [UInt8(ascii: "j")])
        XCTAssertEqual(actionJ, .down)
        
        let actionH = TUIKeyParser.parse(bytes: [UInt8(ascii: "h")])
        XCTAssertEqual(actionH, .left)
        
        let actionL = TUIKeyParser.parse(bytes: [UInt8(ascii: "l")])
        XCTAssertEqual(actionL, .right)
        
        let actionE = TUIKeyParser.parse(bytes: [UInt8(ascii: "e")])
        XCTAssertEqual(actionE, .extract)
        
        let actionP = TUIKeyParser.parse(bytes: [UInt8(ascii: "p")])
        XCTAssertEqual(actionP, .peek)
        
        let actionEnter = TUIKeyParser.parse(bytes: [0x0A])
        XCTAssertEqual(actionEnter, .enter)
        
        let actionSpace = TUIKeyParser.parse(bytes: [0x20])
        XCTAssertEqual(actionSpace, .space)
    }
    
    func testAnsiEscapeSequenceParsing() {
        // Up arrow: ESC [ A
        let actionUp = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x41])
        XCTAssertEqual(actionUp, .up)
        
        // Down arrow: ESC [ B
        let actionDown = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x42])
        XCTAssertEqual(actionDown, .down)
        
        // Right arrow: ESC [ C
        let actionRight = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x43])
        XCTAssertEqual(actionRight, .right)
        
        // Left arrow: ESC [ D
        let actionLeft = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x44])
        XCTAssertEqual(actionLeft, .left)
        
        // Page Up: ESC [ 5 ~
        let actionPgUp = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x35, 0x7E])
        XCTAssertEqual(actionPgUp, .pageUp)
        
        // Page Down: ESC [ 6 ~
        let actionPgDn = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x36, 0x7E])
        XCTAssertEqual(actionPgDn, .pageDown)
        
        // Home: ESC [ H
        let actionHome = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x48])
        XCTAssertEqual(actionHome, .home)
        
        // End: ESC [ F
        let actionEnd = TUIKeyParser.parse(bytes: [0x1B, 0x5B, 0x46])
        XCTAssertEqual(actionEnd, .end)
        
        // Lone Escape: ESC
        let actionEsc = TUIKeyParser.parse(bytes: [0x1B])
        XCTAssertEqual(actionEsc, .exit)
    }
    
    func testControlKeyParsing() {
        // Ctrl+C (0x03)
        let actionCtrlC = TUIKeyParser.parse(bytes: [0x03])
        XCTAssertEqual(actionCtrlC, .exit)
        
        // Ctrl+D (0x04)
        let actionCtrlD = TUIKeyParser.parse(bytes: [0x04])
        XCTAssertEqual(actionCtrlD, .pageDown)
    }
    
    // MARK: - 2. TUI Session Models & State Integrity
    
    func testTUISessionStateInitialization() {
        let row1 = TUIVisibleRow(
            name: "docs",
            path: "docs",
            isDirectory: true,
            depth: 0,
            isExpanded: true,
            sizeBytes: 1024,
            formattedSize: "1.0 KB",
            isSelected: false,
            indentationPrefix: "",
            iconEmoji: "📁"
        )
        
        let row2 = TUIVisibleRow(
            name: "readme.md",
            path: "docs/readme.md",
            isDirectory: false,
            depth: 1,
            isExpanded: false,
            sizeBytes: 512,
            formattedSize: "512 B",
            isSelected: true,
            indentationPrefix: "├── ",
            iconEmoji: "📄"
        )
        
        var state = TUISessionState(
            archivePath: "/tmp/sample.zip",
            currentDirectoryPath: "",
            cursorIndex: 0,
            scrollOffset: 0,
            expandedPaths: ["docs"],
            selectedPaths: ["docs/readme.md"],
            visibleRows: [row1, row2],
            isPeeking: false,
            peekContent: nil,
            flashMessage: "Welcome to TTZip TUI",
            isExiting: false,
            terminalRows: 24,
            terminalCols: 80
        )
        
        XCTAssertEqual(state.visibleRows.count, 2)
        XCTAssertEqual(state.selectedPaths.count, 1)
        XCTAssertTrue(state.selectedPaths.contains("docs/readme.md"))
        
        // Toggle selection
        state.selectedPaths.insert("docs")
        XCTAssertEqual(state.selectedPaths.count, 2)
        
        // Toggle peek
        state.isPeeking = true
        state.peekContent = TUIPeekContent(
            filePath: "docs/readme.md",
            mimeType: "text/markdown",
            uncompressedSize: 512,
            formattedSize: "512 B",
            lines: ["# TTZip", "Fast archive engine"],
            hexDump: nil,
            metadata: ["Format": "ZIP"],
            isTruncated: false
        )
        XCTAssertTrue(state.isPeeking)
        XCTAssertEqual(state.peekContent?.lines.count, 2)
    }
    
    // MARK: - 3. Non-Interactive Fallback Test
    
    func testInteractiveTUIExplorerNonInteractiveRun() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipPath = tempDir.appendingPathComponent("test_archive.zip").path
        let sampleFile = tempDir.appendingPathComponent("sample.txt").path
        try "Hello TUI Explorer".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipPath,
            format: .zip,
            level: .fast,
            inputPaths: [sampleFile]
        )
        
        let explorer = InteractiveTUIExplorer(archivePath: zipPath)
        let exitCode = try await explorer.run()
        // In test environments (non-TTY), run() returns 0 gracefully
        XCTAssertEqual(exitCode, 0)
    }
}
