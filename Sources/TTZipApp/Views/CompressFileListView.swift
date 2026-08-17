import SwiftUI
import TTZipCore

public struct CompressFileListView: View {
    @Binding public var itemsList: [CompressFileItem]
    @Binding public var selectedItemIDs: Set<CompressFileItem.ID>
    
    public let totalSizeBytes: Int64
    public let onAddFiles: () -> Void
    public let onAddFolder: () -> Void
    public let onClearAll: () -> Void
    public let onRemoveSelected: () -> Void
    
    public init(
        itemsList: Binding<[CompressFileItem]>,
        selectedItemIDs: Binding<Set<CompressFileItem.ID>>,
        totalSizeBytes: Int64,
        onAddFiles: @escaping () -> Void,
        onAddFolder: @escaping () -> Void,
        onClearAll: @escaping () -> Void,
        onRemoveSelected: @escaping () -> Void
    ) {
        self._itemsList = itemsList
        self._selectedItemIDs = selectedItemIDs
        self.totalSizeBytes = totalSizeBytes
        self.onAddFiles = onAddFiles
        self.onAddFolder = onAddFolder
        self.onClearAll = onClearAll
        self.onRemoveSelected = onRemoveSelected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text("待压缩源文件清单")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                    
                    Text("(\(itemsList.count) 个项目 · 共 \(formatBytes(totalSizeBytes)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onAddFiles) {
                        Label("添加文件...", systemImage: "doc.badge.plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: onAddFolder) {
                        Label("添加文件夹...", systemImage: "folder.badge.plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !selectedItemIDs.isEmpty {
                        Button(action: onRemoveSelected) {
                            Label("移除选中 (\(selectedItemIDs.count))", systemImage: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !itemsList.isEmpty {
                        Button(action: onClearAll) {
                            Text("清空列表")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                    )
                
                if itemsList.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(TTZipTheme.bambooGreen.opacity(0.6))
                        Text("拖拽文件或文件夹至此区域以开始打包")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 32)
                } else {
                    List(itemsList, selection: $selectedItemIDs) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                .foregroundStyle(item.isDirectory ? TTZipTheme.bambooGreen : Color.blue)
                                .font(.system(size: 13))
                            
                            Text(item.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatBytes(item.size))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Button(action: {
                                if let idx = itemsList.firstIndex(where: { $0.id == item.id }) {
                                    itemsList.remove(at: idx)
                                    selectedItemIDs.remove(item.id)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("移除此项")
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                if !itemsList.contains(where: { $0.path == url.path }) {
                                    itemsList.append(CompressFileItem(path: url.path))
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
