import Foundation
import TTZipCore

public struct CompressFileItem: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    
    /// 固化的组合组件节点 (Leaf 或 Composite Directory)，在 init 时一次性构建，消除 UI 渲染期间的重复磁盘 I/O
    public let component: ArchiveComponentProtocol
    
    public init(path: String) {
        self.path = path
        self.component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
    }
    
    public var name: String { (path as NSString).lastPathComponent }
    
    /// O(1) 内存操作：直接从已固化的 component 读取
    public var isDirectory: Bool {
        return component.isDirectory
    }
    
    /// O(1) 内存操作：组合模式透明计算文件或文件夹树总大小
    public var size: Int64 {
        return component.sizeBytes
    }
    
    // MARK: - Hashable / Equatable 手动实现（component 不参与哈希与等价判定）
    
    public static func == (lhs: CompressFileItem, rhs: CompressFileItem) -> Bool {
        return lhs.id == rhs.id && lhs.path == rhs.path
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path)
    }
}
