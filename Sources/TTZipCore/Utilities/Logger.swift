// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Unified console, system diagnostics, and in-memory test log buffering service (`TTLogger`).
public final class TTLogger: @unchecked Sendable {
    public enum Level: Int, Comparable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case quiet = 4

        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public struct LogEntry: Sendable {
        public let timestamp: Date
        public let level: Level
        public let message: String
        public let file: String
        public let line: UInt
    }

    public static let shared = TTLogger()

    private let lock = NSLock()
    private var _level: Level
    private var isCapturingForTest: Bool = false
    private var logBuffer: [LogEntry] = []
    private let maxBufferSize: Int = 2000

    public var level: Level {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _level
        }
        set {
            lock.lock()
            _level = newValue
            lock.unlock()
        }
    }

    private init() {
        let env = ProcessInfo.processInfo.environment
        if let envLevelStr = env["TTZIP_LOG_LEVEL"]?.lowercased() {
            switch envLevelStr {
            case "debug": self._level = .debug
            case "info": self._level = .info
            case "warning", "warn": self._level = .warning
            case "error": self._level = .error
            case "quiet", "off": self._level = .quiet
            default: self._level = .info
            }
        } else if env["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            self._level = .quiet
            self.isCapturingForTest = true
        } else {
            self._level = .info
        }
        
        ttzip_set_log_callback { level, msg in
            guard let msg = msg else { return }
            let str = String(cString: msg)
            let lvl: TTLogger.Level
            switch level {
            case 0: lvl = .debug
            case 1: lvl = .info
            case 2: lvl = .warning
            default: lvl = .error
            }
            TTLogger.shared.log(level: lvl, message: str, file: "CBridge", line: 0)
        }
    }

    // MARK: - Core Logging

    public func log(level: Level, message: String, file: String = #file, line: UInt = #line) {
        lock.lock()
        defer { lock.unlock() }
        
        let entry = LogEntry(timestamp: Date(), level: level, message: message, file: (file as NSString).lastPathComponent, line: line)
        
        if isCapturingForTest {
            if logBuffer.count >= maxBufferSize {
                logBuffer.removeFirst(100)
            }
            logBuffer.append(entry)
        }
        
        if level >= _level && _level != .quiet {
            let formatted = "[\(entry.file):\(entry.line)] \(message)"
            print(formatted)
            fflush(stdout)
        }
    }

    // MARK: - Test Log Capture & Fail-Dump API

    public static func startTestCapture() {
        let instance = shared
        instance.lock.lock()
        defer { instance.lock.unlock() }
        instance.isCapturingForTest = true
        instance.logBuffer.removeAll(keepingCapacity: true)
    }

    public static func clearTestCapture() {
        let instance = shared
        instance.lock.lock()
        defer { instance.lock.unlock() }
        instance.logBuffer.removeAll(keepingCapacity: true)
    }

    public static func dumpCapturedLogsOnFailure(testName: String = "Test") {
        let instance = shared
        instance.lock.lock()
        defer { instance.lock.unlock() }
        
        guard !instance.logBuffer.isEmpty else { return }
        print("\n==========================================================================================")
        print("🚨 [TTLogger Log Dump on Failure] Test '\(testName)' execution trace (\(instance.logBuffer.count) entries)")
        print("==========================================================================================")
        for entry in instance.logBuffer {
            let lvlStr: String
            switch entry.level {
            case .debug: lvlStr = "DEBUG"
            case .info: lvlStr = "INFO"
            case .warning: lvlStr = "WARN"
            case .error: lvlStr = "ERROR"
            case .quiet: lvlStr = "QUIET"
            }
            print(" [\(lvlStr)] [\(entry.file):\(entry.line)] \(entry.message)")
        }
        print("==========================================================================================\n")
        fflush(stdout)
    }

    // MARK: - Static Helper Shorthands

    @inline(__always)
    public static func debug(_ message: @autoclosure () -> String, file: String = #file, line: UInt = #line) {
        shared.log(level: .debug, message: message(), file: file, line: line)
    }

    @inline(__always)
    public static func info(_ message: @autoclosure () -> String, file: String = #file, line: UInt = #line) {
        shared.log(level: .info, message: message(), file: file, line: line)
    }

    @inline(__always)
    public static func warning(_ message: @autoclosure () -> String, file: String = #file, line: UInt = #line) {
        shared.log(level: .warning, message: message(), file: file, line: line)
    }

    @inline(__always)
    public static func error(_ message: @autoclosure () -> String, file: String = #file, line: UInt = #line) {
        shared.log(level: .error, message: message(), file: file, line: line)
    }
}
