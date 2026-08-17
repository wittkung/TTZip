import XCTest
@testable import TTZipCore

final class TestTierClassificationTests: XCTestCase {
    
    // MARK: - 1. 测试分层定义与排序测试
    
    func testTestTierEnumAndOrdering() {
        XCTAssertEqual(TestTier.allCases.count, 6)
        XCTAssertEqual(TestTier.tier0.rawValue, 0)
        XCTAssertEqual(TestTier.tier5.rawValue, 5)
        
        XCTAssertTrue(TestTier.tier0 < TestTier.tier1)
        XCTAssertTrue(TestTier.tier1 < TestTier.tier2)
        XCTAssertTrue(TestTier.tier2 < TestTier.tier3)
        XCTAssertTrue(TestTier.tier3 < TestTier.tier4)
        XCTAssertTrue(TestTier.tier4 < TestTier.tier5)
        
        for tier in TestTier.allCases {
            XCTAssertFalse(tier.name.isEmpty)
            XCTAssertFalse(tier.description.isEmpty)
        }
    }
    
    // MARK: - 2. 测试报告模型与 JSON 序列化测试
    
    func testTestSessionReportJSONSerialization() {
        let cases = [
            TestCaseRecord(name: "testA", className: "SuiteA", tier: 0, durationSeconds: 0.001, passed: true),
            TestCaseRecord(name: "testB", className: "SuiteB", tier: 1, durationSeconds: 0.025, passed: false, failureMessage: "Expected 100 but got 99")
        ]
        
        let report = TestSessionReport(testCases: cases)
        XCTAssertEqual(report.totalTests, 2)
        XCTAssertEqual(report.passedTests, 1)
        XCTAssertEqual(report.failedTests, 1)
        XCTAssertEqual(report.totalDurationSeconds, 0.026, accuracy: 0.0001)
        
        let json = report.toJSON()
        XCTAssertTrue(json.contains("\"totalTests\" : 2"))
        XCTAssertTrue(json.contains("\"failedTests\" : 1"))
        XCTAssertTrue(json.contains("\"testB\""))
    }
    
    // MARK: - 3. JUnit XML 报告构建与转义测试
    
    func testJUnitXMLReportBuilder() {
        let cases = [
            TestCaseRecord(name: "testFastSIMD", className: "CryptoTests", tier: 0, durationSeconds: 0.002, passed: true),
            TestCaseRecord(name: "testCorruptedData<Block>", className: "SecurityTests", tier: 4, durationSeconds: 0.015, passed: false, failureMessage: "Corrupt magic: & < > \" '")
        ]
        
        let report = TestSessionReport(testCases: cases)
        let xml = JUnitReportBuilder.buildXML(from: report)
        
        XCTAssertTrue(xml.starts(with: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<testsuites name=\"TTZipTests\" tests=\"2\" failures=\"1\""))
        XCTAssertTrue(xml.contains("<testsuite name=\"CryptoTests\""))
        XCTAssertTrue(xml.contains("<testsuite name=\"SecurityTests\""))
        XCTAssertTrue(xml.contains("&amp; &lt; &gt; &quot; &apos;"), "Must escape XML special characters")
    }
}
