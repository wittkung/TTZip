import Foundation

/// 7z 全核高密度多固实块 (-ms=128m) 物理极限打包压缩引擎 (Delegate to SevenZipEngine)
public final class SevenZipParallelWriter: @unchecked Sendable {
    public static let shared = SevenZipParallelWriter()
    
    private init() {}
    
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
        return try SevenZipEngine.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password
        )
    }
}
