import XCTest
import Foundation
@testable import TTZipCore

/// 大厂级 XCTest 全局监听器：实现单测日志全自动抓取、无噪音静默与失败精准 Dump
public final class TTZipTestObserver: NSObject, XCTestObservation, @unchecked Sendable {
    
    public static let shared = TTZipTestObserver()
    nonisolated(unsafe) private static var isRegistered = false
    private static let lock = NSLock()
    
    nonisolated(unsafe) private var currentTestHasFailed: Bool = false
    
    /// 自动注册全局 XCTest 监听器
    public static func registerObserverIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRegistered else { return }
        XCTestObservationCenter.shared.addTestObserver(shared)
        isRegistered = true
    }
    
    // MARK: - XCTestObservation Lifecycle
    
    public func testCaseWillStart(_ testCase: XCTestCase) {
        Self.lock.lock()
        currentTestHasFailed = false
        Self.lock.unlock()
        
        // 每一个测试用例开始前，清空并开启日志抓取
        TTLogger.startTestCapture()
    }
    
    public func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        Self.lock.lock()
        currentTestHasFailed = true
        Self.lock.unlock()
    }
    
    public func testCaseDidFinish(_ testCase: XCTestCase) {
        Self.lock.lock()
        let hasFailed = currentTestHasFailed || ((testCase.testRun?.totalFailureCount ?? 0) > 0)
        Self.lock.unlock()
        
        if hasFailed {
            // 仅在单测断言失败时打出上下文日志
            TTLogger.dumpCapturedLogsOnFailure(testName: testCase.name)
        } else {
            // 成功则静默清除
            TTLogger.clearTestCapture()
        }
    }
}
