import Foundation
import CryptoKit
import CommonCrypto
import CTTZipBridge

/// 针对传统 ZipCrypto 与 WinZip AES-256 加密解密的高性能原生硬件加速引擎
public final class ZipCryptoEngine: ZipCryptoEngineProtocol, @unchecked Sendable {
    public static let shared = ZipCryptoEngine()
    
    private init() {}
    
    // MARK: - 1. PKZIP 传统 ZipCrypto 3-Key 解密流
    
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
    
    /// 解密传统 ZipCrypto 数据 Payload (首先切除前 12 字节 header)
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
        
        // 切除前 12 字节校验头
        return decrypted.subdata(in: 12..<decrypted.count)
    }
    
    // MARK: - 2. WinZip AES-256 原生 Apple CryptoKit 硬件解密
    
    // MARK: - 2. WinZip AES-256 原生 Apple CommonCrypto / SIMD 硬件极速加解密

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
                return ttzip_aes256_ctr_crypt_parallel(kPtr, basePtr, payloadCount, basePtr, 16)
            }
        }
        guard status == 0 else { return nil }
        
        var hmacTag = Data(count: 10)
        cipherPayload.withUnsafeBytes { pIn in
            hmacKey.withUnsafeBytes { hIn in
                hmacTag.withUnsafeMutableBytes { tOut in
                    if let hPtr = hIn.baseAddress?.assumingMemoryBound(to: UInt8.self),
                       let pPtr = pIn.baseAddress?.assumingMemoryBound(to: UInt8.self),
                       let tPtr = tOut.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                        _ = ttzip_compute_hmac_sha1_fast(hPtr, hmacKey.count, pPtr, cipherPayload.count, tPtr)
                    }
                }
            }
        }
        
        var cipherStream = Data()
        cipherStream.append(salt)
        cipherStream.append(pvv)
        cipherStream.append(cipherPayload)
        cipherStream.append(hmacTag.prefix(10))
        
        // WinZip AES Extra Field (Header ID: 0x9901, Size: 7)
        var extra = Data()
        var headerId: UInt16 = 0x9901
        var extraSize: UInt16 = 7
        var vendorVer: UInt16 = 0x0001
        var vendorId: UInt16 = 0x4541 // "AE"
        var strength: UInt8 = 0x03    // AES-256
        var methodVal: UInt16 = actualCompressionMethod
        
        extra.append(Data(bytes: &headerId, count: 2))
        extra.append(Data(bytes: &extraSize, count: 2))
        extra.append(Data(bytes: &vendorVer, count: 2))
        extra.append(Data(bytes: &vendorId, count: 2))
        extra.append(Data(bytes: &strength, count: 1))
        extra.append(Data(bytes: &methodVal, count: 2))
        
        return (cipherStream, 99, extra)
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
            return ttzip_aes256_ctr_crypt_parallel(kPtr, srcCipherPtr, cipherLen, dstBytePtr, 16)
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
            let status = passBytes.withUnsafeBufferPointer { pBuf -> Int32 in
                guard let pPtr = pBuf.baseAddress else { return -1 }
                return ttzip_pbkdf2_sha1_fast(pPtr, passBytes.count, saltPtr, 16, 1000, keyPtr, 66)
            }
            guard status == 0 else { return false }
            
            let derivedPvv1 = keyPtr[64]
            let derivedPvv2 = keyPtr[65]
            guard pvv1 == derivedPvv1 && pvv2 == derivedPvv2 else { return false }
            
            let cipherLen = count - 18 - 10
            let srcCipherPtr = payloadPtr.advanced(by: 18)
            return ttzip_aes256_ctr_crypt_parallel(keyPtr, srcCipherPtr, cipherLen, destinationPtr, 16) == 0
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
        let status = passBytes.withUnsafeBufferPointer { pBuf -> Int32 in
            guard let pPtr = pBuf.baseAddress else { return -1 }
            return salt.withUnsafeBytes { sBuf -> Int32 in
                guard let sPtr = sBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                return derived.withUnsafeMutableBytes { dBuf -> Int32 in
                    guard let dPtr = dBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                    return ttzip_pbkdf2_sha1_fast(pPtr, passBytes.count, sPtr, salt.count, 1000, dPtr, keyLength)
                }
            }
        }
        
        if status == 0 {
            ArchiveKeyCacheManager.shared.setKey(password: password, salt: salt, keyLength: keyLength, derivedKey: derived)
            return derived
        }
        return nil
    }
}
