// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput unified memory buffer-to-buffer ZIP codec engine (30+ GB/s).
public final class ZipMemoryEngine: @unchecked Sendable {
    public static let shared = ZipMemoryEngine()
    
    private init() {}
    
    /// In-memory zero-copy parallel ZIP decompression without filesystem I/O overhead.
    public func extractInMemory(archiveData: Data) -> [(path: String, data: Data)]? {
        return archiveData.withUnsafeBytes { rawIn in
            guard let bytePtr = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let fileSize = archiveData.count
            
            guard let descriptors = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize, skipMacJunk: true) else {
                return nil
            }
            
            let fileDescriptors = descriptors.filter { !$0.isDirectory }
            let resultsBox = StateBoxResults([(path: String, data: Data)?](repeating: nil, count: fileDescriptors.count))
            let pointerBox = SendablePointerBox(pointer: bytePtr, size: fileSize)
            
            ConcurrencyBridge.parallelFor(iterations: fileDescriptors.count) { idx in
                let desc = fileDescriptors[idx]
                let lfhPos = Int(desc.lfhOffset)
                let currentBytePtr = pointerBox.pointer
                
                if lfhPos + 30 > pointerBox.size { return }
                var fnLenVal: UInt16 = 0
                var extraLenVal: UInt16 = 0
                memcpy(&fnLenVal, currentBytePtr.advanced(by: lfhPos + 26), 2)
                memcpy(&extraLenVal, currentBytePtr.advanced(by: lfhPos + 28), 2)
                let lfhFnLen = Int(fnLenVal)
                let lfhExtraLen = Int(extraLenVal)
                
                let payloadOffset = lfhPos + 30 + lfhFnLen + lfhExtraLen
                if payloadOffset + Int(desc.compressedSize) > pointerBox.size { return }
                
                let payloadPtr = currentBytePtr.advanced(by: payloadOffset)
                
                if desc.compressionMethod == 0 { // Store
                    let outData = Data(bytes: payloadPtr, count: Int(desc.compressedSize))
                    resultsBox.set(idx: idx, res: (path: desc.path, data: outData))
                } else if desc.compressionMethod == 8 { // Deflate
                    let uncompSize = Int(desc.uncompressedSize)
                    let rawDst = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompSize)
                    let decompSize = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), rawDst, uncompSize)
                    if decompSize == desc.uncompressedSize {
                        let outData = Data(bytesNoCopy: rawDst, count: uncompSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
                        resultsBox.set(idx: idx, res: (path: desc.path, data: outData))
                    } else {
                        rawDst.deallocate()
                    }
                }
            }
            
            return resultsBox.values.compactMap { $0 }
        }
    }
    
    /// In-memory zero-copy parallel ZIP decompression from `MmapBufferHandle`.
    public func extractInMemory(handle: MmapBufferHandle) -> [(path: String, data: Data)]? {
        guard let bytePtr = handle.bytes.baseAddress else { return nil }
        let fileSize = handle.count
        
        guard let descriptors = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize, skipMacJunk: true) else {
            return nil
        }
        
        let fileDescriptors = descriptors.filter { !$0.isDirectory }
        let resultsBox = StateBoxResults([(path: String, data: Data)?](repeating: nil, count: fileDescriptors.count))
        
        ConcurrencyBridge.parallelFor(iterations: fileDescriptors.count) { idx in
            let desc = fileDescriptors[idx]
            let lfhPos = Int(desc.lfhOffset)
            
            if lfhPos + 30 > handle.count { return }
            guard let headerSlice = handle.slice(offset: lfhPos + 26, length: 4),
                  let headerPtr = headerSlice.baseAddress else { return }
            
            var fnLenVal: UInt16 = 0
            var extraLenVal: UInt16 = 0
            memcpy(&fnLenVal, headerPtr, 2)
            memcpy(&extraLenVal, headerPtr.advanced(by: 2), 2)
            let lfhFnLen = Int(fnLenVal)
            let lfhExtraLen = Int(extraLenVal)
            
            let payloadOffset = lfhPos + 30 + lfhFnLen + lfhExtraLen
            if payloadOffset + Int(desc.compressedSize) > handle.count { return }
            
            guard let payloadSlice = handle.slice(offset: payloadOffset, length: Int(desc.compressedSize)),
                  let payloadPtr = payloadSlice.baseAddress else { return }

            if desc.compressionMethod == 0 { // Store
                let outData = Data(bytes: payloadPtr, count: Int(desc.compressedSize))
                resultsBox.set(idx: idx, res: (path: desc.path, data: outData))
            } else if desc.compressionMethod == 8 { // Deflate
                let uncompSize = Int(desc.uncompressedSize)
                let rawDst = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompSize)
                let decompSize = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), rawDst, uncompSize)
                if decompSize == desc.uncompressedSize {
                    let outData = Data(bytesNoCopy: rawDst, count: uncompSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
                    resultsBox.set(idx: idx, res: (path: desc.path, data: outData))
                } else {
                    rawDst.deallocate()
                }
            }
        }
        
        return resultsBox.values.compactMap { $0 }
    }
}
