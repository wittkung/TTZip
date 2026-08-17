import Foundation

/// 归档校验错误类型
public enum ArchiveValidationError: Error, LocalizedError, Equatable, Sendable {
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case zipSlipDetected(path: String, detail: String)
    case symlinkEscapeDetected(path: String)
    case insufficientDiskSpace(requiredBytes: UInt64, availableBytes: UInt64)
    case invalidHeaderMagic(expected: String, actual: String)
    case licenseRequired(feature: String)
    case custom(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "校验失败: 目标路径不存在 [\(path)]"
        case .fileNotReadable(let path):
            return "校验失败: 目标文件没有可读权限 [\(path)]"
        case .zipSlipDetected(let path, let detail):
            return "安全拦截: 检测到 ZipSlip/Path Traversal 逃逸攻击 [路径: \(path), 详情: \(detail)]"
        case .symlinkEscapeDetected(let path):
            return "安全拦截: 检测到 Symlink 符号链接越界逃逸 [\(path)]"
        case .insufficientDiskSpace(let required, let available):
            let reqMB = String(format: "%.2f MB", Double(required) / 1024.0 / 1024.0)
            let availMB = String(format: "%.2f MB", Double(available) / 1024.0 / 1024.0)
            return "校验失败: 目标磁盘空间不足 (需要 \(reqMB), 可用 \(availMB))"
        case .invalidHeaderMagic(let expected, let actual):
            return "校验失败: 标头 Magic Bytes 魔数损坏或不匹配 (预期: \(expected), 实际: \(actual))"
        case .licenseRequired(let feature):
            return "许可门禁拦截: 功能 [\(feature)] 需要 TTZip Pro / Enterprise 商业授权"
        case .custom(let message):
            return "校验失败: \(message)"
        }
    }
    
    /// 转换为底层传统 ArchiveError (用于向后兼容 Legacy Facade 异常断言)
    public var asArchiveError: ArchiveError {
        switch self {
        case .fileNotFound, .fileNotReadable:
            return .fileNotFound
        case .invalidHeaderMagic:
            return .invalidFormat
        case .licenseRequired:
            return .readFailed(code: -403)
        case .zipSlipDetected, .symlinkEscapeDetected:
            return .readFailed(code: -901)
        case .insufficientDiskSpace:
            return .readFailed(code: -902)
        case .custom:
            return .readFailed(code: -999)
        }
    }
}

/// 归档校验结果
public enum ArchiveValidationResult: Equatable, Sendable {
    case success
    case failure(ArchiveValidationError)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    public var error: ArchiveValidationError? {
        if case .failure(let err) = self { return err }
        return nil
    }
}

/// 责任链处理者接口协议
public protocol ArchiveValidationHandlerProtocol: AnyObject, Sendable {
    /// 下一个处理者引用
    var nextHandler: ArchiveValidationHandlerProtocol? { get set }
    
    /// 链式装配：设置下一个 Handler 并返回该 Handler
    @discardableResult
    func setNext(handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationHandlerProtocol
    
    /// 责任链递归/下发入口
    func handle(context: ArchiveValidationContext) throws -> ArchiveValidationResult
    
    /// 当前具体 Handler 的私有业务校验逻辑
    func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult
}

/// 责任链处理者抽象基类 (Base Handler)
open class BaseArchiveValidationHandler: ArchiveValidationHandlerProtocol, @unchecked Sendable {
    private var _nextHandler: ArchiveValidationHandlerProtocol?
    private let lock = NSLock()
    
    public var nextHandler: ArchiveValidationHandlerProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _nextHandler
        }
        set {
            lock.lock()
            _nextHandler = newValue
            lock.unlock()
        }
    }
    
    public init(nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self._nextHandler = nextHandler
    }
    
    @discardableResult
    public func setNext(handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationHandlerProtocol {
        guard handler !== self else { return handler }
        self.nextHandler = handler
        return handler
    }
    
    /// 递归/下发处理入口：若当前校验通过则传递给 nextHandler，遇到失败立即可强行短路拦截
    public func handle(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        let result = try process(context: context)
        guard result.isSuccess else {
            return result
        }
        if let next = nextHandler {
            return try next.handle(context: context)
        }
        return .success
    }
    
    /// 默认基础处理逻辑（子类重写）
    open func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        return .success
    }
}
