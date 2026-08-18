// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// RFC 8878 Zstandard (.zst) frame header structure.
public struct ZstdFrameDescriptor: Sendable {
    public let magicNumber: UInt32
    public let isSkippableFrame: Bool
    public let frameContentSizeBytes: UInt64?
    public let windowSizeBytes: UInt64
    public let hasChecksum: Bool
    public let dictionaryID: UInt32?
}

/// RFC 8878 Zstandard frame parser and metadata extractor.
public final class ZstdHeaderReader: @unchecked Sendable {
    public static let shared = ZstdHeaderReader()
    
    public static let zstdMagicNumber: UInt32 = 0xFD2FB528
    
    private init() {}
    
    /// Parses Zstandard frame descriptor from file.
    public func readFrameDescriptor(filePath: String) -> ZstdFrameDescriptor? {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handle.close() }
        
        guard let headerData = try? handle.read(upToCount: 18), headerData.count >= 4 else { return nil }
        return headerData.withUnsafeBytes { ptr -> ZstdFrameDescriptor? in
            guard let base = ptr.baseAddress else { return nil }
            return readFrameDescriptor(from: base.assumingMemoryBound(to: UInt8.self), length: headerData.count)
        }
    }
    
    /// Parses RFC 8878 Zstd frame descriptor from raw memory buffer.
    public func readFrameDescriptor(from buffer: UnsafePointer<UInt8>, length: Int) -> ZstdFrameDescriptor? {
        if length < 4 { return nil }
        
        var magic: UInt32 = 0
        memcpy(&magic, buffer, 4)
        let magicLE = UInt32(littleEndian: magic)
        
        // 1. Skippable Frames (0x184D2A50 ... 0x184D2A5F)
        if magicLE >= 0x184D2A50 && magicLE <= 0x184D2A5F {
            var skippableSize: UInt32 = 0
            if length >= 8 {
                memcpy(&skippableSize, buffer.advanced(by: 4), 4)
                skippableSize = UInt32(littleEndian: skippableSize)
            }
            return ZstdFrameDescriptor(
                magicNumber: magicLE,
                isSkippableFrame: true,
                frameContentSizeBytes: UInt64(skippableSize),
                windowSizeBytes: 0,
                hasChecksum: false,
                dictionaryID: nil
            )
        }
        
        // 2. Standard Zstandard frame magic
        guard magicLE == Self.zstdMagicNumber else { return nil }
        if length < 5 { return nil }
        
        let fhd = buffer[4]
        let dictIDFlag = fhd & 0x03
        let checksumFlag = ((fhd >> 2) & 0x01) != 0
        let singleSegmentFlag = ((fhd >> 5) & 0x01) != 0
        let fcsFlag = (fhd >> 6) & 0x03
        
        var offset = 5
        var windowSize: UInt64 = 0
        
        if !singleSegmentFlag {
            if length <= offset { return nil }
            let windowByte = buffer[offset]
            offset += 1
            let exponent = UInt64((windowByte >> 3) & 0x1F)
            let mantissa = UInt64(windowByte & 0x07)
            let baseWin = UInt64(1) << (exponent + 10)
            windowSize = baseWin + (mantissa * baseWin / 8)
        }
        
        var dictID: UInt32? = nil
        if dictIDFlag == 1 {
            if length >= offset + 1 { dictID = UInt32(buffer[offset]); offset += 1 }
        } else if dictIDFlag == 2 {
            if length >= offset + 2 {
                var d16: UInt16 = 0
                memcpy(&d16, buffer.advanced(by: offset), 2)
                dictID = UInt32(UInt16(littleEndian: d16))
                offset += 2
            }
        } else if dictIDFlag == 3 {
            if length >= offset + 4 {
                var d32: UInt32 = 0
                memcpy(&d32, buffer.advanced(by: offset), 4)
                dictID = UInt32(littleEndian: d32)
                offset += 4
            }
        }
        
        var contentSize: UInt64? = nil
        if fcsFlag == 1 {
            if length >= offset + 1 {
                contentSize = UInt64(buffer[offset]) + 256
                offset += 1
            }
        } else if fcsFlag == 2 {
            if length >= offset + 2 {
                var s16: UInt16 = 0
                memcpy(&s16, buffer.advanced(by: offset), 2)
                contentSize = UInt64(UInt16(littleEndian: s16))
                offset += 2
            }
        } else if fcsFlag == 3 {
            if length >= offset + 8 {
                var s64: UInt64 = 0
                memcpy(&s64, buffer.advanced(by: offset), 8)
                contentSize = UInt64(littleEndian: s64)
                offset += 8
            }
        }
        
        if singleSegmentFlag && contentSize != nil {
            windowSize = contentSize!
        }
        
        return ZstdFrameDescriptor(
            magicNumber: magicLE,
            isSkippableFrame: false,
            frameContentSizeBytes: contentSize,
            windowSizeBytes: windowSize,
            hasChecksum: checksumFlag,
            dictionaryID: dictID
        )
    }
}
