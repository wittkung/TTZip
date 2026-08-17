import Foundation

/// macOS Finder 访达右键扩展集成助手 (对齐 Bandizip 经典右键菜单)
public final class FinderSyncHelper: @unchecked Sendable {
    public static let shared = FinderSyncHelper()
    
    private init() {}
    
    public struct ContextMenuItem: Sendable {
        public let title: String
        public let actionIdentifier: String
        
        public init(title: String, actionIdentifier: String) {
            self.title = title
            self.actionIdentifier = actionIdentifier
        }
    }
    
    /// 获取快捷右键动态菜单项列表 (对齐 Bandizip 经典快捷菜单)
    public func getContextMenuItems(selectedURLs: [URL]) -> [ContextMenuItem] {
        guard !selectedURLs.isEmpty else { return [] }
        
        let firstURL = selectedURLs[0]
        let baseName = selectedURLs.count == 1 ? firstURL.deletingPathExtension().lastPathComponent : "选中归档集"
        let ext = firstURL.pathExtension.lowercased()
        let isArchive = ["zip", "7z", "rar", "tar", "gz", "zst", "bz2", "xz", "iso"].contains(ext)
        
        if isArchive {
            return [
                ContextMenuItem(title: "⚡️ 解压到当前文件夹 (\(baseName))", actionIdentifier: "extract_here"),
                ContextMenuItem(title: "📂 自动创建同名独立文件夹解压", actionIdentifier: "extract_to_subfolder"),
                ContextMenuItem(title: "🔍 双击预览包内媒体与代码...", actionIdentifier: "inspect_archive"),
                ContextMenuItem(title: "🔑 提取前预检/自动匹配密码库", actionIdentifier: "autofill_password"),
                ContextMenuItem(title: "🛡️ 计算文件 CRC32 / SHA-256 散列", actionIdentifier: "compute_hash")
            ]
        } else {
            return [
                ContextMenuItem(title: "🌟 添加到 \"\(baseName).7z\" (推荐新标准)", actionIdentifier: "compress_quick_7z"),
                ContextMenuItem(title: "📦 添加到 \"\(baseName).zip\" (兼容传统格式)", actionIdentifier: "compress_quick_zip"),
                ContextMenuItem(title: "📑 压缩到单独的归档文件 (批量独立打包)", actionIdentifier: "compress_separate"),
                ContextMenuItem(title: "🧹 压缩并自动删除源文件", actionIdentifier: "compress_and_delete_source"),
                ContextMenuItem(title: "⚙️ 高级加密/分卷/预设压缩...", actionIdentifier: "compress_modal_advanced")
            ]
        }
    }
}
