import Foundation
import CommonCrypto
import Security

/// Apple Silicon ARMv8.4-A 硬件加速 7z AES-256 多线程并发加解密引擎
public final class SevenZipCryptoEngine: SevenZipCryptoEngineProtocol, @unchecked Sendable {
    public static let shared = SevenZipCryptoEngine()
    
    private init() {}
    
    /// 执行 7z 派生密钥生成 (PBKDF2 变体 2^19 次高强度迭代)
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
    
    /// 突破 7z 单线程 AES 限制：全核并发分块加解密 10GB Payload (利用 CBC 解密与分块 IV 无锁并行性)
    public func processParallelAES256(
        inputData: Data,
        key: Data,
        iv: Data,
        encrypt: Bool,
        chunkSize: Int = 64 * 1024 * 1024 // 64MB 细粒度并行 Block
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
                // CBC 模式加密必须流式顺序处理以保证分组 IV 连续衔接
                var outMoved: Int = 0
                let status = key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            0, // 字节对齐无 Padding
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
            
            var successFlag: Int32 = 1
            let dstBox = SendablePointerBox(pointer: dstBytePtr, size: totalSize)
            
            // 全核并发分块并行处理 (仅用于解密)
            withUnsafeMutablePointer(to: &successFlag) { flagPtr in
                DispatchQueue.concurrentPerform(iterations: numChunks) { chunkIdx in
                    let offset = chunkIdx * chunkSize
                    let length = min(chunkSize, totalSize - offset)
                    
                    let srcPtr = pointerBox.pointer.advanced(by: offset)
                    let dstChunkPtr = dstBox.pointer.advanced(by: offset)
                    
                    var chunkIV = iv
                    if chunkIdx > 0 {
                        // CBC 模式解密并发：Block N 的 IV 即为 Ciphertext Block N-1 的末尾 16 字节
                        if !encrypt {
                            let prevCipherOffset = offset - 16
                            chunkIV = Data(bytes: pointerBox.pointer.advanced(by: prevCipherOffset), count: 16)
                        }
                    }
                    
                    var outMoved: Int = 0
                    let op = encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt)
                    
                    let status = key.withUnsafeBytes { keyBytes in
                        chunkIV.withUnsafeBytes { ivBytes in
                            CCCrypt(
                                op,
                                CCAlgorithm(kCCAlgorithmAES),
                                0, // 字节对齐无 Padding
                                keyBytes.baseAddress, 32,
                                ivBytes.baseAddress,
                                srcPtr, length,
                                UnsafeMutableRawPointer(mutating: dstChunkPtr), length,
                                &outMoved
                            )
                        }
                    }
                    
                    if status != kCCSuccess {
                        OSAtomicCompareAndSwap32Barrier(1, 0, flagPtr)
                    }
                }
            }
            
            if successFlag == 1 {
                return Data(bytes: dstBytePtr, count: totalSize)
            }
            return nil
        }
    }
}
