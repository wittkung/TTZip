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

    public init(hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner) {
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
                    ttzip_rust_crc32(0, raw.bindMemory(to: UInt8.self).baseAddress, raw.count)
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

