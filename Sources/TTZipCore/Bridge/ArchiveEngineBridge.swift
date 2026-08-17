import Foundation

/// 统一底层归档解耦实现者接口 (Implementor in Bridge Pattern)
/// 将高层归档业务逻辑与底层各格式的具体算法执行彻底分离。
public protocol ArchiveEngineImplementorProtocol: Sendable {
    /// 该实现者所支持的基础归档格式
    var supportedFormat: ArchiveCompressionFormat { get }

    /// 流式归档打包压缩方法
    /// - Parameters:
    ///   - inputPaths: 要打包的目标文件或目录路径列表
    ///   - outputPath: 目标输出归档文件路径
    ///   - options: 全局高级配置选项
    /// - Returns: 生成归档文件的总字节数 (Int64)
    func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64

    /// 流式归档解压提取方法
    /// - Parameters:
    ///   - archivePath: 待解压的源归档文件路径
    ///   - destinationDir: 目标解压提取目录路径
    ///   - options: 全局高级配置选项
    /// - Returns: 解压提取出的解压数据总字节数 (Int64)
    func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64
}

// MARK: - 具体格式桥接实现者 (Concrete Implementors)

/// ZIP 归档格式桥接适配实现者
public final class ZipEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .zip
    public let zipEngine: ZipEngineProtocol

    public init(zipEngine: ZipEngineProtocol = NativeZipEngine.shared) {
        self.zipEngine = zipEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(zipEngine: zipEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zip,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .zip)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// 7z 归档格式桥接适配实现者
public final class SevenZipEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .sevenZip
    public let sevenZipEngine: SevenZipEngineProtocol

    public init(sevenZipEngine: SevenZipEngineProtocol = SevenZipParallelWriter.shared) {
        self.sevenZipEngine = sevenZipEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(sevenZipEngine: sevenZipEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .sevenZip,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .sevenZip)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Zstandard (zst) 归档格式桥接适配实现者
public final class ZstdEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .zst
    public let zstdEngine: ZstdEngineProtocol

    public init(zstdEngine: ZstdEngineProtocol = NativeZstdEngine.shared) {
        self.zstdEngine = zstdEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(zstdEngine: zstdEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zst,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .zst)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// POSIX Tar 归档格式桥接适配实现者
public final class TarEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .tar
    public let tarEngine: POSIXTarEngineProtocol

    public init(tarEngine: POSIXTarEngineProtocol = POSIXTarCAdapter.shared) {
        self.tarEngine = tarEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let success = try tarEngine.createTar(outputPath: outputPath, inputPaths: inputPaths, workingDirectory: nil)
        if !success {
            let writer = ArchiveEngineFactory.makeWriter(for: .tar)
            try writer.createArchiveSync(
                outputPath: outputPath,
                format: .tar,
                level: .normal,
                inputPaths: inputPaths,
                options: .defaultClean,
                advancedOptions: options
            )
        }
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let success = try tarEngine.extractTar(archivePath: archivePath, destinationDir: destinationDir)
        if !success {
            let extractor = ArchiveEngineFactory.makeExtractor(for: .tar)
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: .defaultClean,
                advancedOptions: options
            )
        }
        return calculateDirectorySize(at: destinationDir)
    }
}

// MARK: - 辅助计算函数

internal func calculateDirectorySize(at path: String) -> Int64 {
    let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
    return component.sizeBytes
}

// MARK: - 高层抽象基类 (Abstraction in Bridge Pattern)

/// 高层归档业务抽象基类
/// 持有一个 `ArchiveEngineImplementorProtocol` 实例，使业务逻辑（如指标统计、参数处理、转换等）
/// 与底层具体的算法格式引擎解耦，两者可独立演进。
open class ArchiveOperationAbstraction: @unchecked Sendable {
    private let lock = NSLock()
    private var _implementor: ArchiveEngineImplementorProtocol

    public var implementor: ArchiveEngineImplementorProtocol {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _implementor
        }
        set {
            lock.lock()
            _implementor = newValue
            lock.unlock()
        }
    }

    public init(implementor: ArchiveEngineImplementorProtocol) {
        self._implementor = implementor
    }

    /// 动态切换底层实现者 (Bridge Pattern 核心特性: 动态解耦)
    @discardableResult
    public func setImplementor(_ newImplementor: ArchiveEngineImplementorProtocol) -> Self {
        lock.lock()
        _implementor = newImplementor
        lock.unlock()
        return self
    }

    /// 统一高层压缩业务逻辑
    open func compress(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> Int64 {
        let currentImpl = implementor
        return try await currentImpl.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )
    }

    /// 统一高层解压业务逻辑
    open func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> Int64 {
        let currentImpl = implementor
        return try await currentImpl.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}

/// 精化归档操作管道抽象 (Refined Abstraction in Bridge Pattern)
/// 在基础抽象的基础上扩展吞吐率测量与双向流式验证能力
open class AdvancedArchiveOperationPipelineAbstraction: ArchiveOperationAbstraction, @unchecked Sendable {
    /// 执行压缩并测量详细性能指标
    open func compressWithMetrics(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> (bytesWritten: Int64, durationSeconds: Double, throughputMBs: Double) {
        let startTime = Date()
        let bytes = try await compress(inputPaths: inputPaths, outputPath: outputPath, options: options)
        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytes) / 1024.0 / 1024.0) / elapsed
        return (bytesWritten: bytes, durationSeconds: elapsed, throughputMBs: throughput)
    }

    /// 执行解压并测量详细性能指标
    open func extractWithMetrics(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> (bytesExtracted: Int64, durationSeconds: Double, throughputMBs: Double) {
        let startTime = Date()
        let bytes = try await extract(archivePath: archivePath, destinationDir: destinationDir, options: options)
        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytes) / 1024.0 / 1024.0) / elapsed
        return (bytesExtracted: bytes, durationSeconds: elapsed, throughputMBs: throughput)
    }
}
