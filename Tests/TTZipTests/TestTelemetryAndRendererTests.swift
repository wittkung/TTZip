// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipCLI

final class TestTelemetryAndRendererTests: XCTestCase {
    
    // MARK: - 1. TestTelemetryEvent & TestTelemetryStream Tests
    
    func testTelemetryEventSerializationAndDeserialization() throws {
        let sessionID = "TEST-SESSION-20260817"
        let timestamp = "2026-08-17T15:30:00.000Z"
        
        let startEvent = TestTelemetryEvent.runStarted(sessionID: sessionID, timestamp: timestamp)
        XCTAssertEqual(startEvent.eventType, .testRunStarted)
        XCTAssertEqual(startEvent.sessionID, sessionID)
        XCTAssertEqual(startEvent.timestamp, timestamp)
        
        guard let json1 = TestTelemetryStream.serializeJSON(startEvent) else {
            XCTFail("Failed to serialize startEvent")
            return
        }
        
        let parsed1 = TestTelemetryStream.parseNDJSON(from: json1)
        XCTAssertNotNil(parsed1)
        XCTAssertEqual(parsed1?.eventType, .testRunStarted)
        XCTAssertEqual(parsed1?.sessionID, sessionID)
        XCTAssertEqual(parsed1?.timestamp, timestamp)
        
        // Error / Failed case test
        let error = TestTelemetryEvent.TelemetryError(
            message: "Header CRC mismatch",
            diff: "- 0x01234567\n+ 0x89ABCDEF",
            stackTrace: ["ArchiveReader.swift:42", "ZipEngine.swift:108"]
        )
        let failEvent = TestTelemetryEvent.caseFailed(
            sessionID: sessionID,
            suiteName: "Tier1_ZipTests",
            testCaseName: "testZipCRCValidation",
            durationMs: 12.45,
            error: error,
            timestamp: timestamp
        )
        
        guard let json2 = TestTelemetryStream.serializeJSON(failEvent) else {
            XCTFail("Failed to serialize failEvent")
            return
        }
        
        let parsed2 = TestTelemetryStream.parseNDJSON(from: json2)
        XCTAssertNotNil(parsed2)
        XCTAssertEqual(parsed2?.eventType, .testCaseFailed)
        XCTAssertEqual(parsed2?.suiteName, "Tier1_ZipTests")
        XCTAssertEqual(parsed2?.testCaseName, "testZipCRCValidation")
        XCTAssertEqual(parsed2?.durationMs, 12.45)
        XCTAssertEqual(parsed2?.error?.message, "Header CRC mismatch")
        XCTAssertEqual(parsed2?.error?.diff, "- 0x01234567\n+ 0x89ABCDEF")
        XCTAssertEqual(parsed2?.error?.stackTrace?.count, 2)
        
        // Metrics / RunFinished test
        let metrics = TestTelemetryEvent.TelemetryMetrics(
            totalTests: 100,
            passedTests: 98,
            failedTests: 1,
            skippedTests: 1,
            passRate: 98.0
        )
        let finishEvent = TestTelemetryEvent.runFinished(
            sessionID: sessionID,
            durationMs: 1543.2,
            metrics: metrics,
            timestamp: timestamp
        )
        
        guard let json3 = TestTelemetryStream.serializeJSON(finishEvent) else {
            XCTFail("Failed to serialize finishEvent")
            return
        }
        
        let parsed3 = TestTelemetryStream.parseNDJSON(from: json3)
        XCTAssertNotNil(parsed3)
        XCTAssertEqual(parsed3?.eventType, .testRunFinished)
        XCTAssertEqual(parsed3?.metrics?.totalTests, 100)
        XCTAssertEqual(parsed3?.metrics?.passedTests, 98)
        XCTAssertEqual(parsed3?.metrics?.failedTests, 1)
        XCTAssertEqual(parsed3?.metrics?.skippedTests, 1)
        XCTAssertEqual(parsed3?.metrics?.passRate, 98.0)
    }
    
    func testTelemetryEventAllEventTypes() {
        for type in TestTelemetryEvent.EventType.allCases {
            let event = TestTelemetryEvent(
                eventType: type,
                timestamp: TestTelemetryEvent.currentISO8601Timestamp(),
                sessionID: "SESSION-001",
                suiteName: "Suite-\(type.rawValue)",
                testCaseName: "Case-\(type.rawValue)",
                durationMs: 1.5
            )
            guard let json = TestTelemetryStream.serializeJSON(event) else {
                XCTFail("Failed to serialize \(type)")
                continue
            }
            let decoded = TestTelemetryStream.parseNDJSON(from: json)
            XCTAssertEqual(decoded?.eventType, type)
            XCTAssertEqual(decoded?.sessionID, "SESSION-001")
        }
    }
    
    // MARK: - 2. TestTerminalRenderer Tests
    
