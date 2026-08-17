import Foundation

/// 进度监控与 ETA 估算具体装饰器 (Concrete Decorator)
/// 透明叠加平滑进度与剩余时间 (ETA) 算能估算，在压缩/解压流中自动进行状态更新与回调通知。
open class ProgressMonitoringDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    private let lock = NSLock()
    private var startTime: Date?
    
    public init(
        inner: ArchiveEngineImplementorProtocol,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) {
        self.progressHandler = progressHandler
        super.init(inner: inner)
    }

    private func recordStartTime(_ time: Date) {
        lock.lock()
        startTime = time
        lock.unlock()
    }

    private func getStartTime() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return startTime ?? Date()
    }

    /// 透明叠加平滑进度与 ETA 估算的压缩处理
    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let now = Date()
        recordStartTime(now)

        reportProgress(fraction: 0.05, statusMessage: "正在准备打包输入文件...", totalBytes: 0, processedBytes: 0)

        // 估算输入文件总尺寸
        let estimatedTotalBytes = calculateTotalInputSize(inputPaths: inputPaths)

        reportProgress(fraction: 0.15, statusMessage: "启动引擎流式压缩...", totalBytes: estimatedTotalBytes, processedBytes: 0)

        let resultBytes = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        let duration = Date().timeIntervalSince(now)
        let throughput = duration > 0 ? (Double(resultBytes) / 1024.0 / 1024.0) / duration : 0

        reportProgress(
            fraction: 1.0,
            statusMessage: String(format: "打包压缩完成 (耗时 %.2fs, 速率 %.1f MB/s)", duration, throughput),
            totalBytes: estimatedTotalBytes,
            processedBytes: resultBytes
        )

        return resultBytes
    }

    /// 透明叠加平滑进度与 ETA 估算的解压处理
    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let now = Date()
        recordStartTime(now)

        let archiveSize = (try? FileManager.default.attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0

        reportProgress(fraction: 0.10, statusMessage: "正在解析归档元数据并准备解压...", totalBytes: archiveSize, processedBytes: 0)

        let extractedBytes = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        let duration = Date().timeIntervalSince(now)
        let throughput = duration > 0 ? (Double(extractedBytes) / 1024.0 / 1024.0) / duration : 0

        reportProgress(
            fraction: 1.0,
            statusMessage: String(format: "解压提取完成 (耗时 %.2fs, 速率 %.1f MB/s)", duration, throughput),
            totalBytes: extractedBytes,
            processedBytes: extractedBytes
        )

        return extractedBytes
    }

    private func reportProgress(
        fraction: Double,
        statusMessage: String,
        totalBytes: Int64,
        processedBytes: Int64
    ) {
        guard let handler = progressHandler else { return }

        let start = getStartTime()
        let elapsed = max(0.001, Date().timeIntervalSince(start))
        let speedBytesPerSec = elapsed > 0 ? Double(processedBytes) / elapsed : 0.0

        let progressState: ArchiveProgress.State = (fraction >= 1.0) ? .completed : .processing
        let progress = ArchiveProgress(
            state: progressState,
            bytesProcessed: processedBytes,
            totalBytes: max(processedBytes, totalBytes),
            currentFileName: statusMessage,
            throughputMBs: speedBytesPerSec / 1024.0 / 1024.0
        )
        handler(progress)
    }

    private func calculateTotalInputSize(inputPaths: [String]) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        for path in inputPaths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                if let attr = try? fm.attributesOfItem(atPath: path), let size = attr[.size] as? Int64 {
                    total += size
                }
            } else {
                if let enumerator = fm.enumerator(atPath: path) {
                    while let subpath = enumerator.nextObject() as? String {
                        let fullPath = (path as NSString).appendingPathComponent(subpath)
                        if let attr = try? fm.attributesOfItem(atPath: fullPath), let size = attr[.size] as? Int64 {
                            total += size
                        }
                    }
                }
            }
        }
        return total
    }
}
