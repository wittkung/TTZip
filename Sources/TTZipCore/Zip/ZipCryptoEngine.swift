// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CommonCrypto
import CTTZipBridge

/// High-performance native cryptographic engine supporting traditional PKZIP ZipCrypto
/// and WinZip AES-256 CTR mode with SIMD / NEON hardware acceleration.
public final class ZipCryptoEngine: ZipCryptoEngineProtocol, @unchecked Sendable {
    public static let shared = ZipCryptoEngine()
    
    private init() {}
    
    // MARK: - 1. PKZIP Traditional ZipCrypto 3-Key Stream
    
    public struct ZipCryptoKeys {
        public var key0: UInt32 = 0x12345678
        public var key1: UInt32 = 0x23456789
        public var key2: UInt32 = 0x34567890
        
        public init(password: String) {
            for b in password.utf8 {
                updateKeys(byte: b)
            }
        }
        
        public mutating func updateKeys(byte: UInt8) {
            key0 = crc32(key0, byte)
            key1 = (key1 &+ (key0 & 0xFF)) &* 134775813 &+ 1
            key2 = crc32(key2, UInt8(truncatingIfNeeded: key1 >> 24))
        }
        
        public func decryptByte() -> UInt8 {
            let temp = UInt16(key2 | 2)
            return UInt8(truncatingIfNeeded: (temp &* (temp ^ 1)) >> 8)
        }
        
        private func crc32(_ key: UInt32, _ byte: UInt8) -> UInt32 {
            let table: [UInt32] = [
                0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
                0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988, 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91
            ]
            let idx = Int((key ^ UInt32(byte)) & 0x0F)
            return table[idx] ^ (key >> 4)
        }
    }
    
    /// Decrypts traditional ZipCrypto payload (strips the initial 12-byte header).
    public func decryptZipCrypto(payload: Data, password: String) -> Data? {
        guard payload.count >= 12 else { return nil }
        var keys = ZipCryptoKeys(password: password)
        var decrypted = Data(count: payload.count)
        
        payload.withUnsafeBytes { inPtr in
            decrypted.withUnsafeMutableBytes { outPtr in
                guard let src = inPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dst = outPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                for i in 0..<payload.count {
                    let k = keys.decryptByte()
                    let c = src[i] ^ k
                    keys.updateKeys(byte: c)
                    dst[i] = c
                }
            }
        }
        
        // Strip the 12-byte encryption check header
        return decrypted.subdata(in: 12..<decrypted.count)
    }
    
    // MARK: - 2. WinZip AES-256 Native Apple CommonCrypto / SIMD Acceleration

