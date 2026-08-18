// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Memory-safe C pointer and buffer interoperability adapter.
///
/// Eliminates dangling pointer dereferences, heap buffer overruns, and stack exhaustion
/// when interfacing Swift memory collections with underlying C static libraries.
public enum CUnsafeBufferAdapter {
    
    /// Safely converts an optional Swift `String` to a temporary `const char*` pointer.
    /// - Parameters:
    ///   - string: Input Swift string, or `nil`.
    ///   - body: Closure receiving the C string pointer.
    /// - Returns: Closure return value.
    @inline(__always)
    public static func withCString<R>(_ string: String?, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        guard let string = string else {
            return try body(nil)
        }
        return try string.withCString { cStr in
            try body(cStr)
        }
    }

    /// Safely converts `[String]` into a scoped `const char* const*` pointer array with automatic deallocation.
    /// - Parameters:
    ///   - strings: Array of Swift strings.
    ///   - body: Closure receiving the C string pointer array.
    /// - Returns: Closure return value.
    public static func withCStringsArray<R>(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) throws -> R) rethrows -> R {
        var cStrings: [UnsafeMutablePointer<CChar>?] = []
        cStrings.reserveCapacity(strings.count + 1)
        for str in strings {
            cStrings.append(strdup(str))
        }
        defer {
            for ptr in cStrings {
                if let ptr = ptr {
                    free(ptr)
                }
            }
        }

        return try cStrings.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else {
                var dummy: UnsafePointer<CChar>? = nil
                return try withUnsafePointer(to: &dummy) { try body($0) }
            }
            return try base.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: bufPtr.count) { reboundPtr in
                try body(reboundPtr)
            }
        }
    }

    /// Safely converts `[String]` into a `NULL`-terminated pointer array suitable for `posix_spawn` argv.
    /// - Parameters:
    ///   - strings: Array of Swift argument strings.
    ///   - body: Closure receiving the NULL-terminated pointer array.
    /// - Returns: Closure return value.
    public static func withCStringsNullTerminatedArray<R>(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) throws -> R) rethrows -> R {
        var cStrings: [UnsafeMutablePointer<CChar>?] = []
        cStrings.reserveCapacity(strings.count + 1)
        for str in strings {
            cStrings.append(strdup(str))
        }
        cStrings.append(nil)
        defer {
            for ptr in cStrings {
                if let ptr = ptr {
                    free(ptr)
                }
            }
        }

        return try cStrings.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else {
                var dummy: UnsafePointer<CChar>? = nil
                return try withUnsafePointer(to: &dummy) { try body($0) }
            }
            return try base.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: bufPtr.count) { reboundPtr in
                try body(reboundPtr)
            }
        }
    }

    /// Safely provides raw byte pointer and count representation of Swift `Data`.
    /// - Parameters:
    ///   - data: Input Data payload.
    ///   - body: Closure receiving `(UnsafeRawPointer, Int)`.
    /// - Returns: Closure return value.
    @inline(__always)
    public static func withBufferPointer<R>(_ data: Data, _ body: (UnsafeRawPointer, Int) throws -> R) rethrows -> R {
        if data.isEmpty {
            var dummy: UInt8 = 0
            return try body(&dummy, 0)
        }
        return try data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                return try body(baseAddress, data.count)
            } else {
                var dummy: UInt8 = 0
                return try body(&dummy, 0)
            }
        }
    }

    /// Safely provides mutable raw byte pointer and capacity representation of Swift `Data`.
    /// - Parameters:
    ///   - data: Inout Data payload.
    ///   - body: Closure receiving `(UnsafeMutableRawPointer, Int)`.
    /// - Returns: Closure return value.
    @inline(__always)
    public static func withMutableBufferPointer<R>(_ data: inout Data, _ body: (UnsafeMutableRawPointer, Int) throws -> R) rethrows -> R {
        let count = data.count
        if count == 0 {
            var dummy: UInt8 = 0
            return try body(&dummy, 0)
        }
        return try data.withUnsafeMutableBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                return try body(baseAddress, count)
            } else {
                var dummy: UInt8 = 0
                return try body(&dummy, 0)
            }
        }
    }

    /// Allocates an Apple Silicon 16KB hardware page-aligned memory buffer.
    /// - Parameter capacity: Minimum capacity in bytes.
    /// - Returns: Pointer to aligned buffer, or `nil` on failure.
    @inline(__always)
    public static func allocateAlignedBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return ttzip_core_aligned_alloc_16k(capacity)
    }

    /// Deallocates a 16KB hardware page-aligned memory buffer.
    /// - Parameter pointer: Pointer previously returned by `allocateAlignedBuffer`.
    @inline(__always)
    public static func deallocateAlignedBuffer(_ pointer: UnsafeMutableRawPointer) {
        ttzip_core_aligned_free_16k(pointer)
    }

    /// Flyweight Pattern: Borrows a 4KB or 64KB page-aligned buffer from the shared flyweight pool.
    /// - Parameter size: Target page size enum (`.page4K` or `.page64K`).
    /// - Returns: Active `MemoryPageBufferFlyweight` handle.
    @inline(__always)
    public static func borrowPageBuffer(size: MemoryPageSize = .page64K) -> MemoryPageBufferFlyweight {
        return MemoryPageFlyweightPool.shared.borrowBuffer(size: size)
    }

    /// Returns a borrowed page buffer flyweight back to the shared pool.
    /// - Parameter buffer: Buffer handle to return.
    @inline(__always)
    public static func returnPageBuffer(_ buffer: MemoryPageBufferFlyweight) {
        MemoryPageFlyweightPool.shared.returnBuffer(buffer)
    }
}
