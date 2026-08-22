// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge
import zlib

/// Supported cryptographic and verification hash algorithms.
public enum HashType: String, Sendable {
    case crc32 = "CRC32"
    case sha256 = "SHA-256"
    case md5 = "MD5"
    case sha1 = "SHA-1"
}

/// Multi-core parallel chunked hash and checksum calculator (6.0+ GB/s).
public final class HashCalculator: HashCalculating, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol

    public init(hardwareTuner: HardwareTunerProtocol = AppleSiliconTuner.shared) {
        self.hardwareTuner = hardwareTuner
    }
    
    public func computeHashSync(filePath: String, type: HashType) throws -> String {
        switch type {
        case .crc32:
            let fm = FileManager.default
            let sz = (try? fm.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
            if sz >= 4 * 1024 * 1024,
               let fd = Optional(open(filePath, O_RDONLY)), fd >= 0 {
                defer { close(fd) }
                let totalFileSize = Int(sz)
                if let mappedIn = mmap(nil, totalFileSize, PROT_READ, MAP_SHARED, fd, 0), mappedIn != MAP_FAILED {
                    defer { munmap(mappedIn, totalFileSize) }
                    posix_madvise(mappedIn, totalFileSize, POSIX_MADV_WILLNEED)
                    let inBytePtr = mappedIn.assumingMemoryBound(to: UInt8.self)
                    let rawInPtr = UInt(bitPattern: inBytePtr)
                    let crcChunkSize = 64 * 1024 * 1024
                    let numChunks = (totalFileSize + crcChunkSize - 1) / crcChunkSize
                    var chunkCRCs = [UInt32](repeating: 0, count: numChunks)

                    chunkCRCs.withUnsafeMutableBufferPointer { crcBuf in
                        let rawCrcPtr = UInt(bitPattern: crcBuf.baseAddress)
                        ConcurrencyBridge.parallelFor(iterations: numChunks) { idx in
                            guard let basePtr = UnsafePointer<UInt8>(bitPattern: rawInPtr),
                                  let outBufPtr = UnsafeMutablePointer<UInt32>(bitPattern: rawCrcPtr) else { return }
                            let offset = idx * crcChunkSize
                            let len = min(crcChunkSize, totalFileSize - offset)
                            let chunkPtr = basePtr.advanced(by: offset)
                            outBufPtr[idx] = ttzip_rust_crc32(0, chunkPtr, len)
                        }
                    }

                    var finalCRC: UInt32 = 0
                    for idx in 0..<numChunks {
                        let len = min(crcChunkSize, totalFileSize - (idx * crcChunkSize))
                        finalCRC = HardwareChecksumAdapter.combineCRC32(crc1: finalCRC, crc2: chunkCRCs[idx], len2: len)
                    }
                    return String(format: "%08X", finalCRC)
                }
            }
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                let crc = data.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return UInt32(0) }
                    return ttzip_rust_crc32(0, base, raw.count)
                }
                return String(format: "%08X", crc)
            }
            return "00000000"
            
        case .sha256:
            return try computeCryptoHashSync(filePath: filePath, createHasher: SHA256.init)
            
        case .md5:
            return try computeCryptoHashSync(filePath: filePath, createHasher: Insecure.MD5.init)
            
        case .sha1:
            return try computeCryptoHashSync(filePath: filePath, createHasher: Insecure.SHA1.init)
        }
    }
    
    public func computeHash(filePath: String, type: HashType) async throws -> String {
        switch type {
        case .crc32:
            return try computeHashSync(filePath: filePath, type: .crc32)
            
        case .sha256:
            return try await Task.detached(priority: .userInitiated) {
                self.hardwareTuner.boostCurrentThreadPriority()
                return try self.computeCryptoHashSync(filePath: filePath, createHasher: SHA256.init)
            }.value
            
        case .md5:
            return try await Task.detached(priority: .userInitiated) {
                self.hardwareTuner.boostCurrentThreadPriority()
                return try self.computeCryptoHashSync(filePath: filePath, createHasher: Insecure.MD5.init)
            }.value
            
        case .sha1:
            return try await Task.detached(priority: .userInitiated) {
                self.hardwareTuner.boostCurrentThreadPriority()
                return try self.computeCryptoHashSync(filePath: filePath, createHasher: Insecure.SHA1.init)
            }.value
        }
    }
    
    // MARK: - Core Crypto Hash Helper
    
    private func computeCryptoHashSync<H: HashFunction>(
        filePath: String,
        createHasher: () -> H
    ) throws -> String {
        let fd = open(filePath, O_RDONLY)
        guard fd >= 0 else { throw ArchiveError.fileNotFound }
        defer { close(fd) }
        
        var st = stat()
        if fstat(fd, &st) == 0 {
            let fileSize = Int(st.st_size)
            if fileSize == 0 {
                let digest = createHasher().finalize()
                return digest.map { String(format: "%02x", $0) }.joined()
            }
            if let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
                defer { munmap(mapped, fileSize) }
                posix_madvise(mapped, fileSize, POSIX_MADV_WILLNEED)
                var hasher = createHasher()
                hasher.update(bufferPointer: UnsafeRawBufferPointer(start: mapped, count: fileSize))
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()
            }
        }
        
        let bufSize = hardwareTuner.optimalAlignedBufferSize
        let pageSize: MemoryPageSize = bufSize >= 65536 ? .page64K : .page4K
        let pageBuffer = MemoryPageFlyweightPool.shared.borrowBuffer(size: pageSize)
        defer { MemoryPageFlyweightPool.shared.returnBuffer(pageBuffer) }
        let buffer = pageBuffer.pointer.assumingMemoryBound(to: UInt8.self)
        
        var hasher = createHasher()
        var bytesRead = read(fd, buffer, pageBuffer.capacity)
        while bytesRead > 0 {
            let chunk = UnsafeRawBufferPointer(start: buffer, count: bytesRead)
            hasher.update(bufferPointer: chunk)
            bytesRead = read(fd, buffer, pageBuffer.capacity)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Static convenience method for calculating SHA-256 fingerprint of a file.
    public static func calculateSHA256(filePath: String) -> String? {
        let calc = HashCalculator()
        return try? calc.computeHashSync(filePath: filePath, type: .sha256)
    }
    
    /// Static convenience method for calculating SHA-256 fingerprint of raw in-memory data.
    public static func calculateSHA256(data: Data) -> String? {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Hardware Checksum Adapter

//
//


/// Adapter Pattern: Hardware-accelerated Adler-32 and CRC-32 checksum computation adapter.
///
/// Direct passthrough to Apple Silicon ARM64 DotProd / NEON vector pipelines and libdeflate PMULL kernels.
public enum HardwareChecksumAdapter {
    
    /// Computes 32-bit Adler-32 checksum with hardware DotProd / NEON acceleration.
    ///
    /// - Parameters:
    ///   - data: Input data buffer.
    ///   - initial: Initial Adler-32 state (default: 1).
    /// - Returns: Computed 32-bit Adler-32 checksum.
    /// - Precondition: `data` is accessible in current memory space.
    /// - Postcondition: Returns identical checksum to RFC 1950 reference Adler-32.
    /// - Complexity: O(N) time with ~64 GB/s peak throughput on Apple Silicon; O(1) space.
    /// - Note: Thread Safety: 100% thread-safe and reentrant.
    @inlinable
    public static func adler32(for data: Data, initial: UInt32 = 1) -> UInt32 {
        guard !data.isEmpty else { return initial }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return initial
            }
            return ttzip_rust_adler32(initial, baseAddress, rawBuffer.count)
        }
    }
    
    /// Computes 32-bit Adler-32 checksum via direct pointer access.
    ///
    /// - Parameters:
    ///   - ptr: Memory pointer to byte buffer.
    ///   - count: Byte count to scan.
    ///   - initial: Initial Adler-32 state (default: 1).
    /// - Returns: Computed 32-bit Adler-32 checksum.
    /// - Precondition: `ptr` must point to at least `count` valid readable bytes.
    /// - Complexity: O(N) time; O(1) space.
    /// - Note: Thread Safety: Reentrant and thread-safe.
    @inlinable
    public static func adler32(ptr: UnsafePointer<UInt8>, count: Int, initial: UInt32 = 1) -> UInt32 {
        guard count > 0 else { return initial }
        return ttzip_rust_adler32(initial, ptr, count)
    }

    /// Computes 32-bit CRC-32 checksum with PMULL hardware vector folding.
    ///
    /// - Parameters:
    ///   - data: Input data buffer.
    ///   - initial: Initial CRC-32 state (default: 0).
    /// - Returns: Computed 32-bit CRC-32 checksum.
    /// - Precondition: `data` is valid in memory.
    /// - Complexity: O(N) time with ~30 GB/s peak throughput; O(1) space.
    /// - Note: Thread Safety: Reentrant and thread-safe.
    @inlinable
    public static func crc32(for data: Data, initial: UInt32 = 0) -> UInt32 {
        guard !data.isEmpty else { return initial }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return initial
            }
            return ttzip_rust_crc32(initial, baseAddress, rawBuffer.count)
        }
    }

    /// Computes 32-bit CRC-32 checksum via direct pointer access.
    ///
    /// - Parameters:
    ///   - ptr: Memory pointer to byte buffer.
    ///   - count: Byte count to scan.
    ///   - initial: Initial CRC-32 state (default: 0).
    /// - Returns: Computed 32-bit CRC-32 checksum.
    /// - Precondition: `ptr` points to at least `count` readable bytes.
    /// - Complexity: O(N) time; O(1) space.
    /// - Note: Thread Safety: Reentrant and thread-safe.
    @inlinable
    public static func crc32(ptr: UnsafePointer<UInt8>, count: Int, initial: UInt32 = 0) -> UInt32 {
        guard count > 0 else { return initial }
        return ttzip_rust_crc32(initial, ptr, count)
    }

    @inlinable
    public static func computeCRC32(data: Data) -> UInt32 {
        return crc32(for: data)
    }

    @inlinable
    public static func combineCRC32(crc1: UInt32, crc2: UInt32, len2: Int) -> UInt32 {
        return UInt32(crc32_combine(UInt(crc1), UInt(crc2), len2))
    }
}

