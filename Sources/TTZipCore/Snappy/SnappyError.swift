// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Strongly typed error model for Snappy block and framing stream operations.
public enum SnappyError: Error, LocalizedError, Equatable, Sendable {
    case invalidMagicHeader
    case corruptVarint
    case corruptTag
    case offsetOutOfBounds(offset: UInt32, available: Int)
    case literalLengthExceeded(requested: Int, available: Int)
    case bufferTooSmall
    case crc32cMismatch(expected: UInt32, actual: UInt32)
    case unsupportedChunkType(UInt8)
    case unexpectedEOF(expected: Int, remaining: Int)
    case invalidParameter
    case ioError(String)
    case decompressedSizeExceeded(maxAllowed: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidMagicHeader:
            return "Invalid Snappy stream identifier or magic header mismatch."
        case .corruptVarint:
            return "Corrupted or non-terminating Varint32 length prefix."
        case .corruptTag:
            return "Corrupted Snappy element tag byte or invalid payload."
        case .offsetOutOfBounds(let offset, let available):
            return "Snappy copy offset out of bounds: offset=\(offset), available=\(available)."
        case .literalLengthExceeded(let req, let avail):
            return "Literal length exceeded buffer boundary: requested=\(req), available=\(avail)."
        case .bufferTooSmall:
            return "Destination buffer is too small for uncompressed or compressed payload."
        case .crc32cMismatch(let expected, let actual):
            return "Snappy Castagnoli CRC32C checksum mismatch: expected=0x\(String(expected, radix: 16)), actual=0x\(String(actual, radix: 16))."
        case .unsupportedChunkType(let type):
            return "Unsupported unskippable Snappy chunk type: 0x\(String(type, radix: 16))."
        case .unexpectedEOF(let expected, let remaining):
            return "Unexpected end of Snappy stream: expected=\(expected) bytes, remaining=\(remaining) bytes."
        case .invalidParameter:
            return "Invalid parameter or null pointer passed to Snappy engine."
        case .ioError(let msg):
            return "Snappy I/O operation failed: \(msg)."
        case .decompressedSizeExceeded(let maxAllowed, let actual):
            return "Decompressed size \(actual) bytes exceeded maximum allowed limit of \(maxAllowed) bytes."
        }
    }
}
