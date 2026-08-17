import Foundation

/// 归档包内文档双击编辑与监视刷回引擎 (File System Watcher & Incremental Save)
public final class FileWatcherEngine: @unchecked Sendable {
    public static let shared = FileWatcherEngine()
    
    private var activeSources: [String: DispatchSourceFileSystemObject] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 开始监视解压至临时目录的特定文件，在用户修改保存后自动感应并更新归档包
    public func watchFileForChanges(
        filePath: String,
        targetArchivePath: String,
        onFileModified: @escaping @Sendable (String, String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: DispatchQueue.global(qos: .default)
        )
        
        source.setEventHandler { [weak self] in
            onFileModified(filePath, targetArchivePath)
            self?.stopWatching(filePath: filePath)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        activeSources[filePath] = source
        source.resume()
    }
    
    public func stopWatching(filePath: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let source = activeSources.removeValue(forKey: filePath) {
            source.cancel()
        }
    }
    
    /// 停止所有在播监视源并释放句柄 (用于测试重置与全局清理)
    public func stopAllWatching() {
        lock.lock()
        let sources = Array(activeSources.values)
        activeSources.removeAll()
        lock.unlock()
        
        for source in sources {
            source.cancel()
        }
    }
    
    /// 重置 FileWatcherEngine 状态 (别名，统一 reset 测试重置接口)
    public func reset() {
        stopAllWatching()
    }
}
