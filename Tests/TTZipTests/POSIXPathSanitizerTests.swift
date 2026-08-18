// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipApp

final class POSIXPathSanitizerTests: XCTestCase {
    
    private var testBaseURL: URL {
        URL(fileURLWithPath: "/Users/test/Documents")
    }
    
    // MARK: - Tilde Expansion Tests
    
    func testTildeExpansion() {
        let home = NSHomeDirectory()
        
        let resHome = POSIXPathSanitizer.sanitize(rawInput: "~")
        XCTAssertEqual(resHome, home)
        
        let resDownloads = POSIXPathSanitizer.sanitize(rawInput: "~/Downloads")
        XCTAssertEqual(resDownloads, "\(home)/Downloads")
        
        let resWithParent = POSIXPathSanitizer.sanitize(rawInput: "~/Desktop/../Downloads")
        XCTAssertEqual(resWithParent, "\(home)/Downloads")
    }
    
    // MARK: - Shell Escaped Sequences Tests
    
    func testShellEscapes() {
        let raw = #"/Users/test/My\ Space/File\ \(1\).zip"#
        let sanitized = POSIXPathSanitizer.sanitize(rawInput: raw)
        XCTAssertEqual(sanitized, "/Users/test/My Space/File (1).zip")
        
        let complexRaw = #"/var/tmp/Special\[1\]\&\$name.tar"#
        let complexSanitized = POSIXPathSanitizer.sanitize(rawInput: complexRaw)
        XCTAssertEqual(complexSanitized, "/var/tmp/Special[1]&$name.tar")
    }
    
    // MARK: - File URL Unescaping Tests
    
    func testFileURLs() {
        let fileURLStr = "file:///Users/test/Downloads/abc%20def"
        let sanitized = POSIXPathSanitizer.sanitize(rawInput: fileURLStr)
        XCTAssertEqual(sanitized, "/Users/test/Downloads/abc def")
        
        let localhostURLStr = "file://localhost/Users/test/archive.zip"
        let sanitizedLocalhost = POSIXPathSanitizer.sanitize(rawInput: localhostURLStr)
        XCTAssertEqual(sanitizedLocalhost, "/Users/test/archive.zip")
    }
    
    // MARK: - Relative Path Resolution Tests
    
    func testRelativePaths() {
        let resParent = POSIXPathSanitizer.sanitize(rawInput: "../folder", relativeTo: testBaseURL)
        XCTAssertEqual(resParent, "/Users/test/folder")
        
        let resChild = POSIXPathSanitizer.sanitize(rawInput: "./child", relativeTo: testBaseURL)
        XCTAssertEqual(resChild, "/Users/test/Documents/child")
        
        let resSubdir = POSIXPathSanitizer.sanitize(rawInput: "sub/archive.7z", relativeTo: testBaseURL)
        XCTAssertEqual(resSubdir, "/Users/test/Documents/sub/archive.7z")
    }
    
    // MARK: - Redundant Slashes Normalization Tests
    
    func testRedundantSlashes() {
        let res = POSIXPathSanitizer.sanitize(rawInput: "///var///tmp///")
        XCTAssertEqual(res, "/var/tmp")
        
        let root = POSIXPathSanitizer.sanitize(rawInput: "///")
        XCTAssertEqual(root, "/")
    }
    
    // MARK: - Quotes and Whitespace Trimming Tests
    
    func testQuotesAndWhitespaceTrimming() {
        let doubleQuoted = "  \"/Users/test/Documents\"  "
        XCTAssertEqual(POSIXPathSanitizer.sanitize(rawInput: doubleQuoted), "/Users/test/Documents")
        
        let singleQuoted = "  '~/Downloads'  "
        XCTAssertEqual(POSIXPathSanitizer.sanitize(rawInput: singleQuoted), "\(NSHomeDirectory())/Downloads")
        
        let empty = "   "
        XCTAssertEqual(POSIXPathSanitizer.sanitize(rawInput: empty), "")
    }
    
    // MARK: - isPathLike Detection Tests
    
    func testIsPathLike() {
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "/Users/test"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "~/Downloads"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "~"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "./child"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "../parent"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "."))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "file:///var/tmp"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: "folder/archive.zip"))
        XCTAssertTrue(POSIXPathSanitizer.isPathLike(input: " \"/Users/test\" "))
        
        XCTAssertFalse(POSIXPathSanitizer.isPathLike(input: "searchKeyword"))
        XCTAssertFalse(POSIXPathSanitizer.isPathLike(input: "archive.zip"))
        XCTAssertFalse(POSIXPathSanitizer.isPathLike(input: ""))
        XCTAssertFalse(POSIXPathSanitizer.isPathLike(input: "   "))
    }
    
    // MARK: - extractParentAndPrefix Calculation Tests
    
    func testExtractParentAndPrefix() {
        let home = NSHomeDirectory()
        
        // Absolute path with child prefix
        let (p1, f1) = POSIXPathSanitizer.extractParentAndPrefix(input: "/var/lo", relativeTo: testBaseURL)
        XCTAssertEqual(p1, "/var")
        XCTAssertEqual(f1, "lo")
        
        // Absolute directory with trailing slash
        let (p2, f2) = POSIXPathSanitizer.extractParentAndPrefix(input: "/var/log/", relativeTo: testBaseURL)
        XCTAssertEqual(p2, "/var/log")
        XCTAssertEqual(f2, "")
        
        // Root slash
        let (p3, f3) = POSIXPathSanitizer.extractParentAndPrefix(input: "/", relativeTo: testBaseURL)
        XCTAssertEqual(p3, "/")
        XCTAssertEqual(f3, "")
        
        // Tilde prefix
        let (p4, f4) = POSIXPathSanitizer.extractParentAndPrefix(input: "~/Down", relativeTo: testBaseURL)
        XCTAssertEqual(p4, home)
        XCTAssertEqual(f4, "Down")
        
        // Tilde trailing slash
        let (p5, f5) = POSIXPathSanitizer.extractParentAndPrefix(input: "~/Downloads/", relativeTo: testBaseURL)
        XCTAssertEqual(p5, "\(home)/Downloads")
        XCTAssertEqual(f5, "")
        
        // Lone tilde
        let (p6, f6) = POSIXPathSanitizer.extractParentAndPrefix(input: "~", relativeTo: testBaseURL)
        XCTAssertEqual(p6, home)
        XCTAssertEqual(f6, "")
        
        // Relative path with child prefix
        let (p7, f7) = POSIXPathSanitizer.extractParentAndPrefix(input: "sub/fil", relativeTo: testBaseURL)
        XCTAssertEqual(p7, "/Users/test/Documents/sub")
        XCTAssertEqual(f7, "fil")
        
        // Shell escaped path
        let (p8, f8) = POSIXPathSanitizer.extractParentAndPrefix(input: #"/Users/test/My\ Sp"#, relativeTo: testBaseURL)
        XCTAssertEqual(p8, "/Users/test")
        XCTAssertEqual(f8, "My Sp")
        
        // File URL
        let (p9, f9) = POSIXPathSanitizer.extractParentAndPrefix(input: "file:///Users/test/Downloads/abc", relativeTo: testBaseURL)
        XCTAssertEqual(p9, "/Users/test/Downloads")
        XCTAssertEqual(f9, "abc")
        
        // Empty input
        let (p10, f10) = POSIXPathSanitizer.extractParentAndPrefix(input: "", relativeTo: testBaseURL)
        XCTAssertEqual(p10, "/Users/test/Documents")
        XCTAssertEqual(f10, "")
    }
}
