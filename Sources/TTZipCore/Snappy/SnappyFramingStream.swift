// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput streaming framing encoder and decoder for the official Snappy Framing Format (.sz).
public final class SnappyFramingStream: Sendable {

    public static let shared = SnappyFramingStream()

    public static let streamIdentifier = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59])

    public init() {}

    /// Checks if the data begins with standard Snappy stream identifier (\xFF\x06\x00\x00sNaPpY).
    public func isFramedSnappy(data: Data) -> Bool {
        guard data.count >= Self.streamIdentifier.count else { return false }
        return data.prefix(Self.streamIdentifier.count) == Self.streamIdentifier
    }

    /// Encodes arbitrary raw data into official Snappy Framing Format stream (.sz).
    public func encode(data: Data) throws -> Data {
        if data.isEmpty {
            return Self.streamIdentifier
        }

        // Upper bound: 10 byte header + (chunks * (4 byte header + 4 byte CRC + max compressed size))
        let numChunks = (data.count + Int(TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) - 1) / Int(TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE)
        let maxOutCapacity = 10 + (numChunks * (8 + Int(TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) + 1024))
        var framedData = Data(count: maxOutCapacity)
        var actualFramedLength = maxOutCapacity

        let status = data.withUnsafeBytes { inBuf -> Int32 in
            guard let inBase = inBuf.baseAddress else { return -1 }
            return framedData.withUnsafeMutableBytes { outBuf -> Int32 in
                guard let outBase = outBuf.baseAddress else { return -1 }
                return ttzip_snappy_framed_compress(inBase, inBuf.count, outBase, &actualFramedLength)
            }
        }

        guard status == TTZIP_SNAPPY_OK.rawValue else {
            if status == TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL.rawValue {
                throw SnappyError.bufferTooSmall
            }
            throw SnappyError.corruptTag
        }

        framedData.count = actualFramedLength
        return framedData
    }

    /// Decodes official Snappy Framing Format stream (.sz) into restored raw data.
    public func decode(framedData: Data, maxAllowedSize: Int = 2_147_483_648) throws -> Data {
        guard !framedData.isEmpty else {
            return Data()
        }

        guard isFramedSnappy(data: framedData) else {
            throw SnappyError.invalidMagicHeader
        }

        // Estimate initial capacity (3x-10x for compression ratio, dynamically resize if needed)
        var estimatedCapacity = max(framedData.count * 4, 1024 * 1024)
        if estimatedCapacity > maxAllowedSize {
            estimatedCapacity = maxAllowedSize
        }

        var decompressedData = Data(count: estimatedCapacity)
        var actualDecompressedLength = estimatedCapacity

        var status = framedData.withUnsafeBytes { inBuf -> Int32 in
            guard let inBase = inBuf.baseAddress else { return -1 }
            return decompressedData.withUnsafeMutableBytes { outBuf -> Int32 in
                guard let outBase = outBuf.baseAddress else { return -1 }
                return ttzip_snappy_framed_decompress(inBase, inBuf.count, outBase, &actualDecompressedLength)
            }
        }

        // If buffer was too small, double capacity up to maxAllowedSize
        while status == TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL.rawValue && estimatedCapacity < maxAllowedSize {
            estimatedCapacity = min(estimatedCapacity * 2, maxAllowedSize)
            decompressedData = Data(count: estimatedCapacity)
            actualDecompressedLength = estimatedCapacity

            status = framedData.withUnsafeBytes { inBuf -> Int32 in
                guard let inBase = inBuf.baseAddress else { return -1 }
                return decompressedData.withUnsafeMutableBytes { outBuf -> Int32 in
                    guard let outBase = outBuf.baseAddress else { return -1 }
                    return ttzip_snappy_framed_decompress(inBase, inBuf.count, outBase, &actualDecompressedLength)
                }
            }
        }

        guard status == TTZIP_SNAPPY_OK.rawValue else {
            switch status {
            case TTZIP_SNAPPY_ERR_INVALID_MAGIC.rawValue:
                throw SnappyError.invalidMagicHeader
            case TTZIP_SNAPPY_ERR_CRC32C_MISMATCH.rawValue:
                throw SnappyError.crc32cMismatch(expected: 0, actual: 0)
            case TTZIP_SNAPPY_ERR_UNSUPPORTED_CHUNK.rawValue:
                throw SnappyError.unsupportedChunkType(0)
            case TTZIP_SNAPPY_ERR_UNEXPECTED_EOF.rawValue:
                throw SnappyError.unexpectedEOF(expected: 0, remaining: 0)
            case TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL.rawValue:
                throw SnappyError.bufferTooSmall
            default:
                throw SnappyError.corruptTag
            }
        }

        decompressedData.count = actualDecompressedLength
        return decompressedData
    }
}
