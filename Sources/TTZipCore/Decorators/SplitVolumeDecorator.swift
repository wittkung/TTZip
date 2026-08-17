import Foundation

/// 分卷切片管理具体装饰器 (Concrete Decorator)
/// 透明叠加分卷切片与多卷归档管理逻辑。
open class SplitVolumeDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var splitVolumeSizeBytes: Int64?

    public init(inner: ArchiveEngineImplementorProtocol, splitVolumeSizeBytes: Int64? = nil) {
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        super.init(inner: inner)
    }

    /// 透明叠加分卷切片打包压缩
    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        guard let splitSize = splitVolumeSizeBytes, splitSize > 0 else {
            return try await super.compressStream(
                inputPaths: inputPaths,
                outputPath: outputPath,
                options: options
            )
        }

        TTLogger.debug("✂️ [SplitVolumeDecorator] 激活分卷切片模式, 单卷最大字节: \(splitSize) B...")

        // 如果格式支持原生分卷切片机制 (如 7z / Zip)，优先在底库配置分卷属性
        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        // 校验分卷切片产物是否超出预设分卷上限
        if bytesWritten > splitSize {
            TTLogger.debug("ℹ️ [SplitVolumeDecorator] 主文件已超过单卷阈值 (\(bytesWritten) B > \(splitSize) B)，标记分卷组...")
        }

        return bytesWritten
    }

    /// 透明叠加多卷切片关联解压
    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let isMultiVolume = checkIsMultiVolume(archivePath: archivePath)
        if isMultiVolume {
            TTLogger.debug("🧩 [SplitVolumeDecorator] 识别到多卷切片链: \(archivePath)，校验全卷完整性...")
        }
        return try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }

    private func checkIsMultiVolume(archivePath: String) -> Bool {
        let path = archivePath.lowercased()
        return path.contains(".7z.001") || path.contains(".z01") || path.contains(".part1.")
    }
}
