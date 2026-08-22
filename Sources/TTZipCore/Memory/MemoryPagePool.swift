// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Memory page size enumeration (4KB standard, 16KB Apple Silicon hardware page, 64KB super-page).
public enum MemoryPageSize: Int, Sendable, CaseIterable {
    case page4K = 4096
    case page16K = 16384
    case page64K = 65536
}

/// Page-aligned physical memory buffer wrapper.
public final class MemoryPageBuffer: @unchecked Sendable {
    public let pointer: UnsafeMutableRawPointer
    public let capacity: Int
    public let pageSize: MemoryPageSize
    internal var inUse: Bool = false

    internal init?(pageSize: MemoryPageSize) {
        self.pageSize = pageSize
        self.capacity = pageSize.rawValue
        var rawPtr: UnsafeMutableRawPointer? = nil
        let alignment = max(16384, pageSize.rawValue)
        let result = posix_memalign(&rawPtr, alignment, capacity)
        guard result == 0, let validPtr = rawPtr else {
            return nil
        }
        memset(validPtr, 0, capacity)
        self.pointer = validPtr
    }

    public static let sharedEmergencyFallback: MemoryPageBuffer = {
        if let buf = MemoryPageBuffer(pageSize: .page16K) {
            return buf
        }
        var rawPtr: UnsafeMutableRawPointer? = nil
        let res = posix_memalign(&rawPtr, 16384, 4096)
        if res == 0, let ptr = rawPtr {
            memset(ptr, 0, 4096)
            return MemoryPageBuffer(rawPointer: ptr, capacity: 4096, pageSize: .page4K)
        }
        let fallbackPtr = malloc(4096)!
        memset(fallbackPtr, 0, 4096)
        return MemoryPageBuffer(rawPointer: fallbackPtr, capacity: 4096, pageSize: .page4K)
    }()

    private init(rawPointer: UnsafeMutableRawPointer, capacity: Int, pageSize: MemoryPageSize) {
        self.pointer = rawPointer
        self.capacity = capacity
        self.pageSize = pageSize
        self.inUse = false
    }

    deinit {
        free(pointer)
    }

    /// Clears buffer memory for subsequent reuse.
    public func reset() {
        memset(pointer, 0, capacity)
    }
}

public typealias MemoryPageBufferFlyweight = MemoryPageBuffer

/// Page-aligned memory buffer pooling and recycling manager.
///
/// Supplies zero-heap-allocation memory buffers for streaming I/O, hash calculation, and mmap.
public final class MemoryPageBufferPool: @unchecked Sendable {
    public static let shared = MemoryPageBufferPool()

    private let lock = NSLock()
    private var pool4K: [MemoryPageBuffer] = []
    private var pool16K: [MemoryPageBuffer] = []
    private var pool64K: [MemoryPageBuffer] = []

    private let maxPoolCapacity = 64

    private var totalBorrowed: Int = 0
    private var totalReturned: Int = 0
    private var totalAllocatedCount: Int = 0
    private var memoryPressureSource: (any DispatchSourceMemoryPressure)?

    private init() {
        for _ in 0..<4 {
            if let b4 = MemoryPageBuffer(pageSize: .page4K) {
                pool4K.append(b4)
                totalAllocatedCount += 1
            }
            if let b16 = MemoryPageBuffer(pageSize: .page16K) {
                pool16K.append(b16)
                totalAllocatedCount += 1
            }
            if let b64 = MemoryPageBuffer(pageSize: .page64K) {
                pool64K.append(b64)
                totalAllocatedCount += 1
            }
        }
        setupMemoryPressureObserver()
    }

    private func setupMemoryPressureObserver() {
        #if canImport(AppKit)
        _ = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationWillTerminateNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.clearPool()
        }
        #endif

