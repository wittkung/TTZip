// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// ARM64 hardware PMULL accelerated zero-copy CRC-64 (ECMA-182) computation engine.
@frozen
public enum CRC64Checksum: Sendable {
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
            return ttzip_crc64(baseAddress, rawBuffer.count, seed)
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
        return ttzip_crc64(bytePtr, buffer.count, seed)
    }

    /// Computes CRC-64 (ECMA-182) for a typed byte buffer pointer.
    /// - Parameters:
    ///   - buffer: Byte buffer pointer.
    ///   - seed: Initial CRC seed (defaults to 0).
    /// - Returns: Computed 64-bit checksum.
    @inlinable
    public static func calculate(buffer: UnsafeBufferPointer<UInt8>, seed: UInt64 = 0) -> UInt64 {
        guard let base = buffer.baseAddress, buffer.count > 0 else { return seed }
        return ttzip_crc64(base, buffer.count, seed)
    }
}
