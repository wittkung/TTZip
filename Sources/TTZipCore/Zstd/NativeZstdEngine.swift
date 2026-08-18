// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance native Zstandard (.zst) codec engine for Apple Silicon architectures.
public final class NativeZstdEngine: @unchecked Sendable {
    public static let shared = NativeZstdEngine()
    
    private init() {}
    
    /// RFC 8878 Zstandard magic number (0xFD2FB528, Little-Endian: 0x28, 0xB5, 0x2F, 0xFD).
    public static let zstdMagicNumber: UInt32 = 0xFD2FB528
    
    /// Validates whether a file conforms to standard Zstandard frame or skippable frame.
    public func isValidZstdFrame(atPath filePath: String) -> Bool {
        return ZstdHeaderReader.shared.readFrameDescriptor(filePath: filePath) != nil
    }
    
    /// Parses RFC 8878 Zstandard frame descriptor.
    public func inspectFrame(atPath filePath: String) -> ZstdFrameDescriptor? {
        return ZstdHeaderReader.shared.readFrameDescriptor(filePath: filePath)
    }
    
    /// Stream-compresses a file using Zstandard algorithm with optional Long Distance Matching (LDM).
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdStreamWriter.shared.compress(
            srcPath: srcPath,
            dstPath: dstPath,
            level: level,
            enableLDM: enableLDM,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
    
    /// Stream-decompresses a Zstandard archive container.
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdStreamExtractor.shared.decompress(
            srcPath: srcPath,
            dstPath: dstPath,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
}
