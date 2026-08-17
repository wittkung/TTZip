import AppKit

/// 系统通用对话框统一处理服务
@MainActor
public enum SystemDialogHelper {
    /// 拉起目录选择面板
    public static func pickDirectory(prompt: String = "选择目标文件夹", defaultPath: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        if let path = defaultPath, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        if panel.runModal() == .OK, let url = panel.url {
            return url.path
        }
        return nil
    }

    /// 拉起单文件或多文件选择面板
    public static func pickFiles(
        prompt: String = "打开文件",
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true
    ) -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.prompt = prompt
        if panel.runModal() == .OK {
            return panel.urls.map { $0.path }
        }
        return []
    }
}
