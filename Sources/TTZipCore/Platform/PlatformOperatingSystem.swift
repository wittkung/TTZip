import Foundation

/// 跨平台操作系统环境标识中枢
public enum PlatformOperatingSystem: String, Sendable, Codable, CaseIterable {
    case macOS = "macOS"
    case windows = "Windows"
    case linux = "Linux"
    case unknown = "Unknown"
    
    /// 当前编译与运行时所处的操作系统
    public static var current: PlatformOperatingSystem {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .unknown
        #endif
    }
    
    /// 是否为 POSIX 兼容系统 (macOS / Linux / BSD)
    @inlinable
    public var isPOSIX: Bool {
        return self == .macOS || self == .linux
    }
    
    /// 是否为 Windows 平台
    @inlinable
    public var isWindows: Bool {
        return self == .windows
    }
    
    /// 平台默认物理页对齐大小 (Apple Silicon: 16KB, Windows/Generic: 4KB)
    @inlinable
    public var defaultPageAlignment: Int {
        #if os(macOS) && arch(arm64)
        return 16384
        #else
        return 4096
        #endif
    }
}
