import SwiftUI
import AppKit
import TTZipCore

public struct MillerColumnItemRowView: View {
    public let item: DiskItemInfo
    public let columnIndex: Int
    public let isSelected: Bool
    public let isColumnActive: Bool
    public let dirURL: URL
    public let multiSelectedPaths: Set<String>
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onSelectItem: (DiskItemInfo, Int, Bool, Bool, URL?) -> Void
    public let onTriggerNewFolder: (URL) -> Void
    public let onTriggerNewFile: (URL) -> Void
    
    public init(
        item: DiskItemInfo,
        columnIndex: Int,
        isSelected: Bool,
        isColumnActive: Bool = true,
        dirURL: URL,
        multiSelectedPaths: Set<String>,
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onSelectItem: @escaping (DiskItemInfo, Int, Bool, Bool, URL?) -> Void,
        onTriggerNewFolder: @escaping (URL) -> Void,
        onTriggerNewFile: @escaping (URL) -> Void
    ) {
        self.item = item
        self.columnIndex = columnIndex
        self.isSelected = isSelected
        self.isColumnActive = isColumnActive
        self.dirURL = dirURL
        self.multiSelectedPaths = multiSelectedPaths
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onSelectItem = onSelectItem
        self.onTriggerNewFolder = onTriggerNewFolder
        self.onTriggerNewFile = onTriggerNewFile
    }
    
    private var isEncryptedLockItem: Bool {
        item.kindText == "受密码保护的归档包" || item.name.contains("压缩包已被加密")
    }
    
    private var iconName: String {
        isEncryptedLockItem ? "lock.doc.fill" : (item.isDirectory ? "folder.fill" : (item.isArchive ? "archivebox.fill" : "doc.fill"))
    }
    
    private var iconColor: Color {
        isEncryptedLockItem ? Color.orange : (item.isDirectory ? TTZipTheme.bambooGreen : (item.isArchive ? Color.orange : Color.secondary))
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .frame(width: 14)
            
            Text(item.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : (isEncryptedLockItem ? Color.orange : (item.isArchive ? TTZipTheme.bambooGreen : Color.primary.opacity(0.85))))
                .lineLimit(1)
            
            Spacer()
            
            if item.isDirectory || item.isArchive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(item.isArchive ? TTZipTheme.bambooGreen : Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? (isColumnActive ? TTZipTheme.bambooGreen.opacity(0.18) : Color.primary.opacity(0.08)) : Color.primary.opacity(0.015))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(isSelected ? (isColumnActive ? TTZipTheme.bambooGreen.opacity(0.4) : Color.primary.opacity(0.15)) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
            let flags = NSEvent.modifierFlags
            let isCommand = flags.contains(.command)
            let isShift = flags.contains(.shift)
            
            onSelectItem(item, columnIndex, isCommand, isShift, dirURL)
        }
        .onDrag {
            let targets = multiSelectedPaths.contains(item.path) && multiSelectedPaths.count > 1 ? Array(multiSelectedPaths) : [item.path]
            let providers = targets.map { NSItemProvider(object: URL(fileURLWithPath: $0) as NSURL) }
            return providers.first ?? NSItemProvider(object: URL(fileURLWithPath: item.path) as NSURL)
        }
        .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
            let targetDir = item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let srcURL = url, srcURL.isFileURL {
                        DispatchQueue.main.async {
                            FileDragDropHelper.performMove(sources: [srcURL], to: targetDir)
                        }
                    }
                }
            }
            return true
        }
        .contextMenu {
            MillerColumnItemContextMenu(
                item: item,
                columnIndex: columnIndex,
                dirURL: dirURL,
                multiSelectedPaths: multiSelectedPaths,
                onSelectArchive: onSelectArchive,
                onCompressPath: onCompressPath,
                onSelectItem: onSelectItem,
                onTriggerNewFolder: onTriggerNewFolder,
                onTriggerNewFile: onTriggerNewFile
            )
        }
    }
}

public struct MillerColumnItemContextMenu: View {
    public let item: DiskItemInfo
    public let columnIndex: Int
    public let dirURL: URL
    public let multiSelectedPaths: Set<String>
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onSelectItem: (DiskItemInfo, Int, Bool, Bool, URL?) -> Void
    public let onTriggerNewFolder: (URL) -> Void
    public let onTriggerNewFile: (URL) -> Void
    