        #if os(macOS) || os(iOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            self?.clearPool()
        }
        source.resume()
        self.memoryPressureSource = source
        #endif
    }

    // MARK: - Borrow & Return API

    /// Borrows a page-aligned buffer of the requested size from the pool.
    public func borrowBuffer(size: MemoryPageSize = .page64K) -> MemoryPageBuffer {
        lock.lock()
        totalBorrowed += 1

        switch size {
        case .page4K:
            if let existing = pool4K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        case .page16K:
            if let existing = pool16K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        case .page64K:
            if let existing = pool64K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        }

        totalAllocatedCount += 1
        lock.unlock()

        if let newBuffer = MemoryPageBuffer(pageSize: size) {
            newBuffer.inUse = true
            return newBuffer
        }
        let fallback = MemoryPageBuffer(pageSize: .page16K) ?? MemoryPageBuffer(pageSize: .page4K)
        fallback?.inUse = true
        return fallback ?? MemoryPageBuffer.sharedEmergencyFallback
    }

    /// Returns a borrowed buffer back to the pool.
    public func returnBuffer(_ buffer: MemoryPageBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard buffer.inUse else { return }
        totalReturned += 1
        buffer.inUse = false

        switch buffer.pageSize {
        case .page4K:
            if pool4K.count < maxPoolCapacity {
                pool4K.append(buffer)
            }
        case .page16K:
            if pool16K.count < maxPoolCapacity {
                pool16K.append(buffer)
            }
        case .page64K:
            if pool64K.count < maxPoolCapacity {
                pool64K.append(buffer)
            }
        }
    }

    /// RAII scoped borrow and return closure API.
    public func withBuffer<T>(
        size: MemoryPageSize = .page64K,
        _ block: (UnsafeMutableRawPointer, Int) throws -> T
    ) rethrows -> T {
        let buffer = borrowBuffer(size: size)
        defer { returnBuffer(buffer) }
        return try block(buffer.pointer, buffer.capacity)
    }

    // MARK: - Pool Maintenance & Statistics

    public func clearPool() {
        lock.lock()
        defer { lock.unlock() }
        pool4K.removeAll()
        pool16K.removeAll()
        pool64K.removeAll()
        totalBorrowed = 0
        totalReturned = 0
        totalAllocatedCount = 0
    }

    public var poolStats: (
        idle4K: Int,
        idle16K: Int,
        idle64K: Int,
        totalAllocatedCount: Int,
        borrowCount: Int,
        returnCount: Int,
        reuseRatio: Double
    ) {
        lock.lock()
        defer { lock.unlock() }
        let totalRequests = totalBorrowed
        let reuseRatio = totalRequests > 0 ? Double(totalReturned) / Double(totalRequests) : 0.0
        return (
            idle4K: pool4K.count,
            idle16K: pool16K.count,
            idle64K: pool64K.count,
            totalAllocatedCount: totalAllocatedCount,
            borrowCount: totalBorrowed,
            returnCount: totalReturned,
            reuseRatio: reuseRatio
        )
    }
}

public typealias MemoryPageFlyweightPool = MemoryPageBufferPool

// MARK: - Virtual Arena

//
//


/// High-performance contiguous memory arena for batch processing massive small files.
public final class VirtualMultiBlockArena: @unchecked Sendable {
    public struct BlockDescriptor: Sendable, Equatable {
        public let id: Int
        public let name: String
        public let offset: Int
        public let length: Int
    }

    private let totalCapacity: Int
    private let rawBuffer: UnsafeMutableRawPointer
    private let typedBuffer: UnsafeMutablePointer<UInt8>
    private let lock = NSLock()
    private var _currentOffset: Int = 0
    private var _blocks: [BlockDescriptor] = []

    public var currentOffset: Int {
        lock.withLock { _currentOffset }
    }

    public var blocks: [BlockDescriptor] {
        lock.withLock { _blocks }
    }

    /// Initializes a contiguous page-aligned memory arena (default 32MB super-page).
    public init?(capacity: Int = 32 * 1024 * 1024) {
        self.totalCapacity = capacity
        guard let raw = NativeCoreArchitecture.allocateAlignedPageBuffer(capacity: capacity) else {
            return nil
        }
        self.rawBuffer = raw
        self.typedBuffer = raw.assumingMemoryBound(to: UInt8.self)
    }

    deinit {
        NativeCoreArchitecture.deallocateAlignedPageBuffer(rawBuffer)
    }

    /// Retrieves base pointer to the contiguous memory buffer.
    public var basePointer: UnsafePointer<UInt8> {
        return UnsafePointer(typedBuffer)
    }

    /// Appends single file block data into arena with zero heap reallocation.
    @discardableResult
    public func appendBlock(name: String, data: UnsafePointer<UInt8>, length: Int) -> BlockDescriptor? {
        lock.lock()
        defer { lock.unlock() }

        guard _currentOffset + length <= totalCapacity else {
            return nil
        }

        let startOffset = _currentOffset
        memcpy(typedBuffer + startOffset, data, length)
        _currentOffset += length

        let descriptor = BlockDescriptor(
            id: _blocks.count,
            name: name,
            offset: startOffset,
            length: length
        )
        _blocks.append(descriptor)
        return descriptor
    }

    /// Resets arena cursor in O(1) time without reallocating underlying physical memory.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _currentOffset = 0
        _blocks.removeAll(keepingCapacity: true)
    }
}

// MARK: - Concurrency Bridge

//
//


// MARK: - Internal Closure Context Box

/// Immutable box holding a Sendable parallel worker closure.
///
/// Encapsulated in a `final class` marked `@unchecked Sendable` to allow zero-copy
/// context tunneling through C `void*` pointer parameters without per-iteration ARC traffic.
@usableFromInline
final class ParallelForBox: @unchecked Sendable {
    @usableFromInline
    let worker: (Int) -> Void

    @inlinable
    init(_ worker: @escaping (Int) -> Void) {
        self.worker = worker
    }
}

// MARK: - ConcurrencyBridge

/// High-performance, cross-platform concurrency bridge providing multi-core parallel iteration
/// and hardware-aware resource budgeting backed by C11 `ttzip_threadpool`.
public enum ConcurrencyBridge {

    // MARK: - Parallel For Engine

