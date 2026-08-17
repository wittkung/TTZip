import SwiftUI
import TTZipCore
import AppKit
import QuickLook

struct ArchiveExplorerView: View {
    let archivePath: String
    var password: String? = nil
    let entries: [ArchiveEntry]
    let onExtractClicked: () -> Void
    let onCloseClicked: () -> Void
    
    @StateObject private var treeStore = ArchiveTreeStore()
    @State private var selectedEntryID: String?
    @State private var previewFileURL: URL?
    @State private var showPreviewPanel = true
    @State private var isExtractingTemp = false
    @State private var searchText = ""
    @State private var previewTask: Task<Void, Never>? = nil
    @State private var currentTempDir: URL? = nil
    @State private var eventMonitor: Any? = nil
    
    var selectedEntry: ArchiveEntry? {
        guard let id = selectedEntryID else { return nil }
        return entries.first(where: { $0.id == id || $0.path == id })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Explorer Bar
            HStack(spacing: TTZipTheme.Spacing.xs) {
                Image(systemName: "archivebox")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Text((archivePath as NSString).lastPathComponent)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle(isOn: $showPreviewPanel.animation(.easeOut(duration: 0.2))) {
                    Label("预览面板", systemImage: "sidebar.right")
                        .font(TTZipTheme.Typography.callout)
                }
                .toggleStyle(.button)
                .controlSize(.regular)
                
                Button(action: onExtractClicked) {
                    Label("解压至...", systemImage: "square.and.arrow.up")
                        .font(TTZipTheme.Typography.callout)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, TTZipTheme.Spacing.sm)
                        .padding(.vertical, TTZipTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
                .background(TTZipTheme.primaryGradient)
                .clipShape(Capsule())
                .keyboardShortcut("e", modifiers: [.command])
                
                Button(action: onCloseClicked) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .padding(.top, 38)
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.bottom, TTZipTheme.Spacing.md)
            
            // 极细分割线
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            // 主区域: macOS 原生 NSOutlineView 目录树 + 媒体实时预览左右分栏 (HSplitView)
            HSplitView {
                Group {
                    if searchText.isEmpty {
                        if treeStore.isBuildingTree && treeStore.rootNodes.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.1)
                                Text("正在加载归档结构...")
                                    .font(TTZipTheme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // 使用 100% macOS 原生 NSOutlineView：从 ArchiveTreeStore 读取记忆体
                            NativeArchiveOutlineView(
                                nodes: treeStore.rootNodes,
                                selectedPath: $selectedEntryID,
                                onSelectFile: { node in
                                    extractSelectedForPreview(entryID: node.id)
                                }
                            )
                        }
                    } else {
                        // 搜索模式下平铺展示匹配结果
                        Table(treeStore.filteredEntries, selection: $selectedEntryID) {
                            TableColumn("文件名 (路径)") { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: fileIconName(isDirectory: entry.isDirectory, name: entry.name))
                                        .foregroundStyle(entry.isDirectory ? TTZipTheme.bambooGreen : Color.primary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.name)
                                            .font(TTZipTheme.Typography.body)
                                        Text(entry.path)
                                            .font(TTZipTheme.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .width(min: 240, ideal: 360)
                            
                            TableColumn("大小") { entry in
                                Text(entry.isDirectory ? "--" : formatBytes(entry.uncompressedSize))
                                    .foregroundStyle(.secondary)
                            }
                            .width(100)
                            
                            TableColumn("编码解析") { entry in
                                Text(entry.detectedEncoding)
                                    .font(TTZipTheme.Typography.codeCaption)
                                    .padding(.horizontal, TTZipTheme.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.sm, style: .continuous))
                            }
                            .width(min: 80, ideal: 100, max: 140)
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: selectedEntryID) { _, newID in
                            extractSelectedForPreview(entryID: newID)
                        }
                    }
                }
                .background(Color.clear)
                
                // 右侧媒体实时预览抽屉面板
                if showPreviewPanel {
                    VStack {
                        if isExtractingTemp {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("正在实时解压媒体预检数据...")
                                    .font(TTZipTheme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MediaPreviewView(
                                fileURL: previewFileURL,
                                fileName: selectedEntry?.name ?? "未选择文件"
                            )
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: .infinity)
                    .background(Color.black.opacity(0.02))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            // 底部状态栏
            HStack {
                if let selected = selectedEntry {
                    Text("已选中: \(selected.name) (\(formatBytes(selected.uncompressedSize))) · 路径: \(selected.path)")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text("就绪")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("点击文件夹展开 / 折叠目录树，点击文件在右侧面板实时预览")
                    .font(TTZipTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.vertical, TTZipTheme.Spacing.xs)
            .background(Color.clear)
        }
        .searchable(text: $searchText, prompt: "搜索包内文件与文件夹...")
        .onAppear {
            treeStore.updateEntries(entries)
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode >= 123 && event.keyCode <= 126 {
                    if let firstResponder = NSApp.keyWindow?.firstResponder {
                        if firstResponder.isKind(of: NSTextView.self) && (firstResponder as? NSTextView)?.isFieldEditor == true {
                            return event
                        }
                    }
                    switch event.keyCode {
                    case 123: // Left
                        NotificationCenter.default.post(name: .archiveExplorerMoveLeft, object: nil)
                    case 124: // Right
                        NotificationCenter.default.post(name: .archiveExplorerMoveRight, object: nil)
                    case 125: // Down
                        moveSelectionDown()
                    case 126: // Up
                        moveSelectionUp()
                    default:
                        break
                    }
                    return nil
                }
                return event
            }
        }
        .onChange(of: entries) { _, newEntries in
            treeStore.updateEntries(newEntries)
        }
        .onChange(of: searchText) { _, newQuery in
            treeStore.filter(query: newQuery)
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            previewTask?.cancel()
            if let tempDir = currentTempDir {
                try? FileManager.default.removeItem(at: tempDir)
            }
        }
    }
    
    private func moveSelectionUp() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx > 0 {
                selectedEntryID = currentList[idx - 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveUp, object: nil)
        }
    }
    
    private func moveSelectionDown() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx < currentList.count - 1 {
                selectedEntryID = currentList[idx + 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveDown, object: nil)
        }
    }
    
    private func fileIconName(isDirectory: Bool, name: String) -> String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp": return "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "m4a", "aac", "flac": return "music.note"
        case "pdf": return "doc.richtext.fill"
        case "swift", "json", "c", "cpp", "h", "md", "py", "sh", "xml", "html", "css": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    private func extractSelectedForPreview(entryID: String?) {
        previewTask?.cancel()
        if let oldTempDir = currentTempDir {
            try? FileManager.default.removeItem(at: oldTempDir)
            currentTempDir = nil
        }
        
        guard let entryID = entryID,
              let entry = entries.first(where: { $0.id == entryID || $0.path == entryID }),
              !entry.isDirectory else {
            previewFileURL = nil
            return
        }
        
        let filename = (entry.path as NSString).lastPathComponent
        isExtractingTemp = true
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipPreview_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        currentTempDir = tempDir
        
        previewTask = Task {
            do {
                try await TTZipEngineFacade.shared.extractSingleEntry(
                    archivePath: archivePath,
                    entryPath: entry.path,
                    destinationDir: tempDir.path,
                    password: password
                )
                guard !Task.isCancelled else { return }
                let expectedFileURL = tempDir.appendingPathComponent(filename)
                await MainActor.run {
                    self.previewFileURL = expectedFileURL
                    self.isExtractingTemp = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.previewFileURL = nil
                    self.isExtractingTemp = false
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
