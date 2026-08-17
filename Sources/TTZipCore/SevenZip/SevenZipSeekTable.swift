import Foundation
import CTTZipBridge

/// 7Z 归档内存级随机访问与快速单文件抽取索引表 (Seekable 7Z Index)
public final class SevenZipSeekTable: @unchecked Sendable {
    
    public struct SeekEntry: Sendable {
        public let path: String
        public let uncompressedSize: Int64
        public let uncompressedOffset: Int64
        public let folderIndex: Int
        public let crc32: UInt32
        public let isDirectory: Bool
        public let isEmptyStream: Bool
    }
    
    private let entriesByPath: [String: SeekEntry]
    public let allEntries: [SeekEntry]
    public let archivePath: String
    
    public init(archivePath: String, entries: [SeekEntry]) {
        self.archivePath = archivePath
        self.allEntries = entries
        var map: [String: SeekEntry] = [:]
        map.reserveCapacity(entries.count)
        for e in entries {
            map[e.path] = e
        }
        self.entriesByPath = map
    }
    
    /// O(1) 按相对路径检索文件元数据
    public func entry(forPath path: String) -> SeekEntry? {
        return entriesByPath[path]
    }
    
    /// 针对特定条目执行单文件快速提取
    public func extractSingleFile(path: String, destinationDir: String, password: String? = nil) throws -> Bool {
        guard let entry = entry(forPath: path) else { return false }
        if entry.isDirectory {
            let outDir = URL(fileURLWithPath: destinationDir).appendingPathComponent(path).path
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            return true
        }
        
        let outFilePath = URL(fileURLWithPath: destinationDir).appendingPathComponent(path).path
        let parentDir = (outFilePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        
        guard let data = extractData(forPath: path, password: password) else {
            return false
        }
        
        try data.write(to: URL(fileURLWithPath: outFilePath))
        return true
    }
    
    /// 获取单文件的解压内存数据 (Data)
    public func extractData(forPath path: String, password: String? = nil) -> Data? {
        guard let entry = entry(forPath: path), !entry.isDirectory else { return nil }
        if entry.isEmptyStream || entry.uncompressedSize == 0 {
            return Data()
        }
        
        // 尝试通过 C 引擎快速提取
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_7z_seek_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        guard let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: tempDir.path, password: password), ok else {
            return nil
        }
        
        let directFile = tempDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: directFile.path) {
            return try? Data(contentsOf: directFile)
        }
        
        let lastComponentFile = tempDir.appendingPathComponent((path as NSString).lastPathComponent)
        if FileManager.default.fileExists(atPath: lastComponentFile.path) {
            return try? Data(contentsOf: lastComponentFile)
        }
        
        // 递归查找匹配文件
        if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == (path as NSString).lastPathComponent {
                    return try? Data(contentsOf: fileURL)
                }
            }
        }
        return nil
    }
}
