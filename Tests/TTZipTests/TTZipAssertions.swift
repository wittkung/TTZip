// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// libarchive test_common.h POSIX、
public enum TTZipAssertions {
    
    /// Compares two Data instances.
    public static func assertDataEqual(
        _ actual: Data,
        _ expected: Data,
        message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, message ?? "Data mismatch", file: file, line: line)
    }
    
    /// Compares two String instances.
    public static func assertStringEqual(
        _ actual: String,
        _ expected: String,
        message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, message ?? "String mismatch", file: file, line: line)
    }
    
    /// Validates expected behavior and invariants.
    public static func assertFileContents(
        _ url: URL,
        expectedData: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actualData = try? Data(contentsOf: url) else {
            XCTFail("Assertion Failed: Unable to read file at \(url.path)", file: file, line: line)
            return
        }
        assertDataEqual(actualData, expectedData, message: "File: \(url.lastPathComponent)", file: file, line: line)
    }
    
    /// POSIX (mode_t)
    public static func assertFileMode(
        _ url: URL,
        expectedMode: mode_t,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        let actualMode = st.st_mode & 0o777
        XCTAssertEqual(actualMode, expectedMode & 0o777, "Assertion Failed: Expected mode \(String(expectedMode, radix: 8)) but got \(String(actualMode, radix: 8)) for \(url.path)", file: file, line: line)
    }
    
    /// Validates expected behavior and invariants.
    public static func assertIsReg(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertTrue((st.st_mode & S_IFMT) == S_IFREG, "Assertion Failed: \(url.path) is not a regular file", file: file, line: line)
    }
    
    /// Validates expected behavior and invariants.
    public static func assertIsDir(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertTrue((st.st_mode & S_IFMT) == S_IFDIR, "Assertion Failed: \(url.path) is not a directory", file: file, line: line)
    }
    
    /// inode (Hardlink)
    public static func assertIsHardlink(
        _ urlA: URL,
        _ urlB: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var stA = stat()
        var stB = stat()
        guard stat(urlA.path, &stA) == 0, stat(urlB.path, &stB) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(urlA.path) or \(urlB.path)", file: file, line: line)
            return
        }
        XCTAssertEqual(stA.st_ino, stB.st_ino, "Assertion Failed: Inode mismatch between \(urlA.path) and \(urlB.path)", file: file, line: line)
        XCTAssertEqual(stA.st_dev, stB.st_dev, "Assertion Failed: Device mismatch between \(urlA.path) and \(urlB.path)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(stA.st_nlink, 2, "Assertion Failed: Hardlink count for \(urlA.path) should be >= 2", file: file, line: line)
    }
    
    /// (0 )
    public static func assertEmptyFile(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertEqual(st.st_size, 0, "Assertion Failed: Expected empty file at \(url.path), but size is \(st.st_size)", file: file, line: line)
    }
}

public enum TestBenchmarkTier {
    public static var isBenchmarkMode: Bool {
        ProcessInfo.processInfo.environment["TTZIP_BENCHMARK"] != nil
    }
    
    public static func fuzzIterations(default def: Int, deep: Int) -> Int {
        if ProcessInfo.processInfo.environment["TTZIP_DEEP_FUZZ"] != nil {
            return deep
        }
        return def
    }
}

