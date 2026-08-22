// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Individual test case execution record for CLI diagnostics.
public struct TestCaseRecord: Sendable, Codable {
    public let name: String
    public let className: String
    public let tier: Int
    public let durationSeconds: Double
    public let passed: Bool
    public let failureMessage: String?
    
    public init(
        name: String,
        className: String,
        tier: Int,
        durationSeconds: Double,
        passed: Bool,
        failureMessage: String? = nil
    ) {
        self.name = name
        self.className = className
        self.tier = tier
        self.durationSeconds = durationSeconds
        self.passed = passed
        self.failureMessage = failureMessage
    }
}

/// Comprehensive test execution session report model.
public struct TestSessionReport: Sendable, Codable {
    public let timestamp: TimeInterval
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let totalDurationSeconds: Double
    public let testCases: [TestCaseRecord]
    
    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        testCases: [TestCaseRecord] = []
    ) {
        self.timestamp = timestamp
        self.testCases = testCases
        self.totalTests = testCases.count
        self.passedTests = testCases.filter(\.passed).count
        self.failedTests = testCases.filter { !$0.passed }.count
        self.totalDurationSeconds = testCases.reduce(0.0) { $0 + $1.durationSeconds }
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
