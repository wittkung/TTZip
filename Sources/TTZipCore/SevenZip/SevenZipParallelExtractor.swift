import Foundation

/// 7z 全核 P-Core 亲和性绑定与并发零拷贝物理极限提取引擎 (Delegate to SevenZipEngine)
public final class SevenZipParallelExtractor: @unchecked Sendable {
    public static let shared = SevenZipParallelExtractor()
    
    private init() {}
    
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipEngine.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
    }
}