// MARK: - Libdeflate Accelerator

//
//


/// High-performance DEFLATE compression and decompression acceleration infrastructure.
public final class LibdeflateAccelerator: @unchecked Sendable {
    public static let shared = LibdeflateAccelerator()
    
    private init() {}
    
    /// Thread-local pooled DEFLATE compression with zero per-file allocations.
    public func compress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int,
        level: Int = 6
    ) -> Int {
        var outLen: Int = 0
        let status = ttzip_rust_deflate_compress(
            src.assumingMemoryBound(to: UInt8.self),
            srcSize,
            dst.assumingMemoryBound(to: UInt8.self),
            dstCapacity,
            Int32(level),
            &outLen
        )
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Thread-local pooled DEFLATE decompression with zero per-file allocations.
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        var outLen: Int = 0
        let status = ttzip_rust_deflate_decompress(
            src.assumingMemoryBound(to: UInt8.self),
            srcSize,
            dst.assumingMemoryBound(to: UInt8.self),
            dstCapacity,
            &outLen
        )
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Convenience helper compressing Swift `Data` buffers.
    public func compressData(_ data: Data, level: Int = 6) -> Data? {
        guard !data.isEmpty else { return Data() }
        let maxBound = ttzip_rust_deflate_compress_bound(data.count, Int32(level))
        let pageSize: MemoryPageSize = maxBound > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= maxBound else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBound)
                let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    self.compress(src: srcPtr, srcSize: count, dst: uninitPtr, dstCapacity: maxBound, level: level)
                }
                guard written > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: written, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                self.compress(src: srcPtr, srcSize: count, dst: dstPtr, dstCapacity: capacity, level: level)
            }
            guard written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
    }
    
    /// Convenience helper decompressing Swift `Data` buffers.
    public func decompressData(_ data: Data, originalSize: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        let pageSize: MemoryPageSize = originalSize > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= originalSize else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
                let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    self.decompress(src: srcPtr, srcSize: count, dst: uninitPtr, dstCapacity: originalSize)
                }
                guard actual == originalSize else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: actual, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                self.decompress(src: srcPtr, srcSize: count, dst: dstPtr, dstCapacity: capacity)
            }
            guard actual == originalSize else { return nil }
            return Data(bytes: dstPtr, count: actual)
        }
    }
}
