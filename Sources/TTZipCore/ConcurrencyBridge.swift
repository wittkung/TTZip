// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

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
        _ worker: (Int) -> Void
    ) {
        // Fast Path 1: Zero iterations -> Instant no-op
        guard count > 0 else { return }

        // Fast Path 2: Single iteration -> Direct in-place invocation (0 allocation, 0 threadpool overhead)
        if count == 1 {
            worker(0)
            return
        }

        // Parallel Path: Tunnel Swift closure context into C void* via Unmanaged.passUnretained
        withoutActuallyEscaping(worker) { escapingWorker in
            let box = ParallelForBox(escapingWorker)
            let contextPtr = Unmanaged.passUnretained(box).toOpaque()

            withExtendedLifetime(box) {
                ttzip_parallel_for(
                    pool,
                    count,
                    { index, userData in
                        guard let userData = userData else { return }
                        let box = Unmanaged<ParallelForBox>.fromOpaque(userData).takeUnretainedValue()
                        box.worker(index)
                    },
                    contextPtr
                )
            }
        }
    }

    /// Convenience drop-in overload matching `DispatchQueue.concurrentPerform(iterations:)` parameter signature.
    @inlinable
    public static func parallelFor(
        iterations: Int,
        pool: OpaquePointer? = nil,
        _ worker: (Int) -> Void
    ) {
        parallelFor(count: iterations, pool: pool, worker)
    }

    // MARK: - Resource Budgets

    /// Hardware-aware CPU and thread budgeting primitives.
    public enum ThreadBudget {
        /// Computes the optimal worker thread count bounded by CPU topology (P-cores / E-cores).
        @inlinable
        public static func optimalThreadCount(for requestedThreads: Int = 0) -> Int {
            return Int(ttzip_thread_budget_get(UInt32(max(0, requestedThreads))))
        }

        /// Overrides the global thread limit (pass 0 to reset to automatic).
        @inlinable
        public static func setOverride(maxThreads: Int) {
            ttzip_thread_budget_set_override(UInt32(max(0, maxThreads)))
        }

        /// Returns detected CPU topology.
        @inlinable
        public static var topology: ttzip_cpu_topology_t {
            return ttzip_cpu_topology_detect()
        }
    }

    /// System memory awareness and allocation budgeting primitives.
    public enum MemoryBudget {
        /// Safe maximum memory allocation budget in bytes calculated dynamically against physical RAM.
        @inlinable
        public static var safeBudget: UInt64 {
            return ttzip_mem_budget_query().safe_budget_bytes
        }

        /// Queries current memory state (total, available, safe budget).
        @inlinable
        public static func query() -> ttzip_mem_budget_t {
            return ttzip_mem_budget_query()
        }

        /// Clamps a requested buffer or arena size in bytes against system budget boundaries.
        @inlinable
        public static func clamp(desiredBytes: UInt64, minBytes: UInt64, maxBytes: UInt64) -> UInt64 {
            return ttzip_mem_budget_clamp(desiredBytes, minBytes, maxBytes)
        }

        /// Overrides the global memory budget ceiling in bytes (pass 0 to reset to automatic).
        @inlinable
        public static func setOverride(maxBudgetBytes: UInt64) {
            ttzip_mem_budget_set_override(maxBudgetBytes)
        }
    }
}
