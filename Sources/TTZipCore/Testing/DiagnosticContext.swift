// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Deferred failure context injector adhering to libarchive `failure()` test semantics.
///
/// Injects intent descriptions prior to assertion evaluation with zero formatting overhead on pass paths;
/// messages are consumed and rendered only upon assertion failure.
public enum DiagnosticContext: Sendable {
    
    @TaskLocal
    private static var taskLocalPendingMessage: String?
    
    private static let lock = NSLock()
    nonisolated(unsafe) private static var threadLocalPendingMessages: [UInt64: String] = [:]
    
    /// Registers a deferred failure message consumed if subsequent assertions fail.
    public static func failure(_ message: String) {
        if taskLocalPendingMessage != nil {
            return
        }
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        threadLocalPendingMessages[tid] = message
        lock.unlock()
    }
    
    /// Binds deferred failure message within an async closure scope.
    public static func withFailureMessage<R>(_ message: String, operation: () throws -> R) rethrows -> R {
        try $taskLocalPendingMessage.withValue(message) {
            try operation()
        }
    }
    
    /// Async scope binding for deferred failure messages.
    public static func withFailureMessage<R>(_ message: String, operation: () async throws -> R) async rethrows -> R {
        try await $taskLocalPendingMessage.withValue(message) {
            try await operation()
        }
    }
    
    /// Consumes and clears pending message for the current thread or task context.
    public static func consumePendingMessage() -> String? {
        if let msg = taskLocalPendingMessage {
            return msg
        }
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        defer { lock.unlock() }
        return threadLocalPendingMessages.removeValue(forKey: tid)
    }
    
    /// Clears any pending diagnostic failure messages.
    public static func clear() {
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        threadLocalPendingMessages.removeValue(forKey: tid)
        lock.unlock()
    }
}
