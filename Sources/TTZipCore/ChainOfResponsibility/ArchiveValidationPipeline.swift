import Foundation

/// 责任链调度门面与装配器 (ArchiveValidationPipeline)
public final class ArchiveValidationPipeline: @unchecked Sendable {
    private var handlers: [ArchiveValidationHandlerProtocol]
    private let lock = NSLock()
    
    public init(handlers: [ArchiveValidationHandlerProtocol] = []) {
        self.handlers = handlers
    }
    
    /// 动态添加处理者（自动防护重复实例注册）
    @discardableResult
    public func addHandler(_ handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationPipeline {
        lock.lock()
        defer { lock.unlock() }
        if !handlers.contains(where: { $0 === handler }) {
            handlers.append(handler)
        }
        return self
    }
    
    /// 清空所有处理者
    public func clearHandlers() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }
    
    /// 获取已装配的处理者数量
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return handlers.count
    }
    
    /// 责任链按顺序递归校验执行
    public func validate(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        lock.lock()
        let pipelineHandlers = self.handlers
        lock.unlock()
        
        guard !pipelineHandlers.isEmpty else {
            return .success
        }
        
        for handler in pipelineHandlers {
            let result = try handler.process(context: context)
            if !result.isSuccess {
                return result
            }
        }
        
        return .success
    }
    
    /// 执行校验，遇到拦截错误直接抛出 ArchiveValidationError 异常
    public func validateOrThrow(context: ArchiveValidationContext) throws {
        let result = try validate(context: context)
        if case .failure(let error) = result {
            throw error
        }
    }
    
    // MARK: - 静态标准责任链工厂构建器 (Pipeline Builders)
    
    private static let _cachedCompressPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedExtractPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ArchiveHeaderMagicHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedInspectPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ArchiveHeaderMagicHandler(),
        ZipSlipSecurityHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedRepairPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    /// 构建默认打包压缩前置校验管道
    @inline(__always)
    public static func buildDefaultCompressPipeline() -> ArchiveValidationPipeline {
        return _cachedCompressPipeline
    }
    
    /// 构建默认解压提取前置校验管道
    @inline(__always)
    public static func buildDefaultExtractPipeline() -> ArchiveValidationPipeline {
        return _cachedExtractPipeline
    }
    
    /// 构建默认归档探索检测前置校验管道
    @inline(__always)
    public static func buildDefaultInspectPipeline() -> ArchiveValidationPipeline {
        return _cachedInspectPipeline
    }
    
    /// 构建默认归档修复恢复前置校验管道
    @inline(__always)
    public static func buildDefaultRepairPipeline() -> ArchiveValidationPipeline {
        return _cachedRepairPipeline
    }
}
