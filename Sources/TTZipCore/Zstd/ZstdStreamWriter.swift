import Foundation
import CTTZipBridge

/// 独立专有的 全核硬件感知 Zstandard (.zst) 高吞吐流式压缩器
public final class ZstdStreamWriter: @unchecked Sendable {
    public static let shared = ZstdStreamWriter()
    
    private init() {}
    
    /// 执行物理 Zstandard (.zst) 单文件/多文件压缩
    public func compress(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdCAdapter.shared.compressFile(
            srcPath: srcPath,
            dstPath: dstPath,
            level: level,
            enableLDM: enableLDM,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
}
