// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

private final class SevenZipDescriptorAccumulator: @unchecked Sendable {
    var descriptors: [SevenZipEntryDescriptor] = []
}

/// Zero-copy `mmap` and streaming parser for 7z 32-byte Signature Header and authentic Entry Descriptors.
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
    
    /// Parses authentic 7z header descriptors from an archive file path.
    public func readDescriptors(archivePath: String, password: String? = nil) -> [SevenZipEntryDescriptor]? {
        let accumulator = SevenZipDescriptorAccumulator()
        let contextPtr = Unmanaged.passUnretained(accumulator).toOpaque()
        
        let status = withExtendedLifetime(accumulator) {
            CUnsafeBufferAdapter.withCString(archivePath) { cPath in
                CUnsafeBufferAdapter.withCString(password) { cPwd in
                    guard let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    return ttzip_rust_inspect_archive(cPath, cPwd, true, { entryPtr, ctx in
                        guard let entry = entryPtr?.pointee, let ctx = ctx else { return false }
                        let acc = Unmanaged<SevenZipDescriptorAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                        let pathStr = entry.path != nil ? String(cString: entry.path!) : ""
                        let lastComp = (pathStr as NSString).lastPathComponent
                        if lastComp.hasPrefix("._") || lastComp == ".DS_Store" { return true }
                        
                        acc.descriptors.append(SevenZipEntryDescriptor(
                            path: pathStr,
                            isDirectory: entry.is_directory,
                            compressedSize: Int64(entry.compressed_size),
                            uncompressedSize: Int64(entry.uncompressed_size),
                            packOffset: 0,
                            crc32: entry.crc32,
                            isEncrypted: entry.is_encrypted,
                            folderIndex: 0
                        ))
                        return true
                    }, contextPtr)
                }
            }
        }
        
        if status == TTZIP_STATUS_OK {
            return accumulator.descriptors
        }
        return nil
    }
    
    /// Parses authentic 7z header descriptors from mapped buffer.
    public func readDescriptors(from bytePtr: UnsafePointer<UInt8>, fileSize: Int) -> [SevenZipEntryDescriptor]? {
        guard let _ = parseSignatureHeader(from: bytePtr, fileSize: fileSize) else { return nil }
        
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_hdr_\(UUID().uuidString).7z")
        let data = Data(bytes: bytePtr, count: fileSize)
        do {
            try data.write(to: tempUrl)
            defer { try? FileManager.default.removeItem(at: tempUrl) }
            return readDescriptors(archivePath: tempUrl.path)
        } catch {
            return nil
        }
    }
}
