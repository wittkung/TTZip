// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 面向海量小文件批量处理的虚拟多块连续内存竞技场 (Virtual Multi-Block Memory Arena)
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
    private(set) public var currentOffset: Int = 0
    private(set) public var blocks: [BlockDescriptor] = []

    public init?(capacity: Int = 32 * 1024 * 1024) { // 默认 32MB 连续大页
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

    /// 获取底层连续内存基指针
    public var basePointer: UnsafePointer<UInt8> {
        return UnsafePointer(typedBuffer)
    }

    /// 追加单个文件块数据到竞技场中 (零额外动态堆分配)
    @discardableResult
    public func appendBlock(name: String, data: UnsafePointer<UInt8>, length: Int) -> BlockDescriptor? {
        guard currentOffset + length <= totalCapacity else {
            return nil
        }

        let startOffset = currentOffset
        memcpy(typedBuffer + startOffset, data, length)
        currentOffset += length

        let descriptor = BlockDescriptor(
            id: blocks.count,
            name: name,
            offset: startOffset,
            length: length
        )
        blocks.append(descriptor)
        return descriptor
    }

    /// 重置竞技场 (O(1) 游标复位，避免内存二次分配)
    public func reset() {
        currentOffset = 0
        blocks.removeAll(keepingCapacity: true)
    }
}
