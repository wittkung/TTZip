// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

extension FolderMediaArtboardView {
    @ViewBuilder
    var overviewSection: some View {
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
    }
    
    @ViewBuilder
    var contentBreakdownSection: some View {
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
    }
    
    func detailRow(label: String, value: String, isHighlight: Bool = false) -> some View {
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
    
    func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Video", "视频": return .red
        case "Audio", "音频": return .purple
        case "Image", "图片": return .blue
        case "Document", "文档/代码/字幕": return TTZipTheme.bambooGreen
        case "Archive", "压缩包": return .orange
        default: return .secondary
        }
    }
    
    func createNewFolder() {
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
    
    func createNewFile() {
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
    
    func calculateStats() async {
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
