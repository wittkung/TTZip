import XCTest
import Foundation
@testable import TTZipCore

final class TestReportGeneratorTests: XCTestCase {
    
    func testFastHexDiffEngineExactMatch() {
        let sample = "TTZip High Performance Core".data(using: .utf8)!
        let diff = FastHexDiffEngine.generateDiff(expected: sample, actual: sample)
        XCTAssertNil(diff, "Exact match should produce no diff")
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
