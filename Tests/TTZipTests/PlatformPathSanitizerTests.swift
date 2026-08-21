// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class PlatformPathSanitizerTests: XCTestCase {
    
    func testBasicPathNormalization() {
        let res = PlatformPathSanitizer.sanitize(path: "folder//subfolder/./file.txt")
        XCTAssertEqual(res.normalizedPath, "folder/subfolder/file.txt")
        XCTAssertFalse(res.isAbsolute)
        XCTAssertFalse(res.isUNCPath)
    }
    
    func testWindowsBackslashSeparators() {
        let res = PlatformPathSanitizer.sanitize(path: "folder\\subfolder\\file.txt")
        XCTAssertEqual(res.normalizedPath, "folder/subfolder/file.txt")
        XCTAssertEqual(res.win32FormattedPath, "folder\\subfolder\\file.txt")
    }
    
    func testZipSlipTraversalNeutralization() {
        let res = PlatformPathSanitizer.sanitize(path: "safe/../../outside/secret.txt")
        XCTAssertEqual(res.normalizedPath, "outside/secret.txt")
    }
    
    func testWindowsReservedDeviceNamesDetection() {
        let resCon = PlatformPathSanitizer.sanitize(path: "docs/con.txt")
        XCTAssertTrue(resCon.containsWindowsReservedDeviceName)
        
        let resPrn = PlatformPathSanitizer.sanitize(path: "PRN/report.pdf")
        XCTAssertTrue(resPrn.containsWindowsReservedDeviceName)
        
        let resAux = PlatformPathSanitizer.sanitize(path: "aux")
        XCTAssertTrue(resAux.containsWindowsReservedDeviceName)
        
        let resPhysical = PlatformPathSanitizer.sanitize(path: "\\\\.\\PhysicalDrive0")
        XCTAssertTrue(resPhysical.containsWindowsReservedDeviceName)
    }
    
    func testNTFSAlternateDataStreamStripping() {
        let res = PlatformPathSanitizer.sanitize(path: "invoice.pdf:malicious.exe")
        XCTAssertEqual(res.normalizedPath, "invoice.pdf")
        XCTAssertEqual(res.strippedAlternateDataStream, ":malicious.exe")
    }
    
    func testWindowsDriveLetterPreservation() {
        let res = PlatformPathSanitizer.sanitize(path: "C:\\Users\\TTZip\\archive.zip")
        XCTAssertTrue(res.isAbsolute)
        XCTAssertEqual(res.normalizedPath, "C:/Users/TTZip/archive.zip")
        XCTAssertEqual(res.win32FormattedPath, "C:\\Users\\TTZip\\archive.zip")
    }
    
    func testWindowsUNCPathFormatting() {
        let res = PlatformPathSanitizer.sanitize(path: "\\\\nas_server\\share\\backups\\data.tar")
        XCTAssertTrue(res.isUNCPath)
        XCTAssertTrue(res.isAbsolute)
        XCTAssertEqual(res.win32FormattedPath, "\\\\?\\UNC\\nas_server\\share\\backups\\data.tar")
    }
    
    func testLongPathPrefixGeneration() {
        let longSubdirs = String(repeating: "subfolder_level_depth/", count: 20)
        let longPath = "C:/" + longSubdirs + "deep_file.txt"
        let res = PlatformPathSanitizer.sanitize(path: longPath)
        XCTAssertTrue(res.isLongPath)
        XCTAssertTrue(res.win32FormattedPath.hasPrefix("\\\\?\\C:\\"))
    }
    
    func testZipSlipDetectionFlag() {
        let resUnsafe = PlatformPathSanitizer.sanitize(path: "safe/../../outside/secret.txt")
        XCTAssertTrue(resUnsafe.hasTraversalAttack)
        
        let resSafe = PlatformPathSanitizer.sanitize(path: "a/b/../../c")
        XCTAssertFalse(resSafe.hasTraversalAttack)
    }
    
    func testUnicodeNFCNormalization() {
        // Hangul NFD decomposed -> NFC precomposed
        let hangulNFD = "\u{1100}\u{1161}\u{11A8}.dat"
        let res = PlatformPathSanitizer.sanitize(path: hangulNFD)
        XCTAssertEqual(res.normalizedPath, "각.dat")
    }
    
    func testSecurityScannerLegitimateMultiDotPath() {
        XCTAssertTrue(SecurityScanner.isPathSafe("release..notes.txt"))
        XCTAssertTrue(SecurityScanner.isPathSafe("subfolder/file.v1..2.dat"))
        XCTAssertFalse(SecurityScanner.isPathSafe("../escape.txt"))
        XCTAssertFalse(SecurityScanner.isPathSafe("/etc/passwd"))
    }
}
