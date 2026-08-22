// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

extension InspectorColumnView {
    func itemIconName(for item: DiskItemInfo) -> String {
        if item.isArchive { return "archivebox.fill" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) { return "photo.fill" }
        if ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext) { return "film.fill" }
        if ["mp3", "wav", "flac", "m4a", "aac"].contains(ext) { return "music.note" }
        if ext == "pdf" { return "doc.richtext.fill" }
        if ["swift", "js", "ts", "py", "json", "html", "css", "cpp", "c", "h"].contains(ext) { return "code" }
        return "doc.fill"
    }
    
    func itemIconGradient(for item: DiskItemInfo) -> LinearGradient {
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
    
    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        return date.formatted(.dateTime.year().month().day().hour().minute())
    }
    
    @ViewBuilder
    var detailedMetadataPopoverContent: some View {
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
                    Text("EXIF & Hardware Properties")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(deepMetadataDict.count) Properties")
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
                    detailPopoverRow(icon: "doc", label: "File Name", value: item.name)
                    detailPopoverRow(icon: "internaldrive", label: "File Size", value: item.sizeText)
                    detailPopoverRow(icon: "folder", label: "Kind", value: item.kindText)
                    detailPopoverRow(icon: "calendar", label: "Modified", value: formatDate(effectiveModificationDate))
                    if let dims = asyncDimensions {
                        detailPopoverRow(icon: "aspectratio", label: "Dimensions", value: dims)
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
    
    func metadataIcon(for key: String) -> String {
        if key.contains("Camera") || key.contains("Device") || key.contains("相机") || key.contains("设备") { return "camera" }
        if key.contains("Exposure") || key.contains("ISO") || key.contains("曝光") { return "sparkles" }
        if key.contains("Aperture") || key.contains("Focal") || key.contains("光圈") || key.contains("焦距") { return "camera.aperture" }
        if key.contains("Resolution") || key.contains("Dimension") || key.contains("分辨率") || key.contains("尺寸") { return "ruler" }
        if key.contains("Color") || key.contains("Profile") || key.contains("色彩") { return "paintpalette" }
        if key.contains("Bitrate") || key.contains("Frame") || key.contains("码率") || key.contains("帧率") { return "waveform.path.badge.plus" }
        if key.contains("Permission") || key.contains("POSIX") || key.contains("权限") { return "lock.shield" }
        return "info.circle"
    }
    
    func detailPopoverRow(icon: String, label: String, value: String) -> some View {
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
