import Foundation

/// 1. 文件存在性与读取权限具体校验处理者 (FileExistenceHandler)
public final class FileExistenceHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.fileManager = fileManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        guard !context.sourcePaths.isEmpty else {
            return .failure(.fileNotFound(path: "NO_INPUT_PATHS"))
        }
        
        switch context.operation {
        case .compress:
            for path in context.sourcePaths {
                guard fileManager.fileExists(atPath: path) else {
                    return .failure(.fileNotFound(path: path))
                }
                guard fileManager.isReadableFile(atPath: path) else {
                    return .failure(.fileNotReadable(path: path))
                }
            }
            
        case .extract, .inspect, .repair:
            guard let primaryPath = context.sourcePaths.first else {
                return .failure(.fileNotFound(path: "NO_PRIMARY_ARCHIVE_PATH"))
            }
            guard fileManager.fileExists(atPath: primaryPath) else {
                return .failure(.fileNotFound(path: primaryPath))
            }
            guard fileManager.isReadableFile(atPath: primaryPath) else {
                return .failure(.fileNotReadable(path: primaryPath))
            }
        }
        
        if let dest = context.destinationPath, !dest.isEmpty {
            let parentDir = (dest as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && !fileManager.fileExists(atPath: parentDir) {
                // 如果父目录不存在，尝试检查父目录的祖先路径或是否可创建
                let grandparent = (parentDir as NSString).deletingLastPathComponent
                if !grandparent.isEmpty && fileManager.fileExists(atPath: grandparent) {
                    if !fileManager.isWritableFile(atPath: grandparent) {
                        return .failure(.fileNotReadable(path: dest))
                    }
                }
            }
        }
        
        return .success
    }
}
