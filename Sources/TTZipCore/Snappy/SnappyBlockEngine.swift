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
        return ttzip_snappy_is_available()
    }

    /// Computes upper bound on compressed bytes for a given raw input size.
    public func maxCompressedLength(for sourceLength: Int) -> Int {
        guard sourceLength >= 0 else { return 32 }
        return ttzip_snappy_max_compressed_length(sourceLength)
    }

    /// Parses uncompressed length from Varint32 header.
    public func uncompressedLength(of compressedData: Data) throws -> Int {
        guard !compressedData.isEmpty else {
            throw SnappyError.corruptVarint
        }

        var resultLength: Int = 0
        let status = compressedData.withUnsafeBytes { rawBuffer -> Int32 in
            guard let baseAddress = rawBuffer.baseAddress else { return -1 }
            return ttzip_snappy_uncompressed_length(baseAddress, rawBuffer.count, &resultLength)
        }

        guard status == TTZIP_SNAPPY_OK.rawValue else {
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

        let status = data.withUnsafeBytes { inBuf -> Int32 in
            guard let inBase = inBuf.baseAddress else { return -1 }
            return compressedData.withUnsafeMutableBytes { outBuf -> Int32 in
                guard let outBase = outBuf.baseAddress else { return -1 }
                return ttzip_snappy_compress(inBase, inBuf.count, outBase, &actualCompressedLength)
            }
        }

        guard status == TTZIP_SNAPPY_OK.rawValue else {
            if status == TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL.rawValue {
                throw SnappyError.bufferTooSmall
            }
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

        let status = compressedData.withUnsafeBytes { inBuf -> Int32 in
            guard let inBase = inBuf.baseAddress else { return -1 }
            return decompressedData.withUnsafeMutableBytes { outBuf -> Int32 in
                guard let outBase = outBuf.baseAddress else { return -1 }
                return ttzip_snappy_decompress(inBase, inBuf.count, outBase, &actualLength)
            }
        }

        guard status == TTZIP_SNAPPY_OK.rawValue else {
            if status == TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL.rawValue {
                throw SnappyError.bufferTooSmall
            } else if status == TTZIP_SNAPPY_ERR_OFFSET_OUT_OF_BOUNDS.rawValue {
                throw SnappyError.offsetOutOfBounds(offset: 0, available: 0)
            }
            throw SnappyError.corruptTag
        }

        decompressedData.count = actualLength
        return decompressedData
    }

    /// Validates integrity of raw Snappy compressed stream without full output materialization.
    public func validate(compressedData: Data) -> Bool {
        guard !compressedData.isEmpty else { return false }
        return compressedData.withUnsafeBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress else { return false }
            return ttzip_snappy_validate(base, rawBuffer.count) == TTZIP_SNAPPY_OK.rawValue
        }
    }

    /// Calculates Castagnoli CRC32C with ARM64 ACLE hardware acceleration.
    public func crc32c(data: Data, seed: UInt32 = 0) -> UInt32 {
        guard !data.isEmpty else { return seed }
        return data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return seed }
            return ttzip_snappy_crc32c(seed, base, rawBuf.count)
        }
    }

    /// Masks CRC32C per Snappy specification: ((crc >> 15) | (crc << 17)) + 0xa282ead8
    public func maskCRC32C(_ crc: UInt32) -> UInt32 {
        return ttzip_snappy_mask_crc32c(crc)
    }

    /// Unmasks CRC32C per Snappy specification.
    public func unmaskCRC32C(_ maskedCRC: UInt32) -> UInt32 {
        return ttzip_snappy_unmask_crc32c(maskedCRC)
    }
}
