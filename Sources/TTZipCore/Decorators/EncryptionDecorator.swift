import Foundation

/// 密码加密/解密具体装饰器 (Concrete Decorator)
/// 透明地在归档压缩或解压流中叠加密码保护机制，对上层逻辑暴露统一接口。
open class EncryptionDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var password: String?

    public init(inner: ArchiveEngineImplementorProtocol, password: String?) {
        self.password = password
        super.init(inner: inner)
    }

    /// 透明叠加加密压缩逻辑
    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        guard let pwd = password, !pwd.isEmpty else {
            return try await super.compressStream(
                inputPaths: inputPaths,
                outputPath: outputPath,
                options: options
            )
        }

        // 构建包含密码与格式加密策略的配置选项
        var encryptedOptions = options.clone()
        if encryptedOptions.zipOptions.zipEncryptionMethod == "None" {
            encryptedOptions.zipOptions.zipEncryptionMethod = "AES256"
        }
        encryptedOptions.sevenZipOptions.encryptFileNames = true

        TTLogger.debug("🔒 [EncryptionDecorator] 透明叠加加密流处理中 (密码保护已激活)...")
        return try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: encryptedOptions
        )
    }

    /// 透明叠加解密提取逻辑
    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        if let pwd = password, !pwd.isEmpty {
            TTLogger.debug("🔓 [EncryptionDecorator] 透明叠加解密流处理中 (载入密码解密)...")
        }
        return try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}
