// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance thread-local context memory pool for zero-allocation parallel processing.
public final class ThreadLocalContextPoolAdapter: @unchecked Sendable {
    public static let shared = ThreadLocalContextPoolAdapter(
        workerCount: AppleSiliconTuner.shared.totalCores,
        scratchpadSize: 256 * 1024 // 256KB per worker (aligned to L2 cache)
    )

    @usableFromInline
    internal let pool: UnsafeMutablePointer<ttzip_context_pool_t>?
    public let workerCount: Int
    public let scratchpadSize: Int

    public init(workerCount: Int, scratchpadSize: Int = 256 * 1024) {
        self.workerCount = max(1, workerCount)
        self.scratchpadSize = max(4096, scratchpadSize)
        self.pool = ttzip_context_pool_create(self.workerCount, self.scratchpadSize)
    }

    deinit {
        if let pool = pool {
            ttzip_context_pool_destroy(pool)
        }
    }

    /// Borrows a pre-allocated 64-byte aligned scratchpad buffer for worker execution.
    @inlinable
    public func withScratchpad<R>(
        workerId: Int,
        _ body: (UnsafeMutablePointer<UInt8>, Int) throws -> R
    ) rethrows -> R {
        guard let pool = pool else {
            let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: scratchpadSize)
            defer { temp.deallocate() }
            return try body(temp, scratchpadSize)
        }

        let boundedId = workerId % workerCount
        guard let ptr = ttzip_context_pool_acquire(pool, boundedId) else {
            let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: scratchpadSize)
            defer { temp.deallocate() }
            return try body(temp, scratchpadSize)
        }

        defer {
            ttzip_context_pool_release(pool, boundedId)
        }

        return try body(ptr, scratchpadSize)
    }
}
