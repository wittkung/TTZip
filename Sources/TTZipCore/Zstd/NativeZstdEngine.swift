import Foundation
import CTTZipBridge

/// Apple Silicon M 系列芯片全核硬件感知原生物理 Zstandard (.zst) 极速引擎
public final class NativeZstdEngine: @unchecked Sendable {
    public static let shared = NativeZstdEngine()
    
    private init() {}
    
    /// RFC 8878 Zstandard 魔数 (0xFD2FB528, Little-Endian: 0x28, 0xB5, 0x2F, 0xFD)
    public static let zstdMagicNumber: UInt32 = 0xFD2FB528
    
    /// 校验文件是否为标准 Zstandard (.zst) 格式帧或可跳过帧
    public func isValidZstdFrame(atPath filePath: String) -> Bool {
        return ZstdHeaderReader.shared.readFrameDescriptor(filePath: filePath) != nil
    }
    
    /// 从文件解析 RFC 8878 Zstandard 帧描述符
    public func inspectFrame(atPath filePath: String) -> ZstdFrameDescriptor? {
        return ZstdHeaderReader.shared.readFrameDescriptor(filePath: filePath)
    }
    
    /// 全核硬件调优流式 Zstandard (.zst) 压缩
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdStreamWriter.shared.compress(
            srcPath: srcPath,
            dstPath: dstPath,
            level: level,
            enableLDM: enableLDM,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
    
    /// 全核硬件极速 Zstandard (.zst) 解压
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdStreamExtractor.shared.decompress(
            srcPath: srcPath,
            dstPath: dstPath,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
}