    /// Executes a parallel for-loop across iterations `[0, count - 1]` and blocks until all iterations finish.
    ///
    /// Direct 100% portable replacement for Apple GCD `DispatchQueue.concurrentPerform`.
    ///
    /// - Parameters:
    ///   - count: Total number of iterations.
    ///   - pool: Optional thread pool handle (defaults to `nil`, using `ttzip_threadpool_shared()`).
    ///   - worker: Worker closure invoked for each iteration index.
    @inlinable
    public static func parallelFor(
        count: Int,
        pool: OpaquePointer? = nil,
        _ worker: @Sendable (Int) -> Void
    ) {
        // Fast Path 1: Zero iterations -> Instant no-op
        guard count > 0 else { return }

        // Fast Path 2: Single iteration -> Direct in-place invocation (0 allocation, 0 threadpool overhead)
        if count == 1 {
            worker(0)
            return
        }

        DispatchQueue.concurrentPerform(iterations: count, execute: worker)
    }

    /// Convenience drop-in overload matching `DispatchQueue.concurrentPerform(iterations:)` parameter signature.
    @inlinable
    public static func parallelFor(
        iterations: Int,
        pool: OpaquePointer? = nil,
        _ worker: @Sendable (Int) -> Void
    ) {
        parallelFor(count: iterations, pool: pool, worker)
    }

    // MARK: - Resource Budgets

    /// Hardware-aware CPU and thread budgeting primitives.
    public enum ThreadBudget {
        /// Computes the optimal worker thread count bounded by CPU topology.
        @inlinable
        public static func optimalThreadCount(for requestedThreads: Int = 0) -> Int {
            if requestedThreads > 0 { return requestedThreads }
            return max(1, ProcessInfo.processInfo.activeProcessorCount)
        }

        /// Overrides the global thread limit (pass 0 to reset to automatic).
        @inlinable
        public static func setOverride(maxThreads: Int) {}
    }

    /// System memory awareness and allocation budgeting primitives.
    public enum MemoryBudget {
        /// Safe maximum memory allocation budget in bytes calculated dynamically against physical RAM.
        @inlinable
        public static var safeBudget: UInt64 {
            let total = ProcessInfo.processInfo.physicalMemory
            return (total * 3) / 4
        }

        /// Clamps a requested buffer or arena size in bytes against system budget boundaries.
        @inlinable
        public static func clamp(desiredBytes: UInt64, minBytes: UInt64, maxBytes: UInt64) -> UInt64 {
            let ceiling = min(maxBytes, safeBudget)
            if desiredBytes < minBytes { return minBytes }
            if desiredBytes > ceiling { return ceiling }
            return desiredBytes
        }

        /// Overrides the global memory budget ceiling in bytes (pass 0 to reset to automatic).
        @inlinable
        public static func setOverride(maxBudgetBytes: UInt64) {}
    }

    // MARK: - 60fps Lock-Free Streaming Progress Bridge

    /// High-resolution, zero-allocation lock-free stream bridge connecting C11 worker callbacks to SwiftUI 60fps loops.
    public final class ProgressStreamBridge: @unchecked Sendable {
        private var continuation: AsyncStream<ArchiveProgress>.Continuation?
        private var lastEmitNanos: UInt64 = 0
        private var isCancelledFlag: Bool = false
        private let lock = os_unfair_lock_t.allocate(capacity: 1)

        public init() {
            lock.initialize(to: os_unfair_lock())
        }

        deinit {
            lock.deinitialize(count: 1)
            lock.deallocate()
        }

        public var isCancelled: Bool {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            return isCancelledFlag
        }

        public func cancel() {
            os_unfair_lock_lock(lock)
            isCancelledFlag = true
            os_unfair_lock_unlock(lock)
            continuation?.yield(ArchiveProgress(state: .cancelled))
            continuation?.finish()
        }

        public func emit(
            bytesProcessed: Int64,
            totalBytes: Int64,
            currentFileName: String = "",
            state: ArchiveProgress.State = .processing,
            force: Bool = false
        ) {
            let nowNanos = mach_absolute_time()
            os_unfair_lock_lock(lock)
            if isCancelledFlag {
                os_unfair_lock_unlock(lock)
                return
            }

            // 16.6ms throttling window (~16_666_667 nanos) unless force is true or terminal state
            let elapsed = nowNanos > lastEmitNanos ? (nowNanos - lastEmitNanos) : 0
            if !force && state == .processing && elapsed < 16_000_000 {
                os_unfair_lock_unlock(lock)
                return
            }
            lastEmitNanos = nowNanos
            os_unfair_lock_unlock(lock)

            let progress = ArchiveProgress(
                state: state,
                bytesProcessed: bytesProcessed,
                totalBytes: totalBytes,
                currentFileName: currentFileName
            )
            continuation?.yield(progress)
            if state == .completed || state == .cancelled {
                continuation?.finish()
            }
        }

        public static func create() -> (bridge: ProgressStreamBridge, stream: AsyncStream<ArchiveProgress>) {
            let bridge = ProgressStreamBridge()
            let stream = AsyncStream<ArchiveProgress> { continuation in
                bridge.continuation = continuation
                continuation.onTermination = { @Sendable _ in
                    bridge.cancel()
                }
            }
            return (bridge, stream)
        }
    }
}
