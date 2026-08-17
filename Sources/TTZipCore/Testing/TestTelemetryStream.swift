// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
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
    
    // MARK: - Factory Methods
    
    public static func currentISO8601Timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    public static func runStarted(
        sessionID: String,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testRunStarted,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID
        )
    }
    
    public static func suiteStarted(
        sessionID: String,
        suiteName: String,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .suiteStarted,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName
        )
    }
    
    public static func caseStarted(
        sessionID: String,
        suiteName: String,
        testCaseName: String,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testCaseStarted,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName,
            testCaseName: testCaseName
        )
    }
    
    public static func casePassed(
        sessionID: String,
        suiteName: String,
        testCaseName: String,
        durationMs: Double,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testCasePassed,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName,
            testCaseName: testCaseName,
            durationMs: durationMs
        )
    }
    
    public static func caseFailed(
        sessionID: String,
        suiteName: String,
        testCaseName: String,
        durationMs: Double,
        error: TelemetryError,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testCaseFailed,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName,
            testCaseName: testCaseName,
            durationMs: durationMs,
            error: error
        )
    }
    
    public static func caseSkipped(
        sessionID: String,
        suiteName: String,
        testCaseName: String,
        reason: String? = nil,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testCaseSkipped,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName,
            testCaseName: testCaseName,
            error: reason != nil ? TelemetryError(message: reason!) : nil
        )
    }
    
    public static func suiteFinished(
        sessionID: String,
        suiteName: String,
        durationMs: Double,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .suiteFinished,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            suiteName: suiteName,
            durationMs: durationMs
        )
    }
    
    public static func runFinished(
        sessionID: String,
        durationMs: Double,
        metrics: TelemetryMetrics,
        timestamp: String? = nil
    ) -> TestTelemetryEvent {
        TestTelemetryEvent(
            eventType: .testRunFinished,
            timestamp: timestamp ?? currentISO8601Timestamp(),
            sessionID: sessionID,
            durationMs: durationMs,
            metrics: metrics
        )
    }
}

/// Standardized NDJSON Stream Emitter for test telemetry
public enum TestTelemetryStream: Sendable {
    
    private static let lock = NSLock()
    
    /// Serialize a telemetry event to a single-line JSON string
    public static func serializeJSON(_ event: TestTelemetryEvent) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(event),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Parse a telemetry event from a single NDJSON line
    public static func parseNDJSON(from line: String) -> TestTelemetryEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(TestTelemetryEvent.self, from: data)
    }
    
    /// Emit a telemetry event as NDJSON to stdout
    public static func emitNDJSON(_ event: TestTelemetryEvent) {
        emitNDJSON(event, to: .standardOutput)
    }
    
    /// Emit a telemetry event as NDJSON to a specified FileHandle
    public static func emitNDJSON(_ event: TestTelemetryEvent, to handle: FileHandle) {
        guard let jsonString = serializeJSON(event) else { return }
        lock.lock()
        defer { lock.unlock() }
        
        let line = jsonString + "\n"
        if let lineData = line.data(using: .utf8) {
            handle.write(lineData)
        }
    }
}
