// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import os

/// Thread-safe test log collector and POSIX atomic chunk flush coordinator.
///
/// Buffers diagnostic logs in memory during test execution:
/// - Passing test cases: silent memory cleanup with zero terminal noise.
/// - Failing test cases: atomic single-chunk diagnostic dump preventing interleaved stdout writes.
public final class TestLogCollector: @unchecked Sendable {
    public static let shared = TestLogCollector()
    
    private var lock = os_unfair_lock_s()
    private var sessionBuffers: [String: [String]] = [:]
    
    @TaskLocal
    public static var currentSessionID: String?
    
    private init() {}
    
    /// Appends log line to specified session.
    public func record(sessionID: String, message: String) {
        os_unfair_lock_lock(&lock)
        sessionBuffers[sessionID, default: []].append(message)
        os_unfair_lock_unlock(&lock)
    }
    
    /// Appends log line to current TaskLocal session if active.
    public func recordCurrent(message: String) {
        guard let sid = Self.currentSessionID else { return }
        record(sessionID: sid, message: message)
    }
    
    /// Clears session buffer upon test success.
    public func clear(sessionID: String) {
        os_unfair_lock_lock(&lock)
        sessionBuffers.removeValue(forKey: sessionID)
        os_unfair_lock_unlock(&lock)
    }
    
    /// Atomically flushes complete diagnostic report to standard output upon test failure.
    public func flushOnFailure(sessionID: String, failureHeader: String) {
        os_unfair_lock_lock(&lock)
        let logs = sessionBuffers.removeValue(forKey: sessionID) ?? []
        os_unfair_lock_unlock(&lock)
        
        var output = "\n"
        output += "==========================================================================================\n"
        output += "🚨 \u{001B}[1;31m[TEST FAILURE REPORT]\u{001B}[0m Session: \(sessionID)\n"
        output += "------------------------------------------------------------------------------------------\n"
        output += failureHeader + "\n"
        
        if !logs.isEmpty {
            output += "------------------------------------- Captured Logs --------------------------------------\n"
            for log in logs {
                output += "  " + log + "\n"
            }
        }
        output += "==========================================================================================\n\n"
        
        flockfile(stdout)
        fputs(output, stdout)
        fflush(stdout)
        funlockfile(stdout)
    }
    
    /// Retrieves current captured logs snapshot for reporting.
    public func getCapturedLogs(sessionID: String) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return sessionBuffers[sessionID] ?? []
    }
}
