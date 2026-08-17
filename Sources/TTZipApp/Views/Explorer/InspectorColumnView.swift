import SwiftUI
import AppKit
import TTZipCore

public struct InspectorColumnView: View {
    public let item: DiskItemInfo
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onPreviewFile: (String) -> Void
    
    @State private var asyncDimensions: String? = nil
    @State private var localPreviewURL: URL? = nil
    @State private var deepMetadataDict: [String: String] = [:]
    @State private var showDetailedMetadataPopover: Bool = false
    
    public init(
        item: DiskItemInfo,
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onPreviewFile: @escaping (String) -> Void
    ) {
        self.item = item
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onPreviewFile = onPreviewFile
    }
    
    private var isVirtualItem: Bool {
        if let u = URL(string: item.path), let q = u.query, q.contains("subpath=") {
            return true
        }
        return false
    }
    
    private var effectivePreviewURL: URL? {
        if let local = localPreviewURL {
            return local
        }
        if isVirtualItem {
            return nil
        }
        if let url = URL(string: item.path), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: item.path)
    }
    
    private var effectiveModificationDate: Date? {
        if let d = item.modificationDate {
            return d
        }
        guard let targetPath = effectivePreviewURL?.path else { return nil }
        if FileManager.default.fileExists(atPath: targetPath),
           let attr = try? FileManager.default.attributesOfItem(atPath: targetPath) {
            return attr[FileAttributeKey.modificationDate] as? Date
        }
        return nil
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if item.isDirectory {
                FolderMediaArtboardView(
                    item: item,
                    onCompressPath: onCompressPath
                )
                .id(item.path)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    GeometryReader { barGeo in
                        let width = barGeo.size.width
                        HStack(alignment: .center, spacing: width >= 280 ? 8 : (width >= 200 ? 6 : 4)) {
                            if width >= 200 {
                                ZStack {
                                    RoundedRectangle(cornerRadius: width >= 280 ? 8 : 6, style: .continuous)
                                        .fill(itemIconGradient(for: item))
                                        .frame(width: width >= 280 ? 30 : 24, height: width >= 280 ? 30 : 24)
                                    Image(systemName: itemIconName(for: item))
                                        .font(.system(size: width >= 280 ? 14 : 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: width >= 280 ? 13 : 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Button(action: { showDetailedMetadataPopover.toggle() }) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(TTZipTheme.bambooGreen)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showDetailedMetadataPopover, arrowEdge: .bottom) {
                                        detailedMetadataPopoverContent
                                    }
                                }
                                
                                if width >= 320 {
                                    HStack(spacing: 3) {
                                        Text(item.kindText).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                                        Text("·").font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                                        Text(item.sizeText).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                                        if let dims = asyncDimensions {
                                            Text("·").font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                                            Text(dims).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(TTZipTheme.bambooGreen).lineLimit(1)
                                        }
                                    }
                                    .lineLimit(1)
                                } else if width >= 220 {
                                    Text(item.sizeText)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer(minLength: 2)
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    let targetPath = effectivePreviewURL?.path ?? item.path
                                    NSWorkspace.shared.selectFile(targetPath, inFileViewerRootedAtPath: "")
                                }) {
                                    if width >= 380 {
                                        HStack(spacing: 3) {
                                            Image(systemName: "folder").font(.system(size: 10))
                                            Text("Finder")
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Capsule())
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
                                .help("在 Finder 中显示")
                                
                                Button(action: {
                                    if item.isArchive { onSelectArchive(item.path) } else { onCompressPath(item.path) }
                                }) {
                                    if width >= 380 {
                                        HStack(spacing: 3) {
                                            Image(systemName: item.isArchive ? "arrow.down.doc" : "archivebox").font(.system(size: 10))
                                            Text(item.isArchive ? "解压" : "压缩")
                                                .font(.system(size: 11, weight: .semibold))
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(TTZipTheme.bambooGreen.opacity(0.12))
                                        .clipShape(Capsule())
                                    } else {
                                        Image(systemName: item.isArchive ? "arrow.down.doc" : "archivebox")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(TTZipTheme.bambooGreen)
                                            .padding(5.5)
                                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(item.isArchive ? "解压查看包内内容" : "新建压缩包")
                            }
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    
                    Divider()
                    
                    MediaPreviewView(
                        fileURL: effectivePreviewURL,
                        fileName: item.name
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(width: 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.path) {
            if let url = effectivePreviewURL, FileManager.default.fileExists(atPath: url.path) {
                let targetURL = url
                let meta = await Task.detached(priority: .utility) {
                    await DeepFileMetadataReader.readMetadata(for: targetURL)
                }.value
                await MainActor.run {
                    self.deepMetadataDict = meta
                }
            } else {
                self.deepMetadataDict = [:]
            }
        }
        .task(id: item.path) {
            self.localPreviewURL = nil
            self.asyncDimensions = nil
            
            var realArchivePath = ""
            var subpath = ""
            var isVirtual = false
            
            if let u = URL(string: item.path),
               let comp = URLComponents(url: u, resolvingAgainstBaseURL: false),
               let qItems = comp.queryItems,
               let sub = qItems.first(where: { $0.name == "subpath" })?.value {
                isVirtual = true
                realArchivePath = u.path
                subpath = sub
            }
            
            if isVirtual {
                let filename = (subpath as NSString).lastPathComponent
                let hash = abs(realArchivePath.hashValue).description + "_" + abs(filename.hashValue).description
                
                if let cached = PreviewLRUCacheManager.shared.cachedURL(forKey: hash) {
                    self.localPreviewURL = cached
                } else {
                    let targetFileURL = PreviewLRUCacheManager.shared.targetURL(forKey: hash, filename: filename)
                    let tempDir = targetFileURL.deletingLastPathComponent().path
                    let extractedPath = targetFileURL.path
                    let fm = FileManager.default
                    
                    if fm.fileExists(atPath: extractedPath),
                       let attr = try? fm.attributesOfItem(atPath: extractedPath),
                       (attr[.size] as? Int64 ?? 0) > 0 {
                        PreviewLRUCacheManager.shared.register(key: hash, fileURL: targetFileURL)
                        self.localPreviewURL = targetFileURL
                    } else if let contents = try? fm.contentsOfDirectory(atPath: tempDir),
                              let first = contents.first(where: { !$0.hasPrefix(".") }) {
                        let matchURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent(first))
                        PreviewLRUCacheManager.shared.register(key: hash, fileURL: matchURL)
                        self.localPreviewURL = matchURL
                    } else {
                        let pwd = ArchivePasswordStore.shared.getPassword(for: realArchivePath)
                        
                        let extractTask = Task.detached(priority: .userInitiated) {
                            try await TTZipEngineFacade.shared.extractSingleEntry(
                                archivePath: realArchivePath,
                                entryPath: subpath,
                                destinationDir: tempDir,
                                password: pwd
                            )
                        }
                        
                        let extLower = (filename as NSString).pathExtension.lowercased()
                        let isVideo = ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(extLower)
                        
                        if isVideo {
                            var loaded = false
                            var checks = 0
                            while !extractTask.isCancelled && !loaded && checks < 300 {
                                checks += 1
                                if fm.fileExists(atPath: extractedPath),
                                   let attr = try? fm.attributesOfItem(atPath: extractedPath),
                                   let bytes = attr[.size] as? Int64, bytes >= 2 * 1024 * 1024 {
                                    await MainActor.run {
                                        PreviewLRUCacheManager.shared.register(key: hash, fileURL: targetFileURL)
                                        self.localPreviewURL = targetFileURL
                                    }
                                    loaded = true
                                    break
                                }
                                try? await Task.sleep(nanoseconds: 10_000_000)
                            }
                            _ = try? await extractTask.value
                        } else {
                            _ = try? await extractTask.value
                            if fm.fileExists(atPath: extractedPath) {
                                await MainActor.run {
                                    PreviewLRUCacheManager.shared.register(key: hash, fileURL: targetFileURL)
                                    self.localPreviewURL = targetFileURL
                                }
                            } else if let contents = try? fm.contentsOfDirectory(atPath: tempDir),
                                      let firstFile = contents.first(where: { !$0.hasPrefix(".") }) {
                                let matchURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent(firstFile))
                                await MainActor.run {
                                    PreviewLRUCacheManager.shared.register(key: hash, fileURL: matchURL)
                                    self.localPreviewURL = matchURL
                                }
                            }
                        }
                    }
                }
            } else {
                self.localPreviewURL = URL(fileURLWithPath: item.path)
            }
            
            let targetURL = localPreviewURL ?? URL(fileURLWithPath: item.path)
            let ext = targetURL.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"].contains(ext) {
                if let dims = ImageMetadataCache.shared.getDimensions(for: targetURL.path) {
                    self.asyncDimensions = dims
                } else {
                    self.asyncDimensions = await ImageMetadataCache.shared.loadDimensionsAsync(path: targetURL.path, url: targetURL)
                }
            } else {
                self.asyncDimensions = nil
            }
        }
    }
    
    private func itemIconName(for item: DiskItemInfo) -> String {
        if item.isArchive { return "archivebox.fill" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) { return "photo.fill" }
        if ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext) { return "film.fill" }
        if ["mp3", "wav", "flac", "m4a", "aac"].contains(ext) { return "music.note" }
        if ext == "pdf" { return "doc.richtext.fill" }
        if ["swift", "js", "ts", "py", "json", "html", "css", "cpp", "c", "h"].contains(ext) { return "code" }
        return "doc.fill"
    }
    
    private func itemIconGradient(for item: DiskItemInfo) -> LinearGradient {
        if item.isArchive {
            return LinearGradient(colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) {
            return LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext) {
            return LinearGradient(colors: [Color.pink, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if ["mp3", "wav", "flac", "m4a", "aac"].contains(ext) {
            return LinearGradient(colors: [Color.teal, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if ext == "pdf" {
            return LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知" }
        return date.formatted(.dateTime.year().month().day().hour().minute())
    }
    
    private var detailedMetadataPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(itemIconGradient(for: item))
                        .frame(width: 24, height: 24)
                    Image(systemName: itemIconName(for: item))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("全量 EXIF & 硬件属性检查器")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(deepMetadataDict.count) 项参数")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    detailPopoverRow(icon: "doc", label: "文件名", value: item.name)
                    detailPopoverRow(icon: "internaldrive", label: "文件体积", value: item.sizeText)
                    detailPopoverRow(icon: "folder", label: "文件类型", value: item.kindText)
                    detailPopoverRow(icon: "calendar", label: "修改时间", value: formatDate(effectiveModificationDate))
                    if let dims = asyncDimensions {
                        detailPopoverRow(icon: "aspectratio", label: "媒体尺寸", value: dims)
                    }
                    
                    if !deepMetadataDict.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        
                        ForEach(Array(deepMetadataDict.keys.sorted()), id: \.self) { key in
                            detailPopoverRow(icon: metadataIcon(for: key), label: key, value: deepMetadataDict[key] ?? "")
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(14)
        .frame(width: 330)
    }
    
    private func metadataIcon(for key: String) -> String {
        if key.contains("相机") || key.contains("设备") { return "camera" }
        if key.contains("曝光") || key.contains("ISO") { return "sparkles" }
        if key.contains("光圈") || key.contains("焦距") { return "camera.aperture" }
        if key.contains("分辨率") || key.contains("尺寸") { return "ruler" }
        if key.contains("色彩") || key.contains("Profile") { return "paintpalette" }
        if key.contains("码率") || key.contains("帧率") { return "waveform.path.badge.plus" }
        if key.contains("权限") || key.contains("POSIX") { return "lock.shield" }
        return "info.circle"
    }
    
    private func detailPopoverRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 95, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}
