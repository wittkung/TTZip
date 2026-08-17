import Foundation

// MARK: - Standard Portable Tuner Implementation

/// 标准/通用 Portable 硬件调优策略实现 (跨平台与 Standard Fallback 模式)
public final class StandardPortableTuner: HardwareTunerProtocol, @unchecked Sendable {
    public static let shared = StandardPortableTuner()
    
    private init() {}
    
    public var totalCores: Int {
        return max(1, ProcessInfo.processInfo.processorCount)
    }
    
    public var optimalZstdLongWindowLog: Int {
        return 0 // 标准 portable 模式下不启用 128GB 高级 LDM 匹配
    }
    
    public var optimalAlignedBufferSize: Int {
        return 64 * 1024 // 64KB 标准通用 I/O 缓冲区
    }
    
    public func boostCurrentThreadPriority() {
        // Portable 模式保持默认 QoS
    }
}

// MARK: - Abstract Factory Pattern Protocol

/// 归档引擎产品族抽象工厂协议 (Abstract Factory Pattern)
/// 定义创建一整套相互依赖/相互关联引擎产品族的方法
public protocol ArchiveEngineFamilyFactoryProtocol: Sendable {
    /// 获取与该引擎产品族锁定的硬件调优器 (Hardware Tuner)
    var tuner: HardwareTunerProtocol { get }
    /// 创建归档打包/压缩引擎产品
    func makeWriter(for format: ArchiveCompressionFormat?) -> ArchiveWriting
    /// 创建归档解压/提取引擎产品
    func makeExtractor(for format: ArchiveCompressionFormat?) -> ArchiveExtracting
    /// 创建归档目录结构读取引擎产品
    func makeReader(for format: ArchiveCompressionFormat?) -> ArchiveReading
    /// 创建底层算法桥接实现者产品 (Bridge Pattern Implementor)
    func makeImplementor(for format: ArchiveCompressionFormat?) -> ArchiveEngineImplementorProtocol
    /// 创建数据完整性校验引擎产品
    func makeIntegrityChecker() -> ArchiveIntegrityChecking
    /// 创建哈希与散列计算引擎产品
    func makeHashCalculator() -> HashCalculating
}

public extension ArchiveEngineFamilyFactoryProtocol {
    func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return makeWriter(for: format)
    }
    func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return makeExtractor(for: format)
    }
    func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return makeReader(for: format)
    }
    func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        return makeImplementor(for: format)
    }
}

// MARK: - Concrete Engine Family Factories

/// Apple Silicon 硬件加速引擎族工厂 (Apple Silicon Accelerated Family Factory)
/// 构建全硬件加速、物理页对齐 (16KB)、NEON SIMD 与 APFS 预分配的产品族体系
public final class AppleSiliconAcceleratedEngineFactory: ArchiveEngineFamilyFactoryProtocol, @unchecked Sendable {
    public static let shared = AppleSiliconAcceleratedEngineFactory()
    
    public let tuner: HardwareTunerProtocol
    
    public init(tuner: HardwareTunerProtocol = AppleSiliconTuner.shared) {
        self.tuner = tuner
    }
    
    public func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return ArchiveWriter(
            zipEngine: NativeZipEngine.shared,
            sevenZipEngine: SevenZipParallelWriter.shared,
            zstdEngine: NativeZstdEngine.shared,
            hardwareTuner: tuner,
            targetFormat: format
        )
    }
    
    public func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return ArchiveExtractor(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return ArchiveReader(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        let targetFmt = format ?? .zip
        switch targetFmt {
        case .zip:
            return ZipEngineBridgeImplementor()
        case .sevenZip:
            return SevenZipEngineBridgeImplementor()
        case .zst, .tarZst:
            return ZstdEngineBridgeImplementor()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarEngineBridgeImplementor()
        }
    }
    
    public func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return ArchiveIntegrityChecker(hashCalculator: makeHashCalculator())
    }
    
    public func makeHashCalculator() -> HashCalculating {
        return HashCalculator(hardwareTuner: tuner)
    }
}