    public func encryptAES256(payload: Data, password: String, actualCompressionMethod: UInt16) -> (payload: Data, compressionMethod: UInt16, extraField: Data)? {
        guard payload.count > 0, !password.isEmpty else { return nil }
        
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { ptr in
            if let b = ptr.baseAddress { arc4random_buf(b, 16) }
        }
        guard let derivedKey = derivePBKDF2SHA1(password: password, salt: salt, keyLength: 66) else { return nil }
        
        let aesKey = derivedKey.subdata(in: 0..<32)
        let hmacKey = derivedKey.subdata(in: 32..<64)
        let pvv = derivedKey.subdata(in: 64..<66)
        
        var cipherPayload = payload
        let payloadCount = payload.count
        let status = cipherPayload.withUnsafeMutableBytes { outBuf -> Int32 in
            guard let basePtr = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return aesKey.withUnsafeBytes { kBuf -> Int32 in
                guard let kPtr = kBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                return ttzip_rust_aes256_ctr(kPtr, 1, basePtr, payloadCount, basePtr)
            }
        }
        guard status == 0 else { return nil }
        
        var fullHmac = [UInt8](repeating: 0, count: 20)
        cipherPayload.withUnsafeBytes { pIn in
            hmacKey.withUnsafeBytes { hIn in
                if let hPtr = hIn.baseAddress, let pPtr = pIn.baseAddress {
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), hPtr, hmacKey.count, pPtr, cipherPayload.count, &fullHmac)
                }
            }
        }
        let hmacTag = Data(fullHmac.prefix(10))
        
        var cipherStream = Data()
        cipherStream.append(salt)
        cipherStream.append(pvv)
        cipherStream.append(cipherPayload)
        cipherStream.append(hmacTag)
        
        // WinZip AES Extra Field (Header ID: 0x9901, Size: 7)
        var extra = Data()
        var headerId: UInt16 = 0x9901
        var extraSize: UInt16 = 7
        var aesVersion: UInt16 = 0x0002 // AE-2
        var vendorId: UInt16 = 0x4541   // "AE"
        var aesStrength: UInt8 = 0x03   // 256-bit
        var actualMethod: UInt16 = UInt16(actualCompressionMethod)
        
        withUnsafeBytes(of: &headerId) { extra.append(contentsOf: $0) }
        withUnsafeBytes(of: &extraSize) { extra.append(contentsOf: $0) }
        withUnsafeBytes(of: &aesVersion) { extra.append(contentsOf: $0) }
        withUnsafeBytes(of: &vendorId) { extra.append(contentsOf: $0) }
        withUnsafeBytes(of: &aesStrength) { extra.append(contentsOf: $0) }
        withUnsafeBytes(of: &actualMethod) { extra.append(contentsOf: $0) }
        
        return (payload: cipherStream, compressionMethod: 99, extraField: extra)
    }
    
    public func decryptAES256(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String) -> Data? {
        guard count > 16 + 2 + 10 else { return nil } // 16B Salt + 2B Check + Auth Tag
        let salt = Data(bytes: payloadPtr, count: 16)
        let pvv1 = payloadPtr[16]
        let pvv2 = payloadPtr[17]
        
        guard let derivedKeys = derivePBKDF2SHA1(password: password, salt: salt, keyLength: 66) else {
            return nil
        }
        
        let aesKey = derivedKeys.subdata(in: 0..<32)
        let derivedPvv1 = derivedKeys[64]
        let derivedPvv2 = derivedKeys[65]
        
        guard pvv1 == derivedPvv1 && pvv2 == derivedPvv2 else { return nil } // Password mismatch
        
        let cipherLen = count - 18 - 10
        let srcCipherPtr = payloadPtr.advanced(by: 18)
        
        var dstPtr: UnsafeMutableRawPointer? = nil
        posix_memalign(&dstPtr, 64, cipherLen)
        guard let dstBytePtr = dstPtr?.assumingMemoryBound(to: UInt8.self) else { return nil }
        
        let status = aesKey.withUnsafeBytes { kBuf -> Int32 in
            guard let kPtr = kBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return ttzip_rust_aes256_ctr(kPtr, 1, srcCipherPtr, cipherLen, dstBytePtr)
        }
        
        if status == 0 {
            return Data(bytesNoCopy: dstBytePtr, count: cipherLen, deallocator: .free)
        } else {
            free(dstPtr)
            return nil
        }
    }
    
    public func decryptAES256Direct(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String, destinationPtr: UnsafeMutablePointer<UInt8>) -> Bool {
        guard count > 16 + 2 + 10 else { return false }
        let pvv1 = payloadPtr[16]
        let pvv2 = payloadPtr[17]
        
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 66) { keyBuf -> Bool in
            guard let keyPtr = keyBuf.baseAddress else { return false }
            
            let saltPtr = payloadPtr
            let passBytes = Array(password.utf8)
            let status = CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, passBytes.count,
                saltPtr, 16,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                1000,
                keyPtr, 66
            )
            guard status == kCCSuccess else { return false }
            
            let derivedPvv1 = keyPtr[64]
            let derivedPvv2 = keyPtr[65]
            guard pvv1 == derivedPvv1 && pvv2 == derivedPvv2 else { return false }
            
            let cipherLen = count - 18 - 10
            let srcCipherPtr = payloadPtr.advanced(by: 18)
            return ttzip_rust_aes256_ctr(keyPtr, 1, srcCipherPtr, cipherLen, destinationPtr) == 0
        }
    }
    
    public func decryptAES256(payload: Data, password: String) -> Data? {
        return payload.withUnsafeBytes { ptr -> Data? in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return decryptAES256(payloadPtr: base, count: payload.count, password: password)
        }
    }
    
    private func derivePBKDF2SHA1(password: String, salt: Data, keyLength: Int) -> Data? {
        if let cached = ArchiveKeyCacheManager.shared.getKey(password: password, salt: salt, keyLength: keyLength) {
            return cached
        }
        
        var derived = Data(count: keyLength)
        let passBytes = Array(password.utf8)
        let status = salt.withUnsafeBytes { sBuf -> Int32 in
            guard let sPtr = sBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return derived.withUnsafeMutableBytes { dBuf -> Int32 in
                guard let dPtr = dBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, passBytes.count,
                    sPtr, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                    1000,
                    dPtr, keyLength
                )
            }
        }
        
        if status == kCCSuccess {
            ArchiveKeyCacheManager.shared.setKey(password: password, salt: salt, keyLength: keyLength, derivedKey: derived)
            return derived
        }
        return nil
    }
}
