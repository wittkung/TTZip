import Foundation

/// 标准输入/输出管道流式适配器 (Stream Pipe Adapter)
public enum StreamPipeAdapter {
    
    private static let spoolThresholdBytes: Int64 = 64 * 1024 * 1024 // 64 MB
    
    /// 检查路径是否代表标准流管道 ("-")
    public static func isStandardStream(_ path: String) -> Bool {
        return path.trimmingCharacters(in: .whitespaces) == "-"
    }
    
    /// 从标准输入流读取数据，自适应选择内存缓存或临时匿名文件
    public static func readStdinToTemporaryFileIfNeeded() throws -> (path: String, isTemporary: Bool) {
        let chunkSize = 64 * 1024 // 64 KB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("ttzip_stdin_\(UUID().uuidString).tmp")
        
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: tempFile) else {
            throw NSError(domain: "TTZipStreamPipe", code: 73, userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary stdin spool file"])
        }
        
        defer { try? handle.close() }
        
        var totalRead: Int64 = 0
        while true {
            let bytesRead = read(STDIN_FILENO, buffer, chunkSize)
            if bytesRead <= 0 { break }
            
            let data = Data(bytesNoCopy: buffer, count: bytesRead, deallocator: .none)
            handle.write(data)
            totalRead += Int64(bytesRead)
        }
        
        return (tempFile.path, true)
    }
    
    /// 清理临时流式缓存文件
    public static func cleanupTemporaryFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
