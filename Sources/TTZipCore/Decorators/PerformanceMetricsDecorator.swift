import Foundation

/// 归档性能指标统计数据结构
public struct PerformanceMetrics: Sendable, Equatable {
    public let bytesProcessed: Int64
    public let durationSeconds: Double
    public let throughputMBs: Double

    public init(bytesProcessed: Int64, durationSeconds: Double, throughputMBs: Double) {
        self.bytesProcessed = bytesProcessed
        self.durationSeconds = durationSeconds
        self.throughputMBs = throughputMBs
    }
}

/// 吞吐率 (MB/s) 与耗时瓶颈测量具体装饰器 (Concrete Decorator)
/// 透明叠加实时耗时测量、处理字节数统计与吞吐速率 (MB/s) 算力指标计算。
open class PerformanceMetricsDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastCompressMetrics: PerformanceMetrics?
    private var _lastExtractMetrics: PerformanceMetrics?

    public var lastCompressMetrics: PerformanceMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return _lastCompressMetrics
    }

    public var lastExtractMetrics: PerformanceMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return _lastExtractMetrics
    }

    private func updateCompressMetrics(_ metrics: PerformanceMetrics) {
        lock.lock()
        _lastCompressMetrics = metrics
        lock.unlock()
    }

    private func updateExtractMetrics(_ metrics: PerformanceMetrics) {
        lock.lock()
        _lastExtractMetrics = metrics
        lock.unlock()
    }

    public override init(inner: ArchiveEngineImplementorProtocol) {
        super.init(inner: inner)
    }

    /// 透明叠加性能测量的压缩处理
    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let startTime = Date()

        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytesWritten) / 1024.0 / 1024.0) / elapsed

        let metrics = PerformanceMetrics(
            bytesProcessed: bytesWritten,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )

        updateCompressMetrics(metrics)

        TTLogger.debug(String(format: "📊 [PerformanceMetricsDecorator] 压缩性能: 写入 %lld B, 耗时 %.3fs, 吞吐率 %.2f MB/s", bytesWritten, elapsed, throughput))

        return bytesWritten
    }

    /// 透明叠加性能测量的解压处理
    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let startTime = Date()

        let bytesExtracted = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytesExtracted) / 1024.0 / 1024.0) / elapsed

        let metrics = PerformanceMetrics(
            bytesProcessed: bytesExtracted,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )

        updateExtractMetrics(metrics)

        TTLogger.debug(String(format: "📊 [PerformanceMetricsDecorator] 解压性能: 提取 %lld B, 耗时 %.3fs, 吞吐率 %.2f MB/s", bytesExtracted, elapsed, throughput))

        return bytesExtracted
    }
}
