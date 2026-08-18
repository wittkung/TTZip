// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Darwin

/// Log level defining output verbosity during test execution
public enum TestLogLevel: Int, Comparable, Sendable, CaseIterable {
    case silent = 0
    case normal = 1
    case verbose = 2
    case debug = 3
    
    public static func < (lhs: TestLogLevel, rhs: TestLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Terminal capabilities detector adhering to POSIX standards and https://no-color.org
public enum TerminalCapabilities: Sendable {
    
    /// Returns true if stdout is a valid interactive TTY and color is permitted
    public static var supportsColor: Bool {
        // 1. Check NO_COLOR environment variable
        if getenv("NO_COLOR") != nil {
            return false
        }
        // 2. Check TERM variable
        if let term = getenv("TERM"), String(cString: term) == "dumb" {
            return false
        }
        // 3. Check isatty
        return isatty(fileno(stdout)) != 0
    }
    
    /// Fast zero-regex state machine to strip ANSI escape sequences
    public static func stripANSI(from string: String) -> String {
        var result = ""
        result.reserveCapacity(string.utf8.count)
        
        var isEscaping = false
        for char in string {
            if char == "\u{001B}" {
                isEscaping = true
                continue
            }
            if isEscaping {
                if char == "m" || char.isLetter {
                    isEscaping = false
                }
                continue
            }
            result.append(char)
        }
        return result
    }
}

/// Thread-safe in-process task log session buffer for zero-cost test diagnostics
public final class TestLogSession: @unchecked Sendable {
    public let sessionID: String
    public let testName: String
    private var buffer: [String] = []
    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    
    public init(sessionID: String = UUID().uuidString, testName: String) {
        self.sessionID = sessionID
        self.testName = testName
        self.lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        lock.deallocate()
    }
    
    public func append(_ message: String) {
        os_unfair_lock_lock(lock)
        buffer.append(message)
        os_unfair_lock_unlock(lock)
    }
    
    public func snapshot() -> [String] {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return buffer
    }
    
    public func clear() {
        os_unfair_lock_lock(lock)
        buffer.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(lock)
    }
}

/// Centralized test logging subsystem for TTZip
public enum TestLogger: Sendable {
    
    @TaskLocal
    public static var currentSession: TestLogSession?
    
    private static let globalLevelLock = NSLock()
    nonisolated(unsafe) private static var _globalLogLevel: TestLogLevel = .normal
    
    public static var logLevel: TestLogLevel {
        get {
            globalLevelLock.lock()
            defer { globalLevelLock.unlock() }
            return _globalLogLevel
        }
        set {
            globalLevelLock.lock()
            _globalLogLevel = newValue
            globalLevelLock.unlock()
        }
    }
    
    /// Log informative message during test execution
    public static func info(_ message: @autoclosure () -> String) {
        log(level: .normal, message: message())
    }
    
    /// Log verbose detail message
    public static func verbose(_ message: @autoclosure () -> String) {
        log(level: .verbose, message: message())
    }
    
    /// Log low-level debug trace
    public static func debug(_ message: @autoclosure () -> String) {
        log(level: .debug, message: message())
    }
    
    /// Route message to TaskLocal buffer or direct output based on log level
    public static func log(level: TestLogLevel, message: String) {
        guard level <= logLevel else { return }
        
        if let session = currentSession {
            session.append(message)
        } else if logLevel >= .verbose {
            atomicPrint(message)
        }
    }
    
    /// Execute an async test body with TaskLocal session isolation
    public static func withSession<T>(
        testName: String,
        body: () async throws -> T
    ) async rethrows -> T {
        let session = TestLogSession(testName: testName)
        return try await $currentSession.withValue(session) {
            try await body()
        }
    }
    
    /// Execute a sync test body with TaskLocal session isolation
    public static func withSessionSync<T>(
        testName: String,
        body: () throws -> T
    ) rethrows -> T {
        let session = TestLogSession(testName: testName)
        return try $currentSession.withValue(session) {
            try body()
        }
    }
    
    /// Dump captured session logs atomically on test failure
    public static func flushOnFailure(
        file: String = #file,
        line: Int = #line,
        reason: String? = nil,
        useColor: Bool = TerminalCapabilities.supportsColor
    ) {
        guard let session = currentSession else { return }
        let logs = session.snapshot()
        guard !logs.isEmpty || reason != nil else { return }
        
        var card = ""
        let sep = "──────────────────────────────────────────────────────────────────────────────────"
        if useColor {
            card += "\n\(TestTerminalRenderer.ANSI.boldRed)┌── [FAILURE DIAGNOSTIC] \(session.testName) \(sep)\(TestTerminalRenderer.ANSI.reset)\n"
            card += "  📍 Location: \(file):\(line)\n"
            if let r = reason {
                card += "  🚨 Reason:   \(TestTerminalRenderer.ANSI.boldRed)\(r)\(TestTerminalRenderer.ANSI.reset)\n"
            }
            if !logs.isEmpty {
                card += "  📋 Trace Logs:\n"
                for entry in logs {
                    card += "     │ \(entry)\n"
                }
            }
            card += "\(TestTerminalRenderer.ANSI.boldRed)└──\(sep)\(TestTerminalRenderer.ANSI.reset)\n"
        } else {
            card += "\n+-- [FAILURE DIAGNOSTIC] \(session.testName) \(sep)\n"
            card += "  Location: \(file):\(line)\n"
            if let r = reason {
                card += "  Reason:   \(r)\n"
            }
            if !logs.isEmpty {
                card += "  Trace Logs:\n"
                for entry in logs {
                    card += "     | \(entry)\n"
                }
            }
            card += "+--\(sep)\n"
        }
        
        atomicPrint(card)
    }
    
    /// Thread-safe POSIX atomic print using flockfile(stdout)
    public static func atomicPrint(_ string: String) {
        let text = string.hasSuffix("\n") ? string : string + "\n"
        text.withCString { cstr in
            flockfile(stdout)
            fputs(cstr, stdout)
            fflush(stdout)
            funlockfile(stdout)
        }
    }
}
