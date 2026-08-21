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

// MARK: - Checksum Result Models

public struct ChecksumResult: Sendable, Equatable {
    public let crc32: UInt32
    public let crc32String: String
    public let sha256String: String
    public let processedFiles: Int
    public let totalSizeBytes: Int64
    
    public init(
        crc32: UInt32,
        crc32String: String,
        sha256String: String,
        processedFiles: Int,
        totalSizeBytes: Int64
    ) {
        self.crc32 = crc32
        self.crc32String = crc32String
        self.sha256String = sha256String
        self.processedFiles = processedFiles
        self.totalSizeBytes = totalSizeBytes
    }
}

// MARK: - ChecksumCalculatorVisitor

/// Recursively computes aggregate composite tree checksums (CRC32 and SHA-256 signatures).
public final class ChecksumCalculatorVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = ChecksumResult
    
    public init() {}
    
    public func visit(leaf: ArchiveLeafFile) -> ChecksumResult {
        var crc: UInt32 = 0
        var shaData = Data()
        
        if let crcVal = leaf.crc32, crcVal != 0 {
            crc = crcVal
            var crcBig = crc.bigEndian
            shaData.append(Data(bytes: &crcBig, count: MemoryLayout<UInt32>.size))
            shaData.append(leaf.path.data(using: .utf8) ?? Data())
        } else if FileManager.default.fileExists(atPath: leaf.path) {
            let hashCalc = ArchiveEngineFactory.makeHashCalculator()
            if let crcStr = try? hashCalc.computeHashSync(filePath: leaf.path, type: .crc32),
               let crcVal = UInt32(crcStr, radix: 16) {
                crc = crcVal
            }
            if let shaStr = try? hashCalc.computeHashSync(filePath: leaf.path, type: .sha256) {
                shaData.append(shaStr.data(using: .utf8) ?? Data())
            }
        } else {
            let payload = "\(leaf.path)_\(leaf.sizeBytes)"
            let payloadData = payload.data(using: .utf8) ?? Data()
            crc = payloadData.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return UInt32(0) }
                return ttzip_rust_crc32(0, base, buffer.count)
            }
            shaData.append(payloadData)
        }
        
        let sha256Digest = SHA256.hash(data: shaData)
        let sha256Str = sha256Digest.map { String(format: "%02x", $0) }.joined()
        let crcStr = String(format: "%08X", crc)
        
        return ChecksumResult(
            crc32: crc,
            crc32String: crcStr,
            sha256String: sha256Str,
            processedFiles: 1,
            totalSizeBytes: leaf.sizeBytes
        )
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> ChecksumResult {
        var combinedCRC: UInt32 = 0
        var combinedSHAHasher = SHA256()
        var totalFiles = 0
        var totalSize: Int64 = 0
        
        for child in directory.getChildren() {
            let childRes = child.accept(visitor: self)
            totalFiles += childRes.processedFiles
            totalSize += childRes.totalSizeBytes
            
            if childRes.totalSizeBytes > 0 {
                combinedCRC = UInt32(crc32_combine(uLong(combinedCRC), uLong(childRes.crc32), Int(childRes.totalSizeBytes)))
            } else {
                combinedCRC ^= childRes.crc32
            }
            
            if let shaData = childRes.sha256String.data(using: .utf8) {
                combinedSHAHasher.update(data: shaData)
            }
        }
        
        let finalDigest = combinedSHAHasher.finalize()
        let sha256Str = finalDigest.map { String(format: "%02x", $0) }.joined()
        let crcStr = String(format: "%08X", combinedCRC)
        
        return ChecksumResult(
            crc32: combinedCRC,
            crc32String: crcStr,
            sha256String: sha256Str,
            processedFiles: totalFiles,
            totalSizeBytes: totalSize
        )
    }
}
