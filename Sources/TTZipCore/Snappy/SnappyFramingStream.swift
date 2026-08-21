// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput streaming framing encoder and decoder for the official Snappy Framing Format (.sz).
///
/// Backed directly by TTZip pure-Rust framing codec engine with Castagnoli CRC-32C validation.
public final class SnappyFramingStream: Sendable {

    public static let shared = SnappyFramingStream()

    public static let streamIdentifier = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59])
    public static let maxChunkRawSize = 65536

    public init() {}

    /// Checks if the data begins with standard Snappy stream identifier (\xFF\x06\x00\x00sNaPpY).
    public func isFramedSnappy(data: Data) -> Bool {
        guard data.count >= Self.streamIdentifier.count else { return false }
        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            return ttzip_rust_snappy_is_framed(base, raw.count)
        }
    }

    /// Encodes arbitrary raw data into official Snappy Framing Format stream (.sz).
    public func encode(data: Data) throws -> Data {
        if data.isEmpty {
            return Self.streamIdentifier
        }

        let maxBound = ttzip_rust_snappy_frame_max_encoded_length(data.count)
        var result = Data(count: maxBound)
        var actualLen = maxBound

        let status: CTTZipBridge.TTZipStatus = data.withUnsafeBytes { inBuf in
            guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return result.withUnsafeMutableBytes { outBuf in
                guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return ttzip_rust_snappy_frame_encode(inBase, inBuf.count, outBase, maxBound, &actualLen)
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw SnappyError.corruptTag
        }

        result.count = actualLen
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

        var decompressed = Data(count: min(maxAllowedSize, max(framedData.count * 4, 65536)))
        var actualLen = decompressed.count
        var status: CTTZipBridge.TTZipStatus = TTZIP_STATUS_OK
        var success = false

        while decompressed.count <= maxAllowedSize {
            actualLen = decompressed.count
            status = framedData.withUnsafeBytes { inBuf in
                guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return decompressed.withUnsafeMutableBytes { outBuf in
                    guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return TTZIP_STATUS_ERR_INVALID_PARAM
                    }
                    return ttzip_rust_snappy_frame_decode(inBase, inBuf.count, outBase, outBuf.count, &actualLen)
                }
            }

            if status == TTZIP_STATUS_OK {
                success = true
                break
            }

            if decompressed.count * 2 > maxAllowedSize {
                if decompressed.count == maxAllowedSize { break }
                decompressed.count = maxAllowedSize
            } else {
                decompressed.count *= 2
            }
        }

        guard success, status == TTZIP_STATUS_OK else {
            throw SnappyError.corruptTag
        }

        decompressed.count = actualLen
        return decompressed
    }

    /// Compresses a file on disk into Snappy framing format (.sz).
    public func compressFile(
        srcPath: String,
        dstPath: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let status = ttzip_rust_snappy_compress_file_stream(srcPath, dstPath, nil, nil)
        return status == TTZIP_STATUS_OK
    }

    /// Decompresses a Snappy framed file on disk (.sz).
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let status = ttzip_rust_snappy_decompress_file_stream(srcPath, dstPath, nil, nil)
        return status == TTZIP_STATUS_OK
    }
}
