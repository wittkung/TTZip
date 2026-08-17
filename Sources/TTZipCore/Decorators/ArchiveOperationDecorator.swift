import Foundation

/// 归档操作基础装饰器抽象 (Base Decorator in Decorator Pattern)
/// 遵循 `ArchiveEngineImplementorProtocol` 接口，持有一份内层 `inner` 实现者的引用。
/// 所有具体的装饰器扩展类继承该基类，并透传或重写 `compressStream` 与 `extractStream` 行为。
open class ArchiveOperationDecorator: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    /// 持有的被包装组件（可以是一个基础 Implementor，也可以是另一个 Decorator，形成 Decorator Chain）
    public var inner: ArchiveEngineImplementorProtocol

    public init(inner: ArchiveEngineImplementorProtocol) {
        self.inner = inner
    }

    /// 对应的归档格式，透传至内层组件
    open var supportedFormat: ArchiveCompressionFormat {
        return inner.supportedFormat
    }

    /// 基础压缩流透传
    open func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        return try await inner.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )
    }

    /// 基础解压流透传
    open func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        return try await inner.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}

// MARK: - Fluent Chaining API (装饰器链式叠加扩展)

extension ArchiveEngineImplementorProtocol {
    /// 叠加透明加密/解密装饰器
    public func withEncryption(password: String?) -> EncryptionDecorator {
        return EncryptionDecorator(inner: self, password: password)
    }

    /// 叠加平滑进度监控与 ETA 估算装饰器
    public func withProgressMonitoring(
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) -> ProgressMonitoringDecorator {
        return ProgressMonitoringDecorator(inner: self, progressHandler: progressHandler)
    }

    /// 叠加分卷切片管理装饰器
    public func withSplitVolume(splitVolumeSizeBytes: Int64?) -> SplitVolumeDecorator {
        return SplitVolumeDecorator(inner: self, splitVolumeSizeBytes: splitVolumeSizeBytes)
    }

    /// 叠加数据校验和 (CRC32/SHA256) 实时校验装饰器
    public func withChecksumVerification(algorithm: HashType = .crc32) -> ChecksumVerificationDecorator {
        return ChecksumVerificationDecorator(inner: self, algorithm: algorithm)
    }

    /// 叠加吞吐率 (MB/s) 与耗时瓶颈测量装饰器
    public func withPerformanceMetrics() -> PerformanceMetricsDecorator {
        return PerformanceMetricsDecorator(inner: self)
    }
}
