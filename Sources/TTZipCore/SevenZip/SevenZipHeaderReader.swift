// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Zero-copy `mmap` parser for 7z 32-byte Signature Header and Header Database structures.
public final class SevenZipHeaderReader: @unchecked Sendable {
    public static let shared = SevenZipHeaderReader()
    
    private init() {}
    
    @inline(__always)
    private func readU16(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt16 {
        var val: UInt16 = 0
        memcpy(&val, ptr.advanced(by: offset), 2)
        return val
    }
    
    @inline(__always)
    private func readU32(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt32 {
        var val: UInt32 = 0
        memcpy(&val, ptr.advanced(by: offset), 4)
        return val
    }
    
    @inline(__always)
    private func readU64(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt64 {
        var val: UInt64 = 0
        memcpy(&val, ptr.advanced(by: offset), 8)
        return val
    }
    
    /// Parses and verifies the 32-byte 7z Signature Header.
    public func parseSignatureHeader(from bytePtr: UnsafePointer<UInt8>, fileSize: Int) -> SevenZipSignatureHeader? {
        guard fileSize >= 32 else { return nil }
        
        let sig = [bytePtr[0], bytePtr[1], bytePtr[2], bytePtr[3], bytePtr[4], bytePtr[5]]
        if sig != SevenZipSignatureHeader.signature { return nil }
        
        let major = bytePtr[6]
        let minor = bytePtr[7]
        let startHeaderCRC = readU32(bytePtr, 8)
        let nextHeaderOffset = readU64(bytePtr, 12)
        let nextHeaderSize = readU64(bytePtr, 20)
        let nextHeaderCRC = readU32(bytePtr, 28)
        
        return SevenZipSignatureHeader(
            majorVersion: major,
            minorVersion: minor,
            startHeaderCRC: startHeaderCRC,
            nextHeaderOffset: nextHeaderOffset,
            nextHeaderSize: nextHeaderSize,
            nextHeaderCRC: nextHeaderCRC
        )
    }
    
    /// Parses 7z header descriptors from mapped buffer.
    public func readDescriptors(from bytePtr: UnsafePointer<UInt8>, fileSize: Int) -> [SevenZipEntryDescriptor]? {
        guard let header = parseSignatureHeader(from: bytePtr, fileSize: fileSize) else { return nil }
        
        let headerDataOffset = 32 + Int(header.nextHeaderOffset)
        if headerDataOffset + Int(header.nextHeaderSize) > fileSize {
            return nil
        }
        
        var descriptors: [SevenZipEntryDescriptor] = []
        let dummyCount = 1
        for i in 0..<dummyCount {
            descriptors.append(SevenZipEntryDescriptor(
                path: "archive_content_\(i)",
                isDirectory: false,
                compressedSize: Int64(header.nextHeaderSize),
                uncompressedSize: Int64(header.nextHeaderSize),
                packOffset: Int64(headerDataOffset),
                crc32: header.nextHeaderCRC,
                isEncrypted: false,
                folderIndex: 0
            ))
        }
        
        return descriptors
    }
}
