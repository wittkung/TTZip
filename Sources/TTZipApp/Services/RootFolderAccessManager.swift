import Foundation
import AppKit

/// 根目录安全令牌与一键授权管理器
@MainActor
public final class RootFolderAccessManager {
    public static let shared = RootFolderAccessManager()
    
    private let bookmarksKey = "TTZipSecurityScopedBookmarksKey"
    private var activeBookmarks: [URL: Data] = [:]
    private var accessingURLs: Set<URL> = []
    
    private init() {
        restoreBookmarks()
    }
    
    /// 计算目标路径对应的最顶层逻辑根目录 (如用户 Home 目录或外接磁盘根路径)
    public func highestRootURL(for url: URL) -> URL {
        let homePath = NSHomeDirectory()
        let path = url.path
        
        // 1. 如果属于用户主目录 ~/，则顶层根目录统一为 ~/
        if path.hasPrefix(homePath) {
            return URL(fileURLWithPath: homePath)
        }
        
        // 2. 如果属于 /Volumes/外接盘
        if path.hasPrefix("/Volumes/") {
            let components = url.pathComponents
            if components.count >= 3 {
                let volumePath = "/" + components[1] + "/" + components[2]
                return URL(fileURLWithPath: volumePath)
            }
        }
        
        // 3. 系统级顶层根路径 /
        return URL(fileURLWithPath: "/")
    }
    
    /// 恢复并激活 UserDefaults 中保存的所有 Security Scoped Bookmarks
    public func restoreBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let dict = try? PropertyListDecoder().decode([String: Data].self, from: data) else {
            return
        }
        
        for (_, bookmarkData) in dict {
            var isStale = false
            if let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    if let freshData = try? resolvedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        activeBookmarks[resolvedURL] = freshData
                    }
                } else {
                    activeBookmarks[resolvedURL] = bookmarkData
                }
                if resolvedURL.startAccessingSecurityScopedResource() {
                    accessingURLs.insert(resolvedURL)
                }
            }
        }
        saveBookmarks()
    }
    
    private func saveBookmarks() {
        var saveDict: [String: Data] = [:]
        for (url, data) in activeBookmarks {
            saveDict[url.path] = data
        }
        if let encoded = try? PropertyListEncoder().encode(saveDict) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    /// 检查并确保对目标路径及其顶层根目录拥有访问权限
    @discardableResult
    public func ensureAccess(for url: URL, promptIfMissing: Bool = false) -> Bool {
        let rootURL = highestRootURL(for: url)
        
        // 1. 检查是否已经具备直接读取权限
        if FileManager.default.isReadableFile(atPath: url.path) || FileManager.default.isReadableFile(atPath: rootURL.path) {
            return true
        }
        
        // 2. 检查是否有匹配的已激活 Security-Scoped Bookmark
        for activeURL in accessingURLs {
            if url.path.hasPrefix(activeURL.path) || rootURL.path == activeURL.path {
                return true
            }
        }
        
        // 3. 若需要授权，直接针对最上层的 rootURL 弹窗一次性请求访问
        if promptIfMissing {
            return requestRootAccess(for: rootURL)
        }
        
        return false
    }
    
    /// 向用户申请最上一层根目录的最高访问权限
    @discardableResult
    public func requestRootAccess(for rootURL: URL) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = rootURL
        panel.title = "TTZip 最高根目录访问授权"
        panel.prompt = "授权访问最高根目录"
        panel.message = "请授权 TTZip 访问最上层根目录 (\(rootURL.path))。授权一次后，在所有子目录与上级层级间切换将永久畅通，无需重复授权。"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            let targetRoot = highestRootURL(for: selectedURL)
            if let bookmarkData = try? targetRoot.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                activeBookmarks[targetRoot] = bookmarkData
                saveBookmarks()
                if targetRoot.startAccessingSecurityScopedResource() {
                    accessingURLs.insert(targetRoot)
                }
                return true
            }
        }
        return false
    }
}
