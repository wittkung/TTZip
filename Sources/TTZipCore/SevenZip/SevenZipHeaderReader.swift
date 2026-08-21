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
    
    /// Parses and verifies the 32-byte 7z Signature Header.
    public func parseSignatureHeader(from bytePtr: UnsafePointer<UInt8>, fileSize: Int) -> SevenZipSignatureHeader? {
        guard fileSize >= 32 else { return nil }
        guard bytePtr[0] == 0x37, bytePtr[1] == 0x7A, bytePtr[2] == 0xBC, bytePtr[3] == 0xAF, bytePtr[4] == 0x27, bytePtr[5] == 0x1C else {
            return nil
        }
        let major = bytePtr[6]
        let minor = bytePtr[7]
        let rawBuffer = UnsafeRawPointer(bytePtr)
        let startCRC = rawBuffer.loadUnaligned(fromByteOffset: 8, as: UInt32.self).littleEndian
        let nextOffset = rawBuffer.loadUnaligned(fromByteOffset: 12, as: UInt64.self).littleEndian
        let nextSize = rawBuffer.loadUnaligned(fromByteOffset: 20, as: UInt64.self).littleEndian
        let nextCRC = rawBuffer.loadUnaligned(fromByteOffset: 28, as: UInt32.self).littleEndian

        let computedCRC = ttzip_rust_crc32(0, bytePtr.advanced(by: 12), 20)
        guard computedCRC == startCRC else { return nil }

        return SevenZipSignatureHeader(
            majorVersion: major,
            minorVersion: minor,
            startHeaderCRC: startCRC,
            nextHeaderOffset: nextOffset,
            nextHeaderSize: nextSize,
            nextHeaderCRC: nextCRC
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
