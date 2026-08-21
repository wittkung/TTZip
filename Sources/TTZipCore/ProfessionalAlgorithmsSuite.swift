// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// LZ4 microsecond in-memory codec engine for game assets, memory dumps, and real-time buffers.
public final class LZ4LzoEngine: @unchecked Sendable {
    public init() {}
    
    public func compressBound(for rawSize: Int) -> Int {
        guard rawSize > 0 else { return 0 }
        return rawSize + (rawSize / 255) + 16
    }
    
    public func compress(data: Data, acceleration: Int = 1) -> Data {
        guard !data.isEmpty else { return Data() }
        let maxCapacity = max(compressBound(for: data.count), data.count + (data.count / 255) + 16)
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxCapacity)
        var written: Int = 0
        
        let status = data.withUnsafeBytes { srcPtr -> CTTZipBridge.TTZipStatus in
            guard let base = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return CTTZipBridge.TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_lz4_compress(base, data.count, dstPtr, maxCapacity, &written)
        }
        
        guard status == CTTZipBridge.TTZIP_STATUS_OK && written > 0 else {
            dstPtr.deallocate()
            return data
        }
        return Data(bytesNoCopy: dstPtr, count: written, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
    
    public func compressWithTLS(data: Data, acceleration: Int = 1) -> Data {
        return compress(data: data, acceleration: acceleration)
    }
    
    public func decompress(data: Data, originalSizeHint: Int? = nil) -> Data {
        guard !data.isEmpty else { return Data() }
        let capacity = originalSizeHint ?? (data.count * 4 + 65536)
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        var written: Int = 0
        
        let status = data.withUnsafeBytes { srcPtr -> CTTZipBridge.TTZipStatus in
            guard let base = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return CTTZipBridge.TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_lz4_decompress(base, data.count, dstPtr, capacity, &written)
        }
        
        guard status == CTTZipBridge.TTZIP_STATUS_OK && written > 0 else {
            dstPtr.deallocate()
            return Data()
        }
        return Data(bytesNoCopy: dstPtr, count: written, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
    
    public func decompressPartial(data: Data, targetSize: Int, dstCapacity: Int? = nil) -> Data {
        return decompress(data: data, originalSizeHint: targetSize)
    }
}

/// Zstandard high-throughput in-process direct binding engine.
public final class ZstdDictionaryEngine: @unchecked Sendable {
    private var compressionLevel: Int32
    
    public init(compressionLevel: Int = 3) {
        self.compressionLevel = Int32(compressionLevel)
    }
    
    public func compressPayload(data: Data) -> Data {
        guard !data.isEmpty else { return Data() }
        let capacity = data.count + (data.count / 16) + 512
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        var written: Int = 0
        
        let status = data.withUnsafeBytes { srcPtr -> CTTZipBridge.TTZipStatus in
            guard let base = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return CTTZipBridge.TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_zstd_compress(base, data.count, dstPtr, capacity, compressionLevel, &written)
        }
        
        guard status == CTTZipBridge.TTZIP_STATUS_OK && written > 0 else {
            dstPtr.deallocate()
            return data
        }
        return Data(bytesNoCopy: dstPtr, count: written, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
    
    public func decompressPayload(data: Data, uncompressedCapacityHint: Int? = nil) throws -> Data {
        guard !data.isEmpty else { return Data() }
        let capacity = uncompressedCapacityHint ?? (data.count * 4 + 65536)
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        var written: Int = 0
        
        let status = data.withUnsafeBytes { srcPtr -> CTTZipBridge.TTZipStatus in
            guard let base = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return CTTZipBridge.TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_zstd_decompress(base, data.count, dstPtr, capacity, &written)
        }
        
        guard status == CTTZipBridge.TTZIP_STATUS_OK && written > 0 else {
            dstPtr.deallocate()
            throw ArchiveError.readFailed(code: -503)
        }
        return Data(bytesNoCopy: dstPtr, count: written, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
}

/// First-order delta / RLE numerical pre-filter for entropy minimization.
public final class DeltaRLEFilter: @unchecked Sendable {
    public init() {}
    
    /// Converts numeric byte sequence into first-order differential delta stream.
    public func applyDeltaFilter(data: Data) -> Data {
        guard !data.isEmpty else { return data }
        let count = data.count
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        
        data.withUnsafeBytes { srcBytes in
            guard let src = srcBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            dstPtr[0] = src[0]
            for i in 1..<count {
                dstPtr[i] = UInt8(truncatingIfNeeded: Int(src[i]) - Int(src[i - 1]))
            }
        }
        return Data(bytesNoCopy: dstPtr, count: count, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
    
    /// Reverses first-order differential delta stream back into original bytes.
    public func removeDeltaFilter(data: Data) -> Data {
        guard !data.isEmpty else { return data }
        let count = data.count
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        
        data.withUnsafeBytes { srcBytes in
            guard let src = srcBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            dstPtr[0] = src[0]
            for i in 1..<count {
                let prev = Int(dstPtr[i - 1])
                let diff = Int(Int8(bitPattern: src[i]))
                dstPtr[i] = UInt8(truncatingIfNeeded: prev + diff)
            }
        }
        return Data(bytesNoCopy: dstPtr, count: count, deallocator: .custom { ptr, _ in ptr.deallocate() })
    }
}
