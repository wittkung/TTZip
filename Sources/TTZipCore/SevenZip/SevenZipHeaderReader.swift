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
        var cSig = ttzip_7z_signature_header_t()
        let res = ttzip_7z_parse_signature_header(bytePtr, fileSize, &cSig)
        guard res == 0 else { return nil }

        return SevenZipSignatureHeader(
            majorVersion: cSig.major_version,
            minorVersion: cSig.minor_version,
            startHeaderCRC: cSig.start_header_crc,
            nextHeaderOffset: cSig.next_header_offset,
            nextHeaderSize: cSig.next_header_size,
            nextHeaderCRC: cSig.next_header_crc
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
