import Foundation
import CTTZipBridge

/// 7z 原生 C 引擎适配器 (Adapter Pattern)
/// 将 C 语言 ttzip_7z_extract_native_parallel_c 和 ttzip_create_7z_native_c 适配为符合 Swift 并发规范的 SevenZipEngineProtocol
public final class SevenZipCAdapter: SevenZipEngineProtocol, Sendable {
    public static let shared = SevenZipCAdapter()
    
    private init() {}
    
    /// 执行 7z 归档文件打包创建
    @inline(__always)
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        useZstd: Bool = false,
        solidBlockSizeMb: Int = 128,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let raw = level.rawValue
        let lvl: Int32 = raw <= 0 ? 0 : (raw >= 9 ? 9 : Int32(raw))
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        
        return CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return false }
                    let status = ttzip_create_7z_native_c(
                        cOutputPath,
                        cInputPaths,
                        inputPaths.count,
                        lvl,
                        cPassword
                    )
                    if status == 0 {
                        progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: 100, totalBytes: 100, currentFileName: ""))
                    } else {
                        TTLogger.error("[SevenZipCAdapter] C 层压缩失败 code=\(status), output=\(outputPath)")
                    }
                    return status == 0
                }
            }
        }
    }
    
    /// 解压 7z 归档文件（封装 C 语言 ttzip_extract_archive_advanced 桥接细节）
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        skipMacJunk: Bool = true,
        password: String? = nil
    ) throws -> Bool {
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        return CUnsafeBufferAdapter.withCString(archivePath) { cArchivePath in
            CUnsafeBufferAdapter.withCString(destinationDir) { cDestDir in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cArchivePath = cArchivePath, let cDestDir = cDestDir else { return false }
                    let status = ttzip_extract_7z_native_c(
                        cArchivePath,
                        cDestDir,
                        cPassword
                    )
                    if status != 0 {
                        TTLogger.debug("[SevenZipCAdapter] C 层解压 code=\(status), archive=\(archivePath), dest=\(destinationDir)")
                    }
                    return status == 0
                }
            }
        }
    }

    /// 直接调用 Fast-LZMA2 混合分块压缩接口 (Hybrid Fast-Path)
    @inline(__always)
    public func compressBlockFL2(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int,
        level: Int = 5,
        isZeroBlock: Bool = false,
        threadCount: Int = 0
    ) -> (status: Int32, compressedSize: Int, dictSize: UInt32) {
        var outLen: Int = 0
        var outDict: UInt32 = 0
        let status = ttzip_fl2_compress_block(
            src,
            srcLength,
            dst,
            dstCapacity,
            &outLen,
            Int32(level),
            isZeroBlock,
            &outDict,
            Int32(threadCount)
        )
        return (status, outLen, outDict)
    }
}
