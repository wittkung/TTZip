import Foundation
import CTTZipBridge

/// 专为 7z 格式 Level 0 (Store 模式) 打造的零拷贝物理落盘与 mmap 直写引擎
public final class SevenZipStoreStreamWriter: @unchecked Sendable {
    public static let shared = SevenZipStoreStreamWriter()
    
    private init() {}
    
    /// 同步极速创建 7z Store (L0) 归档文件
    public func createStoreArchive(
        outputPath: String,
        inputPaths: [String],
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        guard !inputPaths.isEmpty else { return false }
        let startTime = CFAbsoluteTimeGetCurrent()
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        
        let totalInputSize: Int64 = inputPaths.reduce(0) { acc, path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return acc }
            let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
            let size = (attrs[.size] as? Int64) ?? (attrs[.size] as? NSNumber)?.int64Value ?? 0
            return acc + (isDir ? 0 : size)
        }
        if totalInputSize >= 50 * 1024 * 1024 {
            ArchiveDiskPreallocator.preallocate(atPath: outputPath, targetSizeBytes: totalInputSize)
        }
        
        let factory = ArchiveEntryFlyweightFactory.shared
        let internedInputPaths = inputPaths.map { factory.internPath($0) }
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let success = CUnsafeBufferAdapter.withCString(outputPath) { cOutPath in
            CUnsafeBufferAdapter.withCStringsArray(internedInputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutPath = cOutPath else { return false }
                    let res: Int32
                    if cPassword == nil {
                        res = ttzip_create_7z_store_fast_c(cOutPath, cInputPaths, internedInputPaths.count)
                    } else {
                        res = ttzip_create_7z_native_c(cOutPath, cInputPaths, internedInputPaths.count, 0, cPassword)
                    }
                    return res == 0
                }
            }
        }
        if success {
            let duration = max(0.001, CFAbsoluteTimeGetCurrent() - startTime)
            let throughput = (Double(totalInputSize) / (1024.0 * 1024.0)) / duration
            let formattedTotal = ByteCountFormatterFlyweight.shared.string(fromByteCount: totalInputSize)
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: totalInputSize,
                totalBytes: totalInputSize,
                currentFileName: "7z Store 极速打包完成 (\(formattedTotal))",
                throughputMBs: throughput
            ))
        }
        return success
    }
}

