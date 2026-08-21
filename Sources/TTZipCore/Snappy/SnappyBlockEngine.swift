// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance in-process Swift wrapper around Google Snappy native engine.
public final class SnappyBlockEngine: Sendable {

    public static let shared = SnappyBlockEngine()

    public init() {}

    /// Checks if native Snappy engine is available.
    public var isAvailable: Bool {
        return true
    }

    /// Computes upper bound on compressed bytes for a given raw input size.
    public func maxCompressedLength(for sourceLength: Int) -> Int {
        guard sourceLength >= 0 else { return 32 }
        return ttzip_rust_snappy_max_compressed_length(sourceLength)
    }

    /// Parses uncompressed length from Varint32 header.
    public func uncompressedLength(of compressedData: Data) throws -> Int {
        guard !compressedData.isEmpty else {
            throw SnappyError.corruptVarint
        }

        var resultLength: Int = 0
        let status: CTTZipBridge.TTZipStatus = compressedData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return ttzip_rust_snappy_uncompressed_length(baseAddress, rawBuffer.count, &resultLength)
        }

        guard status == TTZIP_STATUS_OK else {
            throw SnappyError.corruptVarint
        }

        return resultLength
    }

    /// Compresses uncompressed data block using native Google Snappy.
    public func compress(data: Data) throws -> Data {
        if data.isEmpty {
            return Data()
        }

        let maxCapacity = maxCompressedLength(for: data.count)
        var compressedData = Data(count: maxCapacity)
        var actualCompressedLength = maxCapacity

        let status: CTTZipBridge.TTZipStatus = data.withUnsafeBytes { inBuf in
            guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return compressedData.withUnsafeMutableBytes { outBuf in
                guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return ttzip_rust_snappy_compress(inBase, inBuf.count, outBase, maxCapacity, &actualCompressedLength)
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw SnappyError.corruptTag
        }

        compressedData.count = actualCompressedLength
        return compressedData
    }

    /// Decompresses raw Snappy compressed block into uncompressed Data.
    public func decompress(compressedData: Data, maxAllowedSize: Int = 1_073_741_824) throws -> Data {
        guard !compressedData.isEmpty else {
            return Data()
        }

        let expectedLength = try uncompressedLength(of: compressedData)
        guard expectedLength <= maxAllowedSize else {
            throw SnappyError.decompressedSizeExceeded(maxAllowed: maxAllowedSize, actual: expectedLength)
        }

        var decompressedData = Data(count: expectedLength)
        var actualLength = expectedLength

        let status: CTTZipBridge.TTZipStatus = compressedData.withUnsafeBytes { inBuf in
            guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return decompressedData.withUnsafeMutableBytes { outBuf in
                guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return ttzip_rust_snappy_decompress(inBase, inBuf.count, outBase, expectedLength, &actualLength)
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw SnappyError.corruptTag
        }

        decompressedData.count = actualLength
        return decompressedData
    }

    /// Validates integrity of raw Snappy compressed stream without full output materialization.
    public func validate(compressedData: Data) -> Bool {
        guard !compressedData.isEmpty else { return false }
        return compressedData.withUnsafeBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            return ttzip_rust_snappy_validate(base, rawBuffer.count)
        }
    }

    /// Masks CRC32C per Snappy specification: ((crc >> 15) | (crc << 17)) + 0xa282ead8
    public func maskCRC32C(_ crc: UInt32) -> UInt32 {
        return ((crc >> 15) | (crc << 17)) &+ 0xa282ead8
    }

    /// Unmasks CRC32C per Snappy specification.
    public func unmaskCRC32C(_ maskedCRC: UInt32) -> UInt32 {
        let rot = maskedCRC &- 0xa282ead8
        return (rot >> 17) | (rot << 15)
    }
}
