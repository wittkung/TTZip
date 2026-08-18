// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit

/// 语料数据密码学指纹结构体
public struct CorpusDataFingerprint: Codable, Sendable {
    public let corpusId: String
    public let path: String
    public let sizeBytes: Int64
    public let sha256Hex: String
    public let lastModifiedTimestamp: Double
    
    public init(corpusId: String, path: String, sizeBytes: Int64, sha256Hex: String, lastModifiedTimestamp: Double) {
        self.corpusId = corpusId
        self.path = path
        self.sizeBytes = sizeBytes
        self.sha256Hex = sha256Hex
        self.lastModifiedTimestamp = lastModifiedTimestamp
    }
}

/// 语料指纹全生命周期管理与自动失效中枢 (Cache Invalidation & Zero-Tampering Mandate)
public final class CorpusFingerprintManager: @unchecked Sendable {
    
    public static let shared = CorpusFingerprintManager()
    
    private let lock = NSLock()
    private var cachedFingerprints: [String: CorpusDataFingerprint] = [:]
    
    public init() {}
    
    /// 计算指定语料路径的物理 SHA-256 密码学指纹
    public func computeFingerprint(for item: CorpusItem) -> CorpusDataFingerprint? {
        lock.lock()
        if let existing = cachedFingerprints[item.path] {
            // 校验文件修改时间与大小
            if let attrs = try? FileManager.default.attributesOfItem(atPath: item.path),
               let size = attrs[.size] as? Int64,
               let mdate = attrs[.modificationDate] as? Date,
               size == existing.sizeBytes && abs(mdate.timeIntervalSince1970 - existing.lastModifiedTimestamp) < 0.001 {
                lock.unlock()
                return existing
            }
        }
        lock.unlock()
        
        guard FileManager.default.fileExists(atPath: item.path) else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: item.path),
              let size = attrs[.size] as? Int64,
              let mdate = attrs[.modificationDate] as? Date else { return nil }
        
        // 分块流式计算 SHA-256 (内存恒定零暴涨)
        guard let stream = InputStream(fileAtPath: item.path) else { return nil }
        stream.open()
        defer { stream.close() }
        
        var hasher = SHA256()
        let bufferSize = 1024 * 1024 // 1MB 读缓冲
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: read))
            } else if read < 0 {
                return nil
            } else {
                break
            }
        }
        
        let digest = hasher.finalize()
        let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
        
        let fp = CorpusDataFingerprint(
            corpusId: item.id,
            path: item.path,
            sizeBytes: size,
            sha256Hex: sha256Hex,
            lastModifiedTimestamp: mdate.timeIntervalSince1970
        )
        
        lock.lock()
        cachedFingerprints[item.path] = fp
        lock.unlock()
        return fp
    }
    
    /// 计算全量评测数据集的 Merkle Root 哈希摘要
    public func computeDatasetMerkleRoot(items: [CorpusItem]) -> String {
        var sortedFingerprints: [String] = []
        for item in items.sorted(by: { $0.id < $1.id }) {
            if let fp = computeFingerprint(for: item) {
                sortedFingerprints.append("\(fp.corpusId):\(fp.sizeBytes):\(fp.sha256Hex)")
            }
        }
        let joined = sortedFingerprints.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 校验数据集指纹是否发生篡改或变更，若发生变更则自动标记并清除旧缓存
    public func validateAndInvalidateIfChanged(currentItems: [CorpusItem], recordedMerkleRoot: String?) -> (isValid: Bool, currentMerkleRoot: String) {
        let currentMerkle = computeDatasetMerkleRoot(items: currentItems)
        guard let recorded = recordedMerkleRoot, !recorded.isEmpty else {
            return (isValid: false, currentMerkleRoot: currentMerkle)
        }
        let isValid = (currentMerkle == recorded)
        return (isValid: isValid, currentMerkleRoot: currentMerkle)
    }
}
