// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// In-memory random access and checkpoint index table for ZIP archives.
///
/// Enables O(1) single-entry location and range pre-reading without full archive decompression.
public final class ZipSeekTable: @unchecked Sendable {
    
    public struct SeekEntry: Sendable {
        public let path: String
        public let uncompressedSize: Int64
        public let compressedSize: Int64
        public let lfhOffset: Int64
        public let payloadOffset: Int64
        public let compressionMethod: UInt16
        public let crc32: UInt32
        public let isDirectory: Bool
        public let isEncrypted: Bool
    }
    
    private let entriesByPath: [String: SeekEntry]
    public let allEntries: [SeekEntry]
    public let archiveSize: Int
    
    public init(descriptors: [ZipEntryDescriptor], archiveSize: Int, bytePtr: UnsafePointer<UInt8>) {
        self.archiveSize = archiveSize
        var map: [String: SeekEntry] = [:]
        map.reserveCapacity(descriptors.count)
        var list: [SeekEntry] = []
        list.reserveCapacity(descriptors.count)
        
        for desc in descriptors {
            let lfhPos = Int(desc.lfhOffset)
            var payloadOffset = Int64(lfhPos + 30)
            if lfhPos + 30 <= archiveSize {
                var lfhFnLen: UInt16 = 0
                var lfhExtraLen: UInt16 = 0
                memcpy(&lfhFnLen, bytePtr.advanced(by: lfhPos + 26), 2)
                memcpy(&lfhExtraLen, bytePtr.advanced(by: lfhPos + 28), 2)
                payloadOffset = Int64(lfhPos + 30 + Int(lfhFnLen) + Int(lfhExtraLen))
            }
            
            let entry = SeekEntry(
                path: desc.path,
                uncompressedSize: desc.uncompressedSize,
                compressedSize: desc.compressedSize,
                lfhOffset: desc.lfhOffset,
                payloadOffset: payloadOffset,
                compressionMethod: desc.compressionMethod,
                crc32: desc.crc32,
                isDirectory: desc.isDirectory,
                isEncrypted: desc.isEncrypted
            )
            map[desc.path] = entry
            list.append(entry)
        }
        
        self.entriesByPath = map
        self.allEntries = list
    }
    
    /// O(1) entry lookup by relative archive path.
    public func entry(forPath path: String) -> SeekEntry? {
        return entriesByPath[path]
    }
    
    /// Extracts a single entry directly into a Swift `Data` buffer without full extraction overhead.
    public func extractSingleEntry(
        path: String,
        from bytePtr: UnsafePointer<UInt8>,
        fileSize: Int,
        password: String? = nil
    ) -> Data? {
        guard let entry = entry(forPath: path), !entry.isDirectory else { return nil }
        let payloadOff = Int(entry.payloadOffset)
        let compSize = Int(entry.compressedSize)
        guard payloadOff + compSize <= fileSize else { return nil }
        
        let payloadPtr = bytePtr.advanced(by: payloadOff)
        
        if entry.isEncrypted {
            guard let pwd = password, !pwd.isEmpty else { return nil }
            if entry.compressionMethod == 0 {
                return ZipCryptoEngine.shared.decryptAES256(payloadPtr: payloadPtr, count: compSize, password: pwd)
            } else {
                guard let decrypted = ZipCryptoEngine.shared.decryptAES256(payloadPtr: payloadPtr, count: compSize, password: pwd) else { return nil }
                let targetSize = Int(entry.uncompressedSize)
                let rawDst = UnsafeMutablePointer<UInt8>.allocate(capacity: targetSize)
                let uncompSize = decrypted.withUnsafeBytes { inBuf -> size_t in
                    guard let src = inBuf.baseAddress else { return 0 }
                    return ttzip_libdeflate_decompress(src, decrypted.count, rawDst, targetSize)
                }
                if uncompSize == entry.uncompressedSize {
                    return Data(bytesNoCopy: rawDst, count: targetSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
                } else {
                    rawDst.deallocate()
                    return nil
                }
            }
        }
        
        if entry.compressionMethod == 0 {
            return Data(bytes: payloadPtr, count: compSize)
        } else if entry.compressionMethod == 8 {
            let targetSize = Int(entry.uncompressedSize)
            let rawDst = UnsafeMutablePointer<UInt8>.allocate(capacity: targetSize)
            let uncompSize = ttzip_libdeflate_decompress(payloadPtr, compSize, rawDst, targetSize)
            if uncompSize == entry.uncompressedSize {
                return Data(bytesNoCopy: rawDst, count: targetSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
            } else {
                rawDst.deallocate()
                return nil
            }
        }
        return nil
    }
}