/// 标准/通用 Portable 引擎族工厂 (Standard Portable Family Factory)
/// 构建环境无关、标准 fallback 压缩/解压/校验器产品族体系
public final class StandardPortableEngineFactory: ArchiveEngineFamilyFactoryProtocol, @unchecked Sendable {
    public static let shared = StandardPortableEngineFactory()
    
    public let tuner: HardwareTunerProtocol
    
    public init(tuner: HardwareTunerProtocol = StandardPortableTuner.shared) {
        self.tuner = tuner
    }
    
    public func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return ArchiveWriter(
            zipEngine: NativeZipEngine.shared,
            sevenZipEngine: SevenZipParallelWriter.shared,
            zstdEngine: NativeZstdEngine.shared,
            hardwareTuner: tuner,
            targetFormat: format
        )
    }
    
    public func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return ArchiveExtractor(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return ArchiveReader(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        let targetFmt = format ?? .zip
        switch targetFmt {
        case .zip:
            return ZipEngineBridgeImplementor()
        case .sevenZip:
            return SevenZipEngineBridgeImplementor()
        case .zst, .tarZst:
            return ZstdEngineBridgeImplementor()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarEngineBridgeImplementor()
        }
    }
    
    public func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return ArchiveIntegrityChecker(hashCalculator: makeHashCalculator())
    }
    
    public func makeHashCalculator() -> HashCalculating {
        return HashCalculator(hardwareTuner: tuner)
    }
}

// MARK: - Engine Family Provider & Environment Awareness

/// 引擎族选择模式
public enum EngineFamilyMode: String, Sendable, CaseIterable {
    /// 自动根据硬件拓扑识别 (Apple Silicon 优先硬件加速族，其余使用标准 Portable 族)
    case auto
    /// 强制使用 Apple Silicon 硬件加速族
    case appleSiliconAccelerated
    /// 强制使用标准 Portable 通用族
    case standardPortable
}

/// 环境感知与工厂选择器 (Archive Engine Family Provider)
/// 负责根据硬件拓扑或配置要求，动态返回最优产品族工厂，支持运行时无缝切换
public final class ArchiveEngineFamilyProvider: @unchecked Sendable {
    public static let shared = ArchiveEngineFamilyProvider()
    
    private let lock = NSLock()
    private var _mode: EngineFamilyMode = .auto
    private var _overrideFactory: ArchiveEngineFamilyFactoryProtocol?
    
    private init() {}
    
    /// 当前引擎族配置模式
    public var mode: EngineFamilyMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mode
        }
        set {
            lock.lock()
            _mode = newValue
            lock.unlock()
        }
    }
    
    /// 设置自定义覆盖工厂 (通常用于 Mock 或测试隔离)
    public func setOverrideFactory(_ factory: ArchiveEngineFamilyFactoryProtocol?) {
        lock.lock()
        defer { lock.unlock() }
        _overrideFactory = factory
    }
    
    /// 重置 Provider 状态 (加锁重置 mode 为 .auto，重置 overrideFactory 为 nil)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _mode = .auto
        _overrideFactory = nil
    }
    
    /// 获取当前环境推荐或配置指定的产品族工厂
    public var currentFactory: ArchiveEngineFamilyFactoryProtocol {
        lock.lock()
        if let override = _overrideFactory {
            lock.unlock()
            return override
        }
        let currentMode = _mode
        lock.unlock()
        
        switch currentMode {
        case .appleSiliconAccelerated:
            return AppleSiliconAcceleratedEngineFactory.shared
        case .standardPortable:
            return StandardPortableEngineFactory.shared
        case .auto:
            if isAppleSiliconEnvironment {
                return AppleSiliconAcceleratedEngineFactory.shared
            } else {
                return StandardPortableEngineFactory.shared
            }
        }
    }
    
    /// 监测当前宿主是否属于 Apple Silicon 硬件环境
    public var isAppleSiliconEnvironment: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}
