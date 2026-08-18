// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// XCTest ： 、 Dump
public final class TTZipTestObserver: NSObject, XCTestObservation, @unchecked Sendable {
    
    public static let shared = TTZipTestObserver()
    nonisolated(unsafe) private static var isRegistered = false
    private static let lock = NSLock()
    
    nonisolated(unsafe) private var currentTestHasFailed: Bool = false
    
    /// XCTest
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
        
        // ，
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
            // Verify expected invariant
            TTLogger.dumpCapturedLogsOnFailure(testName: testCase.name)
        } else {
            // Verify expected invariant
            TTLogger.clearTestCapture()
        }
    }
}
