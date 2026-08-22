// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Structured NDJSON telemetry event emitted during test execution
public struct TestTelemetryEvent: Sendable, Codable, Equatable {
    
    public enum EventType: String, Sendable, Codable, Equatable, CaseIterable {
        case testRunStarted
        case suiteStarted
        case testCaseStarted
        case testCasePassed
        case testCaseFailed
        case testCaseSkipped
        case suiteFinished
        case testRunFinished
    }
    
    public struct TelemetryError: Sendable, Codable, Equatable {
        public let message: String
        public let diff: String?
        public let stackTrace: [String]?
        
        public init(
            message: String,
            diff: String? = nil,
            stackTrace: [String]? = nil
        ) {
            self.message = message
            self.diff = diff
            self.stackTrace = stackTrace
        }
    }
    
    public struct TelemetryMetrics: Sendable, Codable, Equatable {
        public let totalTests: Int
        public let passedTests: Int
        public let failedTests: Int
        public let skippedTests: Int
        public let passRate: Double
        
        public init(
            totalTests: Int,
            passedTests: Int,
            failedTests: Int,
            skippedTests: Int,
            passRate: Double
        ) {
            self.totalTests = totalTests
            self.passedTests = passedTests
            self.failedTests = failedTests
            self.skippedTests = skippedTests
            self.passRate = passRate
        }
    }
    
    public let eventType: EventType
    public let timestamp: String
    public let sessionID: String
    public let suiteName: String?
    public let testCaseName: String?
    public let durationMs: Double?
    public let error: TelemetryError?
    public let metrics: TelemetryMetrics?
    
    public init(
        eventType: EventType,
        timestamp: String,
        sessionID: String,
        suiteName: String? = nil,
        testCaseName: String? = nil,
        durationMs: Double? = nil,
        error: TelemetryError? = nil,
        metrics: TelemetryMetrics? = nil
    ) {
        self.eventType = eventType
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.suiteName = suiteName
        self.testCaseName = testCaseName
        self.durationMs = durationMs
        self.error = error
        self.metrics = metrics
    }
    
    public static func currentISO8601Timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    public static func runStarted(
        sessionID: String,
        timestamp: String = currentISO8601Timestamp()
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testRunStarted,
            timestamp: timestamp,
            sessionID: sessionID
        )
    }
    
    public static func runFinished(
        sessionID: String,
        durationMs: Double,
        metrics: TelemetryMetrics,
        timestamp: String = currentISO8601Timestamp()
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testRunFinished,
            timestamp: timestamp,
            sessionID: sessionID,
            durationMs: durationMs,
            metrics: metrics
        )
    }
}

/// High-throughput streaming NDJSON telemetry emitter for CI/CD integrations.
public final class TestTelemetryStream: @unchecked Sendable {
    public static let shared = TestTelemetryStream()
    private let queue = DispatchQueue(label: "com.ttzip.cli.telemetry", qos: .utility)
    
    private init() {}
    
    public static func emitNDJSON(_ event: TestTelemetryEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(event), let json = String(data: data, encoding: .utf8) {
            print(json)
            fflush(stdout)
        }
    }
}
