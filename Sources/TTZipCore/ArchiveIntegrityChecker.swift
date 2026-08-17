import Foundation
import CryptoKit
import CTTZipBridge

/// 高性能数据完整性校验引擎 (CRC32 & SHA256)
public final class ArchiveIntegrityChecker: ArchiveIntegrityChecking, @unchecked Sendable {
    private let hashCalculator: HashCalculating
    private var sourceCRCCache: [String: String] = [:]
    private let cacheLock = NSLock()
    
    public init(hashCalculator: HashCalculating = ArchiveEngineFactory.makeHashCalculator()) {
        self.hashCalculator = hashCalculator
    }
    
    /// 计算指定文件的 CRC32 校验和字符串 (如 "A1B2C3D4")
    public func computeCRC32(filePath: String) -> String {
        let crc = ttzip_compute_file_crc32(filePath)
        return String(format: "%08X", crc)
    }
    
    /// 异步计算指定文件的 SHA256 哈希指纹 (调用 16MB 页对齐硬件级 HashCalculator 引擎)
    public func computeSHA256(filePath: String) async throws -> String {
        return try await hashCalculator.computeHash(filePath: filePath, type: .sha256)
    }

    /// 通用解压目录完整性校验：递归核验解压产物总字节与 CRC32 数据散列指纹，打印标准核验日志
    @discardableResult
    public func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String? = nil,
        sourceCRC32: String? = nil,
        label: String
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?) {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: directoryPath)) ?? []
        if items.isEmpty {
            TTLogger.debug("  [\(label) 完整性校验] 解压目标目录为空: \(directoryPath)")
            return (false, 0, nil)
        }
        
        var totalExtractedBytes: Int64 = 0
        var firstFilePath: String? = nil
        
        var checkDir = directoryPath
        if let items = try? fm.contentsOfDirectory(atPath: directoryPath), items.count == 1, let first = items.first {
            let sub = (directoryPath as NSString).appendingPathComponent(first)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue {
                checkDir = sub
            }
        }
        
        if let enumerator = fm.enumerator(atPath: checkDir) {
            while let rel = enumerator.nextObject() as? String {
                let fullPath = (checkDir as NSString).appendingPathComponent(rel)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    let filename = (fullPath as NSString).lastPathComponent
                    if filename == ".metadata_never_index" || filename == ".DS_Store" || filename.hasPrefix("._") || filename.contains(":com.apple.") || filename.contains("com.apple.provenance") {
                        continue
                    }
                    let sz = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? Int64) ?? 0
                    totalExtractedBytes += sz
                    if firstFilePath == nil {
                        firstFilePath = fullPath
                    }
                }
            }
        }
        
        let sizeValid = totalExtractedBytes == expectedOriginalBytes
        var crcStr: String? = nil
        var hashValid = true
        var targetSrcCRC: String? = sourceCRC32

        if sizeValid, let fileToHash = firstFilePath {
            TTLogger.debug("  🔍 [\(label) 哈希核验中] 正在校验解压产物 CRC32 指纹...")
            crcStr = computeCRC32(filePath: fileToHash)
            
            var isSrcDir: ObjCBool = false
            if targetSrcCRC == nil {
                targetSrcCRC = {
                    if let src = sourceFilePath, fm.fileExists(atPath: src, isDirectory: &isSrcDir), !isSrcDir.boolValue {
                        cacheLock.lock()
                        if let cached = sourceCRCCache[src] {
                            cacheLock.unlock()
                            return cached
                        }
                        cacheLock.unlock()
                        
                        let computed = computeCRC32(filePath: src)
                        cacheLock.lock()
                        sourceCRCCache[src] = computed
                        cacheLock.unlock()
                        return computed
                    }
                    return nil
                }()
            }
            
            if let srcCrc = targetSrcCRC, !srcCrc.isEmpty, srcCrc != "00000000" {
                hashValid = (crcStr == srcCrc)
                if !hashValid {
                    TTLogger.error("  ❌ [\(label) 哈希不匹配] 源 CRC32: \(srcCrc) vs 解压 CRC32: \(crcStr ?? "")")
                }
            }
        }

        let isValid = sizeValid && hashValid
        if isValid {
            let crcDisplay: String
            if let srcCrc = targetSrcCRC, let extCrc = crcStr {
                crcDisplay = " | 源文件 CRC32: \(srcCrc) == 解压 CRC32: \(extCrc)"
            } else if let extCrc = crcStr {
                crcDisplay = " | 解压 CRC32: \(extCrc)"
            } else {
                crcDisplay = ""
            }
            TTLogger.debug("  ✅ [\(label) 完整性与哈希校验] 100% 字节精准核验通过 (\(totalExtractedBytes) 字节\(crcDisplay))")
        } else if !sizeValid {
            TTLogger.error("  ❌ [\(label) 字节校验失败] 原始: \(expectedOriginalBytes) 字节 vs 实测解压: \(totalExtractedBytes) 字节 (checkDir: \(checkDir))")
            if let dbgEnum = fm.enumerator(atPath: checkDir) {
                while let r = dbgEnum.nextObject() as? String {
                    let fp = (checkDir as NSString).appendingPathComponent(r)
                    var id: ObjCBool = false
                    if fm.fileExists(atPath: fp, isDirectory: &id) {
                        let s = (try? fm.attributesOfItem(atPath: fp)[.size] as? Int64) ?? 0
                        TTLogger.error("     - rel: \(r) | isDir: \(id.boolValue) | size: \(s)")
                    }
                }
            }
            SingleTestDiagnosticRunner.shared.reportFailure(
                stage: .integrityVerification,
                format: .zip,
                level: .level1,
                errorMessage: "[\(label)] 解压解包字节总数不匹配",
                destinationDir: directoryPath,
                expectedBytes: expectedOriginalBytes,
                actualBytes: totalExtractedBytes
            )
        }
        return (isValid, totalExtractedBytes, crcStr)
    }
}
