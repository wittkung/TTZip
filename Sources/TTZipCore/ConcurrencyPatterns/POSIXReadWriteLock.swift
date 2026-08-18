// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Darwin

/// High-performance POSIX read-write lock wrapper around C `pthread_rwlock_t`.
///
/// Permits concurrent shared reader acquisitions while enforcing exclusive writer mutations.
public final class POSIXReadWriteLock: ReadWriteLockProtocol, @unchecked Sendable {
    private var rwlock = pthread_rwlock_t()
    
    public init() {
        let status = pthread_rwlock_init(&rwlock, nil)
        precondition(status == 0, "POSIXReadWriteLock initialization failed with error code: \(status)")
    }
    
    deinit {
        pthread_rwlock_destroy(&rwlock)
    }
    
    /// Executes closure under shared read lock.
    public func withReadLock<T>(_ closure: () throws -> T) rethrows -> T {
        pthread_rwlock_rdlock(&rwlock)
        defer { pthread_rwlock_unlock(&rwlock) }
        return try closure()
    }
    
    /// Executes closure under exclusive write lock.
    public func withWriteLock<T>(_ closure: () throws -> T) rethrows -> T {
        pthread_rwlock_wrlock(&rwlock)
        defer { pthread_rwlock_unlock(&rwlock) }
        return try closure()
    }
    
    // MARK: - ReadWriteLockProtocol Conformance
    
    public func read<T>(_ block: () throws -> T) rethrows -> T {
        return try withReadLock(block)
    }
    
    public func write<T>(_ block: () throws -> T) rethrows -> T {
        return try withWriteLock(block)
    }
}
