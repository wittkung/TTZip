import Foundation

/// 使用 RAII 模式隔离管理测试临时目录，确保每次基准测试迭代具有完全独立且干净的物理环境
public final class IsolatedTempSandbox: @unchecked Sendable {
    public let url: URL
    private var isCleaned: Bool = false
    
    public var path: String {
        return url.path
    }
    
    public init(prefix: String = "sandbox") throws {
        let uniqueDirName = "TTZip_\(prefix)_\(UUID().uuidString)"
        self.url = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueDirName)
        try FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true)
    }
    
    /// 在沙盒内创建子目录
    public func createSubdirectory(_ name: String) throws -> URL {
        let subDir = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        return subDir
    }
    
    /// 在沙盒内生成指定文件路径
    public func fileURL(named filename: String) -> URL {
        return url.appendingPathComponent(filename)
    }
    
    /// 显式清理临时沙盒
    public func cleanup() {
        guard !isCleaned else { return }
        isCleaned = true
        try? FileManager.default.removeItem(at: url)
    }
    
    deinit {
        cleanup()
    }
}
