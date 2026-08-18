// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class TestReportGeneratorTests: XCTestCase {
    
    func testFastHexDiffEngineExactMatch() {
        let sample = "TTZip High Performance Core".data(using: .utf8)!
        let diff = FastHexDiffEngine.generateDiff(expected: sample, actual: sample)
        XCTAssertNil(diff, "Exact match should produce no diff")
        
        let empty = Data()
        let emptyDiff = FastHexDiffEngine.generateDiff(expected: empty, actual: empty)
        XCTAssertNil(emptyDiff, "Empty match should produce no diff")
    }
    
    func testFastHexDiffEngineMismatch() {
        let dataA = Data(repeating: 0xAA, count: 128)
        var dataB = Data(repeating: 0xAA, count: 128)

        dataB[42] = 0xBB
        
        let diff = FastHexDiffEngine.generateDiff(expected: dataA, actual: dataB, maxWindow: 128, useAnsi: false)
        XCTAssertNotNil(diff, "Mismatch should produce diff output")
        XCTAssertTrue(diff!.contains("0x0000002A"), "Diff should pinpoint offset 0x2A (42)")
        XCTAssertTrue(diff!.contains("_BB_") || diff!.contains("BB"), "Diff should show mismatched byte")
    }
    
    func testFastHexDiffEngineSimdChunkHoppingLargeBuffer() {
        // Test 64-byte SIMD chunk hopping beyond 256 bytes
        let dataA = Data(repeating: 0x11, count: 1024)
        var dataB = Data(repeating: 0x11, count: 1024)
        
        // Inject difference at offset 350 (which is inside the 5th 64-byte chunk: 320..<384)
        dataB[350] = 0x99
        
        let diff = FastHexDiffEngine.generateDiff(expected: dataA, actual: dataB, maxWindow: 256, useAnsi: true)
        XCTAssertNotNil(diff)
        XCTAssertTrue(diff!.contains("0x0000015E"), "Offset 350 in hex is 0x0000015E")
        XCTAssertTrue(diff!.contains("\u{001B}[1;31m"), "Should contain ANSI bold red color code")
    }
    
    func testFastHexDiffEngineLengthMismatchAndEmpty() {
        let dataA = Data([0x01, 0x02, 0x03, 0x04])
        let dataB = Data([0x01, 0x02])
        
        let diffShort = FastHexDiffEngine.generateDiff(expected: dataA, actual: dataB, useAnsi: false)
        XCTAssertNotNil(diffShort)
        XCTAssertTrue(diffShort!.contains("Expected length: 4 bytes | Actual length: 2 bytes"))
        XCTAssertTrue(diffShort!.contains("0x00000002"))
        
        let empty = Data()
        let diffEmpty = FastHexDiffEngine.generateDiff(expected: empty, actual: dataA, useAnsi: false)
        XCTAssertNotNil(diffEmpty)
        XCTAssertTrue(diffEmpty!.contains("Expected length: 0 bytes | Actual length: 4 bytes"))
    }
    
    func testFastHexDiffEngineRawBufferPointer() {
        let bytesA: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]
        let bytesB: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x20, 0x00]
        
        bytesA.withUnsafeBytes { pExp in
            bytesB.withUnsafeBytes { pAct in
                let diff = FastHexDiffEngine.generateDiff(expected: pExp, actual: pAct, useAnsi: true)
                XCTAssertNotNil(diff)
                XCTAssertTrue(diff!.contains("0x00000004"), "Mismatch at offset 4")
            }
        }
    }
    
    func testUnicodeDiagnosticFormatterScalars() {
        let str = "TTZip 🚀"
        let dumped = UnicodeDiagnosticFormatter.dumpScalars(str)
        XCTAssertTrue(dumped.contains("0054"), "Should contain ASCII 'T' (0x54)")
        XCTAssertTrue(dumped.contains("01F680") || dumped.contains("1F680"), "Should contain rocket emoji scalar U+1F680")
    }
    
    func testUnicodeDiagnosticFormatterAPFSNormalization() {
        // NFD vs NFC
        let nfd = "e\u{0301}" // 2 scalars: e + combining acute
        let nfc = "\u{00E9}"  // 1 scalar: é
        
        let report = UnicodeDiagnosticFormatter.analyzeStringMismatch(expected: nfd, actual: nfc)
        XCTAssertTrue(report.contains("Root Cause Identified"), "Should diagnose NFD/NFC normalization difference")
        XCTAssertTrue(report.contains("NFD"), "Should identify NFD form")
    }
    
    func testDiagnosticContextDeferredMessage() {
        DiagnosticContext.failure("Testing LFH Header at offset 0x30")
        let pending = DiagnosticContext.consumePendingMessage()
        XCTAssertEqual(pending, "Testing LFH Header at offset 0x30")
        
        let second = DiagnosticContext.consumePendingMessage()
        XCTAssertNil(second, "Pending message should be cleared once consumed")
    }
    
    func testTestLogCollectorLifecycle() {
        let collector = TestLogCollector.shared
        let session = "TEST-UNIT-01"
        
        collector.record(sessionID: session, message: "Step 1: Init")
        collector.record(sessionID: session, message: "Step 2: Processing")
        
        let logs = collector.getCapturedLogs(sessionID: session)
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0], "Step 1: Init")
        
        collector.clear(sessionID: session)
        let cleared = collector.getCapturedLogs(sessionID: session)
        XCTAssertEqual(cleared.count, 0)
    }
}
