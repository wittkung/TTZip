import Foundation
import Darwin

/// 【Pattern 4.2 读写锁 / 线程安全缓存模式】POSIX 读写锁实现 (POSIX Read-Write Lock)
/// 基于 C `pthread_rwlock_t` 的高性能底层读写锁封装
/// 允许多个并发 Task/Thread 共享读锁，写锁则具备独占与互斥特性
public final class POSIXReadWriteLock: ReadWriteLockProtocol, @unchecked Sendable {
    private var rwlock = pthread_rwlock_t()
    
    public init() {
        let status = pthread_rwlock_init(&rwlock, nil)
        precondition(status == 0, "POSIXReadWriteLock initialization failed with error code: \(status)")
    }
    
    deinit {
        pthread_rwlock_destroy(&rwlock)
    }
    
    /// 读锁执行闭包 (Concurrent Shared Read)
    public func withReadLock<T>(_ closure: () throws -> T) rethrows -> T {
        pthread_rwlock_rdlock(&rwlock)
        defer { pthread_rwlock_unlock(&rwlock) }
        return try closure()
    }
    
    /// 写锁执行闭包 (Exclusive Write)
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
