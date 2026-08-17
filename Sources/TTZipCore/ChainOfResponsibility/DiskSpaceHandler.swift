import Foundation

/// 3. 目标磁盘剩余可用空间与 APFS/HFS+ 预配校验处理者 (DiskSpaceHandler)
public final class DiskSpaceHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.fileManager = fileManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        // 确定需要校验的目标目录
        let targetDir: String
        if let dest = context.destinationPath, !dest.isEmpty {
            if fileManager.fileExists(atPath: dest) {
                targetDir = dest
            } else {
                targetDir = (dest as NSString).deletingLastPathComponent
            }
        } else if let firstSource = context.sourcePaths.first, fileManager.fileExists(atPath: firstSource) {
            targetDir = (firstSource as NSString).deletingLastPathComponent
        } else {
            targetDir = NSTemporaryDirectory()
        }
        
        let checkedDir = targetDir.isEmpty ? "." : targetDir
        let availableFreeBytes = fetchFreeDiskSpaceBytes(at: checkedDir)
        
        // 计算预估所需空间
        var requiredBytes: UInt64 = 0
        if let estimated = context.estimatedUncompressedSize, estimated > 0 {
            requiredBytes = estimated
        } else if context.operation == .compress {
            var inputBytes: UInt64 = 0
            for path in context.sourcePaths {
                inputBytes += calculatePathSize(at: path)
            }
            // 压缩操作需要至少能够容纳原始尺寸（最坏不压缩或压缩元数据开销）
            requiredBytes = inputBytes
        }
        
        // 如果无法确定所需尺寸（比如 inspect / extract 且没有提供预估尺寸），免除严格断言但要求至少 1MB 可用
        if requiredBytes == 0 {
            requiredBytes = 1024 * 1024
        }
        
        if availableFreeBytes < requiredBytes {
            return .failure(.insufficientDiskSpace(requiredBytes: requiredBytes, availableBytes: availableFreeBytes))
        }
        
        return .success
    }
    
    /// 获取指定路径挂载卷的剩余可用磁盘空间 (Bytes)，支持不存在目标路径向最近祖先递归检索
    private func fetchFreeDiskSpaceBytes(at path: String) -> UInt64 {
        let existingDir = findExistingAncestorPath(for: path)
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: existingDir),
              let freeSizeNum = attrs[.systemFreeSize] as? NSNumber else {
            return UInt64.max // 无法检测时放行
        }
        return freeSizeNum.uint64Value
    }
    
    /// 自动向上递归查找已存在的最近祖先目录路径
    private func findExistingAncestorPath(for path: String) -> String {
        var currentPath = (path as NSString).standardizingPath
        if currentPath.isEmpty { return "." }
        
        while !currentPath.isEmpty && currentPath != "/" {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: currentPath, isDirectory: &isDir) {
                return currentPath
            }
            let parent = (currentPath as NSString).deletingLastPathComponent
            if parent == currentPath { break }
            currentPath = parent
        }
        
        if currentPath == "/" && fileManager.fileExists(atPath: "/") {
            return "/"
        }
        if fileManager.fileExists(atPath: ".") {
            return "."
        }
        return NSTemporaryDirectory()
    }
    
    /// 递归计算文件或目录的总字节大小
    private func calculatePathSize(at path: String) -> UInt64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: UInt64 = 0
            if let subpaths = try? fileManager.subpathsOfDirectory(atPath: path) {
                for sub in subpaths {
                    let subPath = (path as NSString).appendingPathComponent(sub)
                    if let subAttrs = try? fileManager.attributesOfItem(atPath: subPath),
                       (subAttrs[.type] as? FileAttributeType) == .typeRegular {
                        total += (subAttrs[.size] as? UInt64) ?? 0
                    }
                }
            }
            return total
        } else {
            guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return 0 }
            return (attrs[.size] as? UInt64) ?? 0
        }
    }
}
