import Foundation

/// 统一 6 级归档操作与状态码枚举
///
/// 对标 libarchive `archive.h` 经典状态码体系 (`ARCHIVE_OK`, `ARCHIVE_EOF`, `ARCHIVE_WARN`, `ARCHIVE_FAILED`, `ARCHIVE_FATAL`)
public enum TTZipStatus: Int32, Sendable, Codable, Equatable {
    /// 归档流正常结束 (End of Archive)
    case eof = 1
    
    /// 操作完全成功 (Success)
    case ok = 0
    
    /// 瞬态等待或资源争用，重试可能成功 (Transient Retry)
    case retry = -10
    
    /// 局部非致命警告（如未识别的扩展属性或非关键元数据截断，可继续读取）
    case warn = -20
    
    /// 单个条目解析失败或数据块损坏（禁止读取当前 payload，但允许跳过并恢复解析后续条目）
    case failed = -25
    
    /// 致命不可逆错误（归档彻底损坏或 I/O 中断，句柄已失效）
    case fatal = -30
    
    /// 是否为致命不可逆错误
    public var isFatal: Bool {
        return self == .fatal
    }
    
    /// 是否允许启动数据恢复状态机继续解压后续文件
    public var allowsDataRecovery: Bool {
        return self == .warn || self == .failed
    }
}

/// 归档引擎内部状态机
public struct TTZipEngineState: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let initial      = TTZipEngineState(rawValue: 1 << 0) // 新建句柄
    public static let header       = TTZipEngineState(rawValue: 1 << 1) // 正在读取/写入标头
    public static let data         = TTZipEngineState(rawValue: 1 << 2) // 正在读取/写入数据载荷
    public static let dataRecovery = TTZipEngineState(rawValue: 1 << 3) // 处于跳过坏块恢复模式
    public static let eof          = TTZipEngineState(rawValue: 1 << 4) // 归档结束
    public static let closed       = TTZipEngineState(rawValue: 1 << 5) // 已安全关闭
    public static let fatalError   = TTZipEngineState(rawValue: 1 << 15) // 致命崩溃锁定
}
