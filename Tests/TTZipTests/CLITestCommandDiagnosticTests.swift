// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class CLITestCommandDiagnosticTests: XCTestCase {
    
    // MARK: - 1. Telemetry Contract Tests
    
    func testTelemetryContractValidation() throws {
        let sessionID = "TEST-SESSION-DIAGNOSTIC-001"
        let timestamp = "2026-08-17T15:30:00.000Z"
        
        let event = TestTelemetryEvent(
            eventType: .testCasePassed,
            timestamp: timestamp,
            sessionID: sessionID,
            suiteName: "DiagnosticSuite",
            testCaseName: "testDiagnosticThroughput",
            durationMs: 4.2
        )
        
        guard let jsonString = TestTelemetryStream.serializeJSON(event) else {
            XCTFail("Failed to serialize TestTelemetryEvent")
            return
        }
        
        // Verify JSON fields
        let data = jsonString.data(using: .utf8)!
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["eventType"] as? String, "testCasePassed")
        XCTAssertEqual(jsonObject?["timestamp"] as? String, timestamp)
        XCTAssertEqual(jsonObject?["sessionID"] as? String, sessionID)
        XCTAssertEqual(jsonObject?["suiteName"] as? String, "DiagnosticSuite")
        XCTAssertEqual(jsonObject?["testCaseName"] as? String, "testDiagnosticThroughput")
        XCTAssertEqual(jsonObject?["durationMs"] as? Double, 4.2)
    }
    
    func testTelemetryErrorPayloadSerialization() throws {
        let error = TestTelemetryEvent.TelemetryError(
            message: "Checksum verification failed at block 4",
            diff: "Expected 0xAA, got 0xBB",
            stackTrace: ["ZipBlockEngine.swift:55", "FastLZMA2.c:120"]
        )
        
        let failEvent = TestTelemetryEvent.caseFailed(
            sessionID: "SESSION-ERR-01",
            suiteName: "Tier1_ErrorSuite",
            testCaseName: "testCorruptionRecovery",
            durationMs: 15.0,
            error: error
        )
        
        guard let jsonString = TestTelemetryStream.serializeJSON(failEvent) else {
            XCTFail("Failed to serialize error event")
            return
        }
        
        let parsed = TestTelemetryStream.parseNDJSON(from: jsonString)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.eventType, .testCaseFailed)
        XCTAssertEqual(parsed?.error?.message, "Checksum verification failed at block 4")
        XCTAssertEqual(parsed?.error?.diff, "Expected 0xAA, got 0xBB")
        XCTAssertEqual(parsed?.error?.stackTrace?.count, 2)
    }
    
    // MARK: - 2. Terminal Renderer Output Tests
    
    func testTerminalBadgesRendering() {
        let pass = TestTerminalRenderer.passBadge(useColor: false)
        let fail = TestTerminalRenderer.failBadge(useColor: false)
        let skip = TestTerminalRenderer.skipBadge(useColor: false)
        let std = TestTerminalRenderer.standardsBadge(useColor: false)
        let oracle = TestTerminalRenderer.oracleBadge(useColor: false)
        let fuzz = TestTerminalRenderer.fuzzBadge(useColor: false)
        
        XCTAssertEqual(pass, "[PASS]")
        XCTAssertEqual(fail, "[FAIL]")
        XCTAssertEqual(skip, "[SKIP]")
        XCTAssertEqual(std, "[STANDARDS]")
        XCTAssertEqual(oracle, "[ORACLE]")
        XCTAssertEqual(fuzz, "[FUZZ]")
    }
    
    func testTestCaseRowFormatting() {
        let row = TestTerminalRenderer.renderTestCaseRow(
            index: 1,
            badge: .pass,
            name: "testZip64LargeFileExtraction",
            target: "ZIP",
            durationMs: 25.4,
            useColor: false
        )
        
        XCTAssertTrue(row.contains("1."))
        XCTAssertTrue(row.contains("[PASS]"))
        XCTAssertTrue(row.contains("ZIP"))
        XCTAssertTrue(row.contains("testZip64LargeFileExtraction"))
        XCTAssertTrue(row.contains("25.40 ms"))
    }
    
    func testHexDiffFormattingDiagnostics() {
        let exp = Data([0xFD, 0x2F, 0xB5, 0x28, 0x00, 0x00])
        var act = Data([0xFD, 0x2F, 0xB5, 0x28, 0x00, 0x00])
        
        let match = TestTerminalRenderer.renderHexDiff(expected: exp, actual: act, useColor: false)
        XCTAssertTrue(match.contains("[Hex Match]"))
        
        act[3] = 0x29
        let diff = TestTerminalRenderer.renderHexDiff(expected: exp, actual: act, useColor: false)
        XCTAssertTrue(diff.contains("Binary Mismatch") || diff.contains("difference at offset"))
    }
}
