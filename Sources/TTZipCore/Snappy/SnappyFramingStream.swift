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
    public static let maxChunkRawSize = 65536

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

        var result = Self.streamIdentifier
        var offset = 0
        let total = data.count

        while offset < total {
            let chunkSize = min(Self.maxChunkRawSize, total - offset)
            let chunkData = data.subdata(in: offset..<(offset + chunkSize))
            offset += chunkSize

            let rawCrc: UInt32 = chunkData.withUnsafeBytes { ptr -> UInt32 in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return ttzip_rust_crc32(0, base, chunkData.count)
            }
            let crc = SnappyBlockEngine.shared.maskCRC32C(rawCrc)
            let compressed = try SnappyBlockEngine.shared.compress(data: chunkData)

            if compressed.count < chunkData.count {
                // Type 0x00: Compressed chunk
                let length = compressed.count + 4
                result.append(0x00)
                result.append(UInt8(truncatingIfNeeded: length & 0xFF))
                result.append(UInt8(truncatingIfNeeded: (length >> 8) & 0xFF))
                result.append(UInt8(truncatingIfNeeded: (length >> 16) & 0xFF))
                var crcLE = crc.littleEndian
                withUnsafeBytes(of: &crcLE) { result.append(contentsOf: $0) }
                result.append(compressed)
            } else {
                // Type 0x01: Uncompressed chunk
                let length = chunkData.count + 4
                result.append(0x01)
                result.append(UInt8(truncatingIfNeeded: length & 0xFF))
                result.append(UInt8(truncatingIfNeeded: (length >> 8) & 0xFF))
                result.append(UInt8(truncatingIfNeeded: (length >> 16) & 0xFF))
                var crcLE = crc.littleEndian
                withUnsafeBytes(of: &crcLE) { result.append(contentsOf: $0) }
                result.append(chunkData)
            }
        }

        return result
    }

    /// Decodes official Snappy Framing Format stream (.sz) into restored raw data.
    public func decode(framedData: Data, maxAllowedSize: Int = 2_147_483_648) throws -> Data {
        guard !framedData.isEmpty else {
            return Data()
        }

        guard isFramedSnappy(data: framedData) else {
            throw SnappyError.invalidMagicHeader
        }

        var result = Data()
        var offset = Self.streamIdentifier.count
        let total = framedData.count

        while offset + 4 <= total {
            let chunkType = framedData[offset]
            let b1 = Int(framedData[offset + 1])
            let b2 = Int(framedData[offset + 2])
            let b3 = Int(framedData[offset + 3])
            let chunkLen = b1 | (b2 << 8) | (b3 << 16)
            offset += 4

            guard offset + chunkLen <= total else {
                throw SnappyError.unexpectedEOF(expected: chunkLen, remaining: total - offset)
            }

            let chunkPayload = framedData.subdata(in: offset..<(offset + chunkLen))
            offset += chunkLen

            switch chunkType {
            case 0xFF: // Stream identifier
                continue
            case 0xFE: // Padding
                continue
            case 0x00: // Compressed data
                guard chunkPayload.count >= 4 else { throw SnappyError.corruptTag }
                let compData = chunkPayload.subdata(in: 4..<chunkPayload.count)
                let decomp = try SnappyBlockEngine.shared.decompress(compressedData: compData, maxAllowedSize: maxAllowedSize)
                if result.count + decomp.count > maxAllowedSize {
                    throw SnappyError.decompressedSizeExceeded(maxAllowed: maxAllowedSize, actual: result.count + decomp.count)
                }
                result.append(decomp)
            case 0x01: // Uncompressed data
                guard chunkPayload.count >= 4 else { throw SnappyError.corruptTag }
                let rawData = chunkPayload.subdata(in: 4..<chunkPayload.count)
                if result.count + rawData.count > maxAllowedSize {
                    throw SnappyError.decompressedSizeExceeded(maxAllowed: maxAllowedSize, actual: result.count + rawData.count)
                }
                result.append(rawData)
            default:
                if chunkType >= 0x02 && chunkType <= 0x7F {
                    throw SnappyError.unsupportedChunkType(chunkType)
                }
                // Skip skippable chunk types (0x80..0xFD)
            }
        }

        return result
    }
}
