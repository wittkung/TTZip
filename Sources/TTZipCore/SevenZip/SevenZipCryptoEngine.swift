// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CommonCrypto
import Security

/// Multi-threaded parallel AES-256 encryption and decryption engine for 7z archives.
public final class SevenZipCryptoEngine: SevenZipCryptoEngineProtocol, @unchecked Sendable {
    public static let shared = SevenZipCryptoEngine()
    
    private init() {}
    
    /// Generates derived key for 7z archive headers and solid streams (PBKDF2 variant with 2^19 cycles).
    public func deriveKey(password: String, salt: Data, numCyclesPower: Int) -> Data {
        if let cached = ArchiveKeyCacheManager.shared.getKey(password: password, salt: salt, keyLength: 32) {
            return cached
        }
        
        var key = Data(count: 32)
        let numCycles = 1 << numCyclesPower
        let pwdData = password.data(using: .utf16LittleEndian) ?? Data()
        
        pwdData.withUnsafeBytes { pwdIn in
            salt.withUnsafeBytes { saltIn in
                key.withUnsafeMutableBytes { keyOut in
                    guard let pwdPtr = pwdIn.baseAddress,
                          let saltPtr = saltIn.baseAddress,
                          let keyPtr = keyOut.baseAddress else { return }
                    
                    var sha = CC_SHA256_CTX()
                    CC_SHA256_Init(&sha)
                    for _ in 0..<numCycles {
                        CC_SHA256_Update(&sha, pwdPtr, CC_LONG(pwdData.count))
                        CC_SHA256_Update(&sha, saltPtr, CC_LONG(salt.count))
                    }
                    CC_SHA256_Final(keyPtr.assumingMemoryBound(to: UInt8.self), &sha)
                }
            }
        }
        
        ArchiveKeyCacheManager.shared.setKey(password: password, salt: salt, keyLength: 32, derivedKey: key)
        return key
    }
    
    /// Processes AES-256 chunked encryption and multi-threaded parallel decryption.
    public func processParallelAES256(
        inputData: Data,
        key: Data,
        iv: Data,
        encrypt: Bool,
        chunkSize: Int = 64 * 1024 * 1024 // 64MB chunk
    ) -> Data? {
        let totalSize = inputData.count
        guard totalSize > 0, key.count == 32 else { return nil }
        
        let numChunks = (totalSize + chunkSize - 1) / chunkSize
        var alignedOutPtr: UnsafeMutableRawPointer? = nil
        let pageSize = 64
        let alignedLength = ((totalSize + pageSize - 1) / pageSize) * pageSize
        posix_memalign(&alignedOutPtr, pageSize, alignedLength)
        
        guard let dstRawPtr = alignedOutPtr else { return nil }
        defer { free(dstRawPtr) }
        let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
        
        return inputData.withUnsafeBytes { inRaw -> Data? in
            guard let inBase = inRaw.baseAddress else { return nil }
            let baseInPtr = inBase.assumingMemoryBound(to: UInt8.self)
            let pointerBox = SendablePointerBox(pointer: baseInPtr, size: totalSize)
            
            if encrypt {
                var outMoved: Int = 0
                let status = key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            0,
                            keyBytes.baseAddress, 32,
                            ivBytes.baseAddress,
                            pointerBox.pointer, totalSize,
                            UnsafeMutableRawPointer(mutating: dstBytePtr), totalSize,
                            &outMoved
                        )
                    }
                }
                if status == kCCSuccess {
                    return Data(bytes: dstBytePtr, count: totalSize)
                }
                return nil
            }
            
            let atomicFlag = SendableAtomicFlag()
            let dstBox = SendablePointerBox(pointer: dstBytePtr, size: totalSize)
            
            // Multi-core parallel chunk decryption
            DispatchQueue.concurrentPerform(iterations: numChunks) { chunkIdx in
                let offset = chunkIdx * chunkSize
                let length = min(chunkSize, totalSize - offset)
                
                let srcPtr = pointerBox.pointer.advanced(by: offset)
                let dstChunkPtr = dstBox.pointer.advanced(by: offset)
                
                var chunkIV = iv
                if chunkIdx > 0 {
                    let prevCipherOffset = offset - 16
                    chunkIV = Data(bytes: pointerBox.pointer.advanced(by: prevCipherOffset), count: 16)
                }
                
                var outMoved: Int = 0
                let op = encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt)
                
                let status = key.withUnsafeBytes { keyBytes in
                    chunkIV.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            op,
                            CCAlgorithm(kCCAlgorithmAES),
                            0,
                            keyBytes.baseAddress, 32,
                            ivBytes.baseAddress,
                            srcPtr, length,
                            UnsafeMutableRawPointer(mutating: dstChunkPtr), length,
                            &outMoved
                        )
                    }
                }
                
                if status != kCCSuccess {
                    atomicFlag.markFailure()
                }
            }
            
            if atomicFlag.isSuccess {
                return Data(bytes: dstBytePtr, count: totalSize)
            }
            return nil
        }
    }
}

