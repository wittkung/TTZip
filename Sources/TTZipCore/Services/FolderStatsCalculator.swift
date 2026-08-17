import Foundation

/// 文件夹与归档结构度量计算器 (配合 Composite Pattern 组合模式)
public final class FolderStatsCalculator: @unchecked Sendable {
    
    /// 对任意 ArchiveComponentProtocol (Composite 树节点或 Leaf 节点) 进行统计度量
    public static func calculateStats(for component: ArchiveComponentProtocol) -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) {
        let visitor = FolderStatsVisitor()
        let res = component.accept(visitor: visitor)
        return (size: res.totalSizeBytes, subfolders: res.totalDirectories, files: res.totalFiles, dist: res.categoryDistribution)
    }
    
    /// 对指定磁盘路径计算统计度量 (底层使用 Composite Pattern 统一接口)
    public static func calculateStats(for targetPath: String) async -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) {
        return await Task.detached(priority: .userInitiated) { () -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) in
            guard FileManager.default.fileExists(atPath: targetPath) else {
                return (0, 0, 0, [])
            }
            let rootComponent = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: targetPath)
            return calculateStats(for: rootComponent)
        }.value
    }
}