    public var body: some View {
        Button {
            onSelectItem(item, columnIndex, false, false, dirURL)
        } label: {
            Text("选中: \(item.name)")
        }
        .disabled(true)
        
        Divider()
        
        if multiSelectedPaths.count > 1 && multiSelectedPaths.contains(item.path) {
            Button {
                let targets = Array(multiSelectedPaths).map { URL(fileURLWithPath: $0) }
                FileClipboardStore.shared.copy(urls: targets)
            } label: {
                Label("复制已选 \(multiSelectedPaths.count) 项", systemImage: "doc.on.doc")
            }
            
            Button {
                let targets = Array(multiSelectedPaths).map { URL(fileURLWithPath: $0) }
                FileClipboardStore.shared.cut(urls: targets)
            } label: {
                Label("剪切已选 \(multiSelectedPaths.count) 项", systemImage: "scissors")
            }
            
            Divider()
            
            Button {
                onCompressPath(Array(multiSelectedPaths).joined(separator: "\n"))
            } label: {
                Label("TTZip: 快捷新建压缩包 (已选 \(multiSelectedPaths.count) 项)...", systemImage: "archivebox.fill")
            }
            
            Button {
                for path in multiSelectedPaths {
                    let u = URL(fileURLWithPath: path)
                    try? FileManager.default.trashItem(at: u, resultingItemURL: nil)
                }
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            } label: {
                Label("移到废纸篓 (已选 \(multiSelectedPaths.count) 项)", systemImage: "trash")
            }
        } else if item.path.contains("?subpath=") {
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let (archivePath, subpath) = parseVirtualURL(item.path)
                let destDir = (archivePath as NSString).deletingLastPathComponent
                Task {
                    let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath)
                    try? await TTZipEngineFacade.shared.extractSingleEntry(archivePath: archivePath, entryPath: subpath, destinationDir: destDir, password: pwd)
                    NSWorkspace.shared.selectFile((destDir as NSString).appendingPathComponent(item.name), inFileViewerRootedAtPath: "")
                }
            } label: {
                Label("TTZip: 提取此项到当前目录", systemImage: "arrow.down.doc.fill")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                if panel.runModal() == .OK, let destURL = panel.url {
                    let (archivePath, subpath) = parseVirtualURL(item.path)
                    Task {
                        let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath)
                        try? await TTZipEngineFacade.shared.extractSingleEntry(archivePath: archivePath, entryPath: subpath, destinationDir: destURL.path, password: pwd)
                        NSWorkspace.shared.selectFile((destURL.path as NSString).appendingPathComponent(item.name), inFileViewerRootedAtPath: "")
                    }
                }
            } label: {
                Label("TTZip: 提取此项到指定位置...", systemImage: "folder.badge.plus")
            }
            
            Divider()
            
            Button {
                let (_, subpath) = parseVirtualURL(item.path)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(subpath, forType: .string)
            } label: {
                Label("拷贝包内相对路径", systemImage: "doc.on.doc")
            }
        } else {
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                FileClipboardStore.shared.copy(urls: [URL(fileURLWithPath: item.path)])
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                FileClipboardStore.shared.cut(urls: [URL(fileURLWithPath: item.path)])
            } label: {
                Label("剪切", systemImage: "scissors")
            }
            
            if item.isDirectory {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    FileClipboardStore.shared.paste(to: URL(fileURLWithPath: item.path))
                } label: {
                    Label("粘贴到此文件夹", systemImage: "doc.on.clipboard")
                }
                .disabled(!FileClipboardStore.shared.canPaste)
            }
            
            Divider()
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.open(u)
            } label: {
                Label("打开", systemImage: "arrow.up.forward.app")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.activateFileViewerSelecting([u])
            } label: {
                Label("快速查看 (Quick Look)", systemImage: "eye")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let script = "tell application \"Finder\" to open information window of (POSIX file \"\(item.path)\" as alias)"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            } label: {
                Label("显示简介", systemImage: "info.circle")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                onTriggerNewFolder(item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL)
            } label: {
                Label("新建文件夹...", systemImage: "folder.badge.plus")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                onTriggerNewFile(item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL)
            } label: {
                Label("新建空白文件...", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            if item.isArchive {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    onSelectArchive(item.path)
                } label: {
                    Label("TTZip: 展开为目录下钻", systemImage: "sidebar.right")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipQuickExtractArchive"), object: item.path)
                } label: {
                    Label("TTZip: 一键解压到同名文件夹", systemImage: "arrow.down.circle.fill")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipOpenArchiveInspector"), object: item.path)
                } label: {
                    Label("TTZip: 归档标准与合规诊断...", systemImage: "doc.badge.gearshape")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipEncryptedArchivePromptRequired"), object: item.path)
                } label: {
                    Label("TTZip: 输入/验证解压口令", systemImage: "key.fill")
                }
            } else {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    onCompressPath(item.path)
                } label: {
                    Label("TTZip: 快捷新建压缩包...", systemImage: "archivebox.fill")
                }
            }
            
            Divider()
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            } label: {
                Label("拷贝绝对路径", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                try? FileManager.default.trashItem(at: u, resultingItemURL: nil)
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            } label: {
                Label("移到废纸篓", systemImage: "trash")
            }
        }
    }
    
    private func parseVirtualURL(_ path: String) -> (archivePath: String, subpath: String) {
        if let u = URL(string: path),
           let comp = URLComponents(url: u, resolvingAgainstBaseURL: false),
           let sub = comp.queryItems?.first(where: { $0.name == "subpath" })?.value {
            var arch = u.path
            if arch.isEmpty { arch = path }
            return (arch, sub)
        }
        return (path, "")
    }
}
