import Foundation
import AppKit

/// 文件系统 GUI 桌面定位服务抽象接口
public protocol FileViewerServiceProtocol: Sendable {
    /// 在系统的 Finder / 文件管理器中定位并选中指定文件或文件夹
    func revealInFinder(at path: String)
}

/// macOS NSWorkspace 桌面定位默认实现
public final class MacNSWorkspaceFileViewer: FileViewerServiceProtocol {
    public init() {}
    
    public func revealInFinder(at path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
