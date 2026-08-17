import Foundation

/// 归档格式压缩与解压引擎统一策略接口 (结合 Strategy Pattern 与 Bridge Pattern)
public protocol ArchiveFormatEngineStrategy: Sendable {
    /// 该策略支持的归档格式
    var format: ArchiveCompressionFormat { get }
    
    /// 该策略关联的 Bridge 桥接实现者 (Bridge Implementor)
    var bridgeImplementor: ArchiveEngineImplementorProtocol { get }

    /// 该策略绑定的模板方法模式骨架 (Template Method Pattern Engine)
    var engineTemplate: BaseArchiveEngineTemplate { get }
    
    /// 判断给定的文件路径是否符合该策略处理范围
    func canHandle(path: String) -> Bool
    
    /// 执行解压操作
    func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool
    
    /// 执行压缩操作
    func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool
}

/// 归档引擎策略集中注册表
public final class ArchiveEngineRegistry: @unchecked Sendable {
    public static let shared = ArchiveEngineRegistry()
    private let lock = NSLock()
    private var strategies: [ArchiveFormatEngineStrategy] = []
    
    private init() {
        registerDefaultStrategies()
    }
    
    private func registerDefaultStrategies() {
        strategies = [
            ZipFormatEngineStrategy(),
            SevenZipFormatEngineStrategy(),
            TarFormatEngineStrategy(),
            ZstdFormatEngineStrategy()
        ]
    }
    
    /// 注册格式处理策略
    public func register(strategy: ArchiveFormatEngineStrategy) {
        lock.lock()
        defer { lock.unlock() }
        strategies.append(strategy)
    }
    
    /// 查找能处理特定路径的解压策略
    public func findExtractor(for path: String) -> ArchiveFormatEngineStrategy? {
        lock.lock()
        defer { lock.unlock() }
        return strategies.first(where: { $0.canHandle(path: path) })
    }
    
    /// 根据底层硬件拓扑与 Payload 动态推荐最优压缩算法策略 (结合 CompressionStrategyContext 策略模式)
    public func selectOptimalCompressionStrategy(
        inputPaths: [String],
        targetFormat: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel = .normal
    ) -> CompressionStrategyProtocol {
        return CompressionStrategyContext.shared.selectOptimalStrategy(
            inputPaths: inputPaths,
            targetFormat: targetFormat,
            level: level
        )
    }
}

// MARK: - 针对各格式的具体策略实现 (Concrete Format Engine Strategies)

private final class StrategySyncBox<T>: @unchecked Sendable {
    var value: T?
    var error: Error?
}

private func executeStrategyBridgeSync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
    let box = StrategySyncBox<T>()
    let sema = DispatchSemaphore(value: 0)
    Task.detached {
        do {
            box.value = try await block()
        } catch {
            box.error = error
        }
        sema.signal()
    }
    sema.wait()
    if let val = box.value { return val }
    if let err = box.error { throw err }
    throw ArchiveError.readFailed(code: -999)
}

/// Zip 归档格式专属策略实现
public final class ZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zip),
        engineTemplate: BaseArchiveEngineTemplate = ZipArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".zip") || lower.hasSuffix(".jar") || lower.hasSuffix(".apk") || lower.hasSuffix(".epub") || lower.hasSuffix(".docx") || lower.hasSuffix(".xlsx")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.zip,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.zip,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// 7z 归档格式专属策略实现
public final class SevenZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .sevenZip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .sevenZip),
        engineTemplate: BaseArchiveEngineTemplate = SevenZipArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) || lower.contains(".7z.")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.sevenZip,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.sevenZip,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// Tar 衍生系列归档格式专属策略实现
public final class TarFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        format: ArchiveCompressionFormat = .tar,
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .tar),
        engineTemplate: BaseArchiveEngineTemplate = TarArchiveEngineTemplate()
    ) {
        self.format = format
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { lower.hasSuffix($0) })
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: format,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// Zstandard (zst) 归档格式专属策略实现
public final class ZstdFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zst
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zst),
        engineTemplate: BaseArchiveEngineTemplate = TarArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        return path.lowercased().hasSuffix(".zst")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.zst,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.zst,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}
