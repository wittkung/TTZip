// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
    @State private var newSubfolderName: String = "Untitled Folder"
    @State private var showCreateFileAlert: Bool = false
    @State private var newSubfileName: String = "Untitled.txt"
    
    public init(item: DiskItemInfo, onCompressPath: @escaping (String) -> Void) {
        self.item = item
        self.onCompressPath = onCompressPath
    }
    
    private var formattedFolderSize: String {
        if isCalculating { return "Calculating..." }
        return ByteCountFormatterFlyweight.shared.string(fromByteCount: totalSizeBytes)
    }
    
    private var formattedDate: String {
        guard let d = item.modificationDate else { return "Unknown" }
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
                                        Text("Reveal in Finder")
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
                            .help("Reveal in Finder")
                            
                            Button(action: {
                                showCreateSubfolderAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.badge.plus").font(.system(size: 11))
                                        Text("New Folder")
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
                            .help("Create new subfolder")
                            
                            Button(action: {
                                showCreateFileAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.badge.plus").font(.system(size: 11))
                                        Text("New File")
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
                            .help("Create new empty file")
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.path, forType: .string)
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc").font(.system(size: 11))
                                        Text("Copy Path")
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
                            .help("Copy Path")
                        }
                    }
                    .frame(height: 24)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Overview & File System")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 10) {
                        detailRow(label: "Size", value: formattedFolderSize, isHighlight: true)
                        detailRow(label: "Items", value: isCalculating ? "Calculating..." : "\(fileCount) Files · \(subfolderCount) Directories")
                        detailRow(label: "Modified", value: formattedDate)
                        detailRow(label: "File System", value: "APFS (Apple File System)")
                        detailRow(label: "POSIX Permissions", value: "0755 (drwxr-xr-x)")
                        detailRow(label: "Owner / Group", value: "kevintung (501) / staff (20)")
                    }
                }
                
                if !fileTypeDistribution.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content Breakdown")
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
                                    Text("\(item.count) items (\(pct)%)")
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
                            Text("New Archive (⌘N)")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("New Archive")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Compress")
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
        .alert("New Folder", isPresented: $showCreateSubfolderAlert) {
            TextField("Folder Name", text: $newSubfolderName)
            Button("Cancel", role: .cancel) {
                newSubfolderName = "Untitled Folder"
            }
            Button("Create") {
                let parentDir = URL(fileURLWithPath: item.path)
                let trimmed = newSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseName = trimmed.isEmpty ? "Untitled Folder" : trimmed
                var targetURL = parentDir.appendingPathComponent(baseName)
                var counter = 2
                while FileManager.default.fileExists(atPath: targetURL.path) {
                    targetURL = parentDir.appendingPathComponent("\(baseName) \(counter)")
                    counter += 1
                }
                try? FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
                newSubfolderName = "Untitled Folder"
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            }
        } message: {
            Text("Creating new folder in:\n\(item.path)")
        }
        .alert("New File", isPresented: $showCreateFileAlert) {
            TextField("File Name (e.g. text.txt)", text: $newSubfileName)
            Button("Cancel", role: .cancel) {
                newSubfileName = "Untitled.txt"
            }
            Button("Create") {
                let parentDir = URL(fileURLWithPath: item.path)
                let trimmed = newSubfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseName = trimmed.isEmpty ? "Untitled.txt" : trimmed
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
                newSubfileName = "Untitled.txt"
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            }
        } message: {
            Text("Creating new empty file in:\n\(item.path)")
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
        case "Video", "视频": return .red
        case "Audio", "音频": return .purple
        case "Image", "图片": return .blue
        case "Document", "文档/代码/字幕": return TTZipTheme.bambooGreen
        case "Archive", "压缩包": return .orange
        default: return .secondary
        }
    }
    
    private func calculateStats() async {
        isCalculating = true
        let targetPath = item.path
        let (size, subfolders, files, dist) = await Task.detached {
            var totalSize: Int64 = 0
            var folderCount = 0
            var fileCount = 0
            var typeDist: [String: Int] = [:]
            
            let fm = FileManager.default
            if let enumerator = fm.enumerator(at: URL(fileURLWithPath: targetPath), includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
                        if resourceValues.isDirectory == true {
                            folderCount += 1
                        } else {
                            fileCount += 1
                            let s = Int64(resourceValues.fileSize ?? 0)
                            totalSize += s
                            let ext = fileURL.pathExtension.lowercased()
                            typeDist[ext.isEmpty ? "other" : ext, default: 0] += 1
                        }
                    }
                }
            }
            let distArray: [(category: String, count: Int)] = typeDist.map { (category: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
            return (totalSize, folderCount, fileCount, distArray)
        }.value
        
        await MainActor.run {
            self.totalSizeBytes = size
            self.subfolderCount = subfolders
            self.fileCount = files
            self.fileTypeDistribution = dist
            self.isCalculating = false
        }
    }
}
