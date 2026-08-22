// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// High-performance zero-copy CRC-64 (ECMA-182) computation engine.
@frozen
public enum CRC64Checksum: Sendable {
    @usableFromInline
    internal static let table: [UInt64] = {
        var tbl = [UInt64](repeating: 0, count: 256)
        let poly: UInt64 = 0x42F0_E1EB_A9EA_3693
        for i in 0..<256 {
            var crc = UInt64(i)
            for _ in 0..<8 {
                crc = (crc & 1 != 0) ? ((crc >> 1) ^ poly) : (crc >> 1)
            }
            tbl[i] = crc
        }
        return tbl
    }()

    /// Computes CRC-64 (ECMA-182) for a `Data` buffer.
    /// - Parameters:
    ///   - data: Binary data payload.
    ///   - seed: Initial CRC seed (defaults to 0).
    /// - Returns: Computed 64-bit checksum.
    @inlinable
    public static func calculate(for data: Data, seed: UInt64 = 0) -> UInt64 {
        guard !data.isEmpty else { return seed }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return seed
            }
            return calculate(buffer: UnsafeBufferPointer(start: baseAddress, count: rawBuffer.count), seed: seed)
        }
    }

    /// Computes CRC-64 (ECMA-182) for a raw buffer pointer.
    /// - Parameters:
    ///   - buffer: Contiguous memory buffer.
    ///   - seed: Initial CRC seed (defaults to 0).
    /// - Returns: Computed 64-bit checksum.
    @inlinable
    public static func calculate(buffer: UnsafeRawBufferPointer, seed: UInt64 = 0) -> UInt64 {
        guard let base = buffer.baseAddress, buffer.count > 0 else { return seed }
        let bytePtr = base.assumingMemoryBound(to: UInt8.self)
        return calculate(buffer: UnsafeBufferPointer(start: bytePtr, count: buffer.count), seed: seed)
    }

    /// Computes CRC-64 (ECMA-182) for a typed byte buffer pointer.
    /// - Parameters:
    ///   - buffer: Byte buffer pointer.
    ///   - seed: Initial CRC seed (defaults to 0).
    /// - Returns: Computed 64-bit checksum.
    @inlinable
    public static func calculate(buffer: UnsafeBufferPointer<UInt8>, seed: UInt64 = 0) -> UInt64 {
        guard let base = buffer.baseAddress, buffer.count > 0 else { return seed }
        var crc = ~seed
        let tbl = table
        for i in 0..<buffer.count {
            let byte = base[i]
            let idx = Int(UInt8(crc & 0xFF) ^ byte)
            crc = tbl[idx] ^ (crc >> 8)
        }
        return ~crc
    }
}
