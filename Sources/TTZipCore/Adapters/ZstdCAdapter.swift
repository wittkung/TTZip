import Foundation
import CTTZipBridge

/// Zstandard 原生 C 引擎适配器 (Adapter Pattern)
/// 将 C 语言 ttzip_zstd_compress_file_stream 适配为符合 ZstdEngineProtocol
public final class ZstdCAdapter: ZstdEngineProtocol, Sendable {
    public static let shared = ZstdCAdapter()
    
    private init() {}
    
    /// 压缩单文件/流为 Zstandard 帧
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tuner = AppleSiliconTuner.shared
        tuner.boostCurrentThreadPriority()
        
        let workers = Int32(tuner.optimalCompressionThreads)
        let jobSizeMB: Int32 = 0
        let fileManager = FileManager.default
        let srcBytes = (try? fileManager.attributesOfItem(atPath: srcPath)[.size] as? Int64) ?? 0
        
        var windowLog: Int32 = 0
        if enableLDM {
            windowLog = Int32(tuner.optimalZstdLongWindowLog)
            if srcBytes > 0 {
                let maxLog = Int32(ceil(log2(Double(srcBytes))))
                if maxLog < windowLog {
                    windowLog = max(10, maxLog)
                }
            }
        }
        let overlapLog: Int32 = enableLDM ? 2 : 0
        let compLevel = Int32(max(-5, min(22, level.rawValue)))
        let startTime = Date()
        
        progressHandler?(ArchiveProgress(
            state: .processing,
            bytesProcessed: 0,
            totalBytes: srcBytes,
            currentFileName: (srcPath as NSString).lastPathComponent,
            throughputMBs: 0.0
        ))
        
        let result = CUnsafeBufferAdapter.withCString(srcPath) { cSrc in
            CUnsafeBufferAdapter.withCString(dstPath) { cDst in
                CUnsafeBufferAdapter.withCString(dictPath) { cDict in
                    guard let cSrc = cSrc, let cDst = cDst else { return Int32(-1) }
                    return ttzip_zstd_compress_file_stream(
                        cSrc,
                        cDst,
                        compLevel,
                        workers,
                        jobSizeMB,
                        overlapLog,
                        windowLog,
                        enableLDM,
                        cDict
                    )
                }
            }
        }
        
        if result == 0 {
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let outBytes = (try? fileManager.attributesOfItem(atPath: dstPath)[.size] as? Int64) ?? 0
            let throughput = (Double(srcBytes) / (1024.0 * 1024.0)) / duration
            
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: outBytes,
                totalBytes: srcBytes,
                currentFileName: (dstPath as NSString).lastPathComponent,
                throughputMBs: throughput
            ))
            return true
        }
        
        return false
    }
    
    /// 解压 Zstandard 帧文件
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let result = CUnsafeBufferAdapter.withCString(srcPath) { cSrc in
            CUnsafeBufferAdapter.withCString(dstPath) { cDst in
                CUnsafeBufferAdapter.withCString(dictPath) { cDict in
                    guard let cSrc = cSrc, let cDst = cDst else { return Int32(-1) }
                    return ttzip_zstd_decompress_file_stream(cSrc, cDst, cDict)
                }
            }
        }
        return result == 0
    }
}