    func testBadgesFormatting() {
        for badge in TestTerminalRenderer.Badge.allCases {
            let colored = TestTerminalRenderer.badge(badge, useColor: true)
            let plain = TestTerminalRenderer.badge(badge, useColor: false)
            
            XCTAssertTrue(plain.contains(badge.rawValue))
            XCTAssertEqual(plain, "[\(badge.rawValue)]")
            XCTAssertTrue(colored.contains(badge.rawValue))
            XCTAssertTrue(colored.contains("\u{001B}["))
        }
        
        XCTAssertEqual(TestTerminalRenderer.passBadge(useColor: false), "[PASS]")
        XCTAssertEqual(TestTerminalRenderer.failBadge(useColor: false), "[FAIL]")
        XCTAssertEqual(TestTerminalRenderer.skipBadge(useColor: false), "[SKIP]")
        XCTAssertEqual(TestTerminalRenderer.standardsBadge(useColor: false), "[STANDARDS]")
        XCTAssertEqual(TestTerminalRenderer.oracleBadge(useColor: false), "[ORACLE]")
        XCTAssertEqual(TestTerminalRenderer.fuzzBadge(useColor: false), "[FUZZ]")
    }
    
    func testDurationAndThroughputFormatting() {
        XCTAssertEqual(TestTerminalRenderer.formatDuration(ms: 0.0001), "< 1 µs")
        XCTAssertTrue(TestTerminalRenderer.formatDuration(ms: 0.5).contains("µs"))
        XCTAssertEqual(TestTerminalRenderer.formatDuration(ms: 12.34), "12.34 ms")
        XCTAssertEqual(TestTerminalRenderer.formatDuration(ms: 2500.0), "2.500 s")
        
        XCTAssertEqual(TestTerminalRenderer.formatThroughput(mbs: 500.0), "500.0 MB/s")
        XCTAssertEqual(TestTerminalRenderer.formatThroughput(mbs: 2048.0), "2.00 GB/s")
        
        let timingStr = TestTerminalRenderer.renderTimingMetrics(
            label: "ZIP Level 1 Compression",
            durationMs: 12.5,
            throughputMBs: 8500.0,
            useColor: false
        )
        XCTAssertTrue(timingStr.contains("ZIP Level 1 Compression"))
        XCTAssertTrue(timingStr.contains("12.50 ms"))
        XCTAssertTrue(timingStr.contains("8.30 GB/s"))
    }
    
    func testHeaderAndTablesRendering() {
        let header = TestTerminalRenderer.renderHeader(
            sessionID: "SES-123",
            tier: "0,1,2",
            filter: "zip",
            useColor: false
        )
        XCTAssertTrue(header.contains("SES-123"))
        XCTAssertTrue(header.contains("Tier Filter: \"0,1,2\""))
        XCTAssertTrue(header.contains("Pattern Filter: \"zip\""))
        
        let suites = [
            TestTerminalRenderer.SuiteSummary(suiteName: "Tier1_ZipStandards", category: "RFC 1951", passed: 10, failed: 0, skipped: 0, durationMs: 45.2),
            TestTerminalRenderer.SuiteSummary(suiteName: "Tier2_OracleTar", category: "POSIX Pax", passed: 8, failed: 1, skipped: 1, durationMs: 120.0)
        ]
        let suiteTable = TestTerminalRenderer.renderSuiteTable(suites: suites, useColor: false)
        XCTAssertTrue(suiteTable.contains("Tier1_ZipStandards"))
        XCTAssertTrue(suiteTable.contains("Tier2_OracleTar"))
        XCTAssertTrue(suiteTable.contains("POSIX Pax"))
        
        let metrics = TestTelemetryEvent.TelemetryMetrics(
            totalTests: 20,
            passedTests: 18,
            failedTests: 1,
            skippedTests: 1,
            passRate: 90.0
        )
        let summary = TestTerminalRenderer.renderSummaryTable(
            metrics: metrics,
            durationMs: 165.2,
            sessionID: "SES-123",
            osVersion: "macOS 14.5",
            arch: "arm64",
            useColor: false
        )
        XCTAssertTrue(summary.contains("TEST FAILURES DETECTED"))
        XCTAssertTrue(summary.contains("Total: 20"))
        XCTAssertTrue(summary.contains("Passed: 18"))
        XCTAssertTrue(summary.contains("Failed: 1"))
        XCTAssertTrue(summary.contains("Pass Rate: 90.0%"))
        XCTAssertTrue(summary.contains("macOS 14.5 (arm64)"))
    }
    
    func testHexDiffRendering() {
        var expected = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
        var actual = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
        
        let matchOutput = TestTerminalRenderer.renderHexDiff(expected: expected, actual: actual, useColor: false)
        XCTAssertTrue(matchOutput.contains("[Hex Match]"))
        
        // Introduce mismatch
        actual[4] = 0xFF
        let diffOutput = TestTerminalRenderer.renderHexDiff(expected: expected, actual: actual, useColor: false)
        XCTAssertTrue(diffOutput.contains("Binary Mismatch") || diffOutput.contains("difference at offset"))
        
        let snippet = TestTerminalRenderer.renderHexDiffSnippet("Expected: 0x504B\nActual:   0x50FF", useColor: false)
        XCTAssertTrue(snippet.contains("[Hex Difference Diagnostic]"))
        XCTAssertTrue(snippet.contains("Expected: 0x504B"))
    }
}
