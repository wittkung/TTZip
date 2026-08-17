import Foundation

/// 经典软件设计模式实现库: 策略模式与工厂模式 (Strategy Pattern & Factory Pattern)
public enum ArchiveEngineFactory {
    
    /// 获取当前活动的产品族工厂 (Abstract Factory)
    public static var currentFamilyFactory: ArchiveEngineFamilyFactoryProtocol {
        return ArchiveEngineFamilyProvider.shared.currentFactory
    }

    /// 根据封装格式为写归档创建最优压缩引擎策略实例 (Factory Method -> Abstract Factory)
    public static func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return currentFamilyFactory.makeWriter(for: format)
    }
    
    /// 根据封装格式为解压提取归档创建最优解压引擎策略实例 (Factory Method -> Abstract Factory)
    public static func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return currentFamilyFactory.makeExtractor(for: format)
    }
    
    /// 根据封装格式为文件目录检查创建最优读取引擎策略实例 (Factory Method -> Abstract Factory)
    public static func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return currentFamilyFactory.makeReader(for: format)
    }

    /// 根据归档格式构建专属格式处理策略实例 (Strategy Factory Method)
    public static func makeStrategy(for format: ArchiveCompressionFormat) -> ArchiveFormatEngineStrategy {
        switch format {
        case .zip:
            return ZipFormatEngineStrategy()
        case .sevenZip:
            return SevenZipFormatEngineStrategy()
        case .zst:
            return ZstdFormatEngineStrategy()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .tarZst, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarFormatEngineStrategy(format: format)
        }
    }

    /// 根据输入文件路径类型自动查验并构建格式策略 (Strategy Discovery Factory)
    public static func makeStrategy(for path: String) -> ArchiveFormatEngineStrategy? {
        return ArchiveEngineRegistry.shared.findExtractor(for: path)
    }

    /// 创建完整性校验引擎抽象实例 (Factory Method -> Abstract Factory)
    public static func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return currentFamilyFactory.makeIntegrityChecker()
    }

    /// 创建硬件级哈希计算引擎抽象实例 (Factory Method -> Abstract Factory)
    public static func makeHashCalculator(hardwareTuner: HardwareTunerProtocol? = nil) -> HashCalculating {
        if let tuner = hardwareTuner {
            return HashCalculator(hardwareTuner: tuner)
        }
        return currentFamilyFactory.makeHashCalculator()
    }

    // MARK: - 桥接模式工厂方法 (Bridge Pattern Factory Methods)

    /// 根据封装格式为底层算法执行创建桥接实现者实例 (Factory Method -> Bridge Pattern -> Abstract Factory)
    public static func makeImplementor(for format: ArchiveCompressionFormat = .zip) -> ArchiveEngineImplementorProtocol {
        return currentFamilyFactory.makeImplementor(for: format)
    }

    /// 根据封装格式构建高层归档操作抽象实例 (Factory Method -> Bridge Pattern Abstraction)
    public static func makeOperationAbstraction(for format: ArchiveCompressionFormat = .zip) -> ArchiveOperationAbstraction {
        let implementor = makeImplementor(for: format)
        return ArchiveOperationAbstraction(implementor: implementor)
    }

    // MARK: - 装饰器模式工厂方法 (Decorator Pattern Factory Methods)

    /// 构建按需叠加动态扩展装饰器链的实现者 (Factory Method -> Decorator Pattern Chain)
    public static func makeDecoratedImplementor(
        for format: ArchiveCompressionFormat = .zip,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil,
        enableChecksum: Bool = false,
        enableMetrics: Bool = false
    ) -> ArchiveEngineImplementorProtocol {
        var engine: ArchiveEngineImplementorProtocol = makeImplementor(for: format)
        if let pwd = password, !pwd.isEmpty {
            engine = engine.withEncryption(password: pwd)
        }
        if let splitSize = splitVolumeSizeBytes, splitSize > 0 {
            engine = engine.withSplitVolume(splitVolumeSizeBytes: splitSize)
        }
        if let handler = progressHandler {
            engine = engine.withProgressMonitoring(progressHandler: handler)
        }
        if enableChecksum {
            engine = engine.withChecksumVerification()
        }
        if enableMetrics {
            engine = engine.withPerformanceMetrics()
        }
        return engine
    }
}

/// 仓库模式 (Repository Pattern) 别名兼容
public typealias PresetRepositoryProtocol = ArchivePresetRepositoryProtocol

