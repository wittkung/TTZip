import SwiftUI
import AppKit
import TTZipCore

public struct FolderMediaArtboardView: View {
    public let item: DiskItemInfo
    public let onCompressPath: (String) -> Void
    
    @State private var totalSizeBytes: Int64 = 0
    @State private var subfolderCount: Int = 0
    @State private var fileCount: Int = 0
    @State private var isCalculating: Bool = true
    @State private var fileTypeDistribution: [(category: String, count: Int)] = []
    @State private var showCreateSubfolderAlert: Bool = false
    @State private var newSubfolderName: String = "未命名文件夹"
    @State private var showCreateFileAlert: Bool = false
    @State private var newSubfileName: String = "未命名文件.txt"
    
    public init(item: DiskItemInfo, onCompressPath: @escaping (String) -> Void) {
        self.item = item
        self.onCompressPath = onCompressPath
    }
    
    private var formattedFolderSize: String {
        if isCalculating { return "解算中..." }
        return ByteCountFormatterFlyweight.shared.string(fromByteCount: totalSizeBytes)
    }
    
    private var formattedDate: String {
        guard let d = item.modificationDate else { return "未知" }
        return DateFormatterCache.shared.string(fromShortDateTime: d)
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            
                            Text(item.path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                    }
                    
                    GeometryReader { btnGeo in
                        let w = btnGeo.size.width
                        HStack(spacing: w >= 320 ? 12 : 6) {
                            Button(action: {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder").font(.system(size: 11))
                                        Text("Finder 中显示")
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Finder 中显示")
                            
                            Button(action: {
                                showCreateSubfolderAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.badge.plus").font(.system(size: 11))
                                        Text("新建子文件夹")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("在此文件夹下新建子文件夹")
                            
                            Button(action: {
                                showCreateFileAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.badge.plus").font(.system(size: 11))
                                        Text("新建文件")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("在此文件夹下新建空白文件")
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.path, forType: .string)
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc").font(.system(size: 11))
                                        Text("复制路径")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(5.5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("复制路径")
                        }
                    }
                    .frame(height: 24)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("概览与文件系统")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 10) {
                        detailRow(label: "容量大小", value: formattedFolderSize, isHighlight: true)
                        detailRow(label: "包含条目", value: isCalculating ? "解算中..." : "\(fileCount) 个文件 · \(subfolderCount) 个目录")
                        detailRow(label: "修改时间", value: formattedDate)
                        detailRow(label: "文件系统格式", value: "APFS (Apple File System)")
                        detailRow(label: "POSIX 访问权限", value: "0755 (drwxr-xr-x)")
                        detailRow(label: "所有者与用户组", value: "kevintung (501) / staff (20)")
                    }
                }
                
                if !fileTypeDistribution.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("内容分布比例")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        GeometryReader { barGeo in
                            let total = fileTypeDistribution.reduce(0) { $0 + $1.count }
                            HStack(spacing: 2) {
                                ForEach(fileTypeDistribution, id: \.category) { item in
                                    let ratio = total > 0 ? CGFloat(item.count) / CGFloat(total) : 0
                                    Rectangle()
                                        .fill(categoryColor(item.category))
                                        .frame(width: max(2, barGeo.size.width * ratio))
                                }
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 8)
                        
                        VStack(spacing: 6) {
                            ForEach(fileTypeDistribution, id: \.category) { item in
                                let total = fileTypeDistribution.reduce(0) { $0 + $1.count }
                                let pct = total > 0 ? Int(round(Double(item.count) / Double(total) * 100)) : 0
                                HStack {
                                    Circle()
                                        .fill(categoryColor(item.category))
                                        .frame(width: 8, height: 8)
                                    Text(item.category)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(item.count) 项 (\(pct)%)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 12)
                
                Button(action: { onCompressPath(item.path) }) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("新建压缩包 (⌘N)")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("新建压缩包")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("压缩")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(TTZipTheme.bambooGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
        .alert("新建子文件夹", isPresented: $showCreateSubfolderAlert) {
            TextField("文件夹名称", text: $newSubfolderName)
            Button("取消", role: .cancel) {
                newSubfolderName = "未命名文件夹"
            }
            Button("创建") {
                let parentDir = URL(fileURLWithPath: item.path)
                let trimmed = newSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseName = trimmed.isEmpty ? "未命名文件夹" : trimmed
                var targetURL = parentDir.appendingPathComponent(baseName)
                var counter = 2
                while FileManager.default.fileExists(atPath: targetURL.path) {
                    targetURL = parentDir.appendingPathComponent("\(baseName) \(counter)")
                    counter += 1
                }
                try? FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
                newSubfolderName = "未命名文件夹"
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            }
        } message: {
            Text("将在以下路径创建新文件夹：\n\(item.path)")
        }
        .alert("新建空白文件", isPresented: $showCreateFileAlert) {
            TextField("文件名 (含扩展名, 如 .txt / .md)", text: $newSubfileName)
            Button("取消", role: .cancel) {
                newSubfileName = "未命名文件.txt"
            }
            Button("创建") {
                let parentDir = URL(fileURLWithPath: item.path)
                let trimmed = newSubfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseName = trimmed.isEmpty ? "未命名文件.txt" : trimmed
                let pathExtension = (baseName as NSString).pathExtension
                let nameWithoutExt = (baseName as NSString).deletingPathExtension
                var targetURL = parentDir.appendingPathComponent(baseName)
                var counter = 2
                while FileManager.default.fileExists(atPath: targetURL.path) {
                    let nextName = pathExtension.isEmpty ? "\(baseName) \(counter)" : "\(nameWithoutExt) \(counter).\(pathExtension)"
                    targetURL = parentDir.appendingPathComponent(nextName)
                    counter += 1
                }
                FileManager.default.createFile(atPath: targetURL.path, contents: Data(), attributes: nil)
                newSubfileName = "未命名文件.txt"
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            }
        } message: {
            Text("将在以下路径创建新空文件：\n\(item.path)")
        }
        .task(id: item.path) {
            await calculateStats()
        }
    }
    
    private func detailRow(label: String, value: String, isHighlight: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 4)
            
            Text(value)
                .font(.system(size: isHighlight ? 13 : 11, weight: isHighlight ? .bold : .regular, design: isHighlight ? .default : .monospaced))
                .foregroundStyle(isHighlight ? TTZipTheme.bambooGreen : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
    
    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "视频": return .red
        case "音频": return .purple
        case "图片": return .blue
        case "文档/代码/字幕": return TTZipTheme.bambooGreen
        case "压缩包": return .orange
        default: return .secondary
        }
    }
    
    private func calculateStats() async {
        isCalculating = true
        let res = await FolderStatsCalculator.calculateStats(for: item.path)
        await MainActor.run {
            self.totalSizeBytes = res.size
            self.subfolderCount = res.subfolders
            self.fileCount = res.files
            self.fileTypeDistribution = res.dist
            self.isCalculating = false
        }
    }
}
