// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

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
