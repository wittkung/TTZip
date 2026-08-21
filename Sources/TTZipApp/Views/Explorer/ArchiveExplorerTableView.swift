// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct ArchiveExplorerTableView: View {
    public let filteredEntries: [ArchiveEntry]
    @Binding public var selectedEntryID: String?
    public let onSelectEntry: (String?) -> Void
    
    @ObservedObject private var l10n = AppLocalizationState.shared
    
    public init(
        filteredEntries: [ArchiveEntry],
        selectedEntryID: Binding<String?>,
        onSelectEntry: @escaping (String?) -> Void
    ) {
        self.filteredEntries = filteredEntries
        self._selectedEntryID = selectedEntryID
        self.onSelectEntry = onSelectEntry
    }
    
    public var body: some View {
        Table(filteredEntries, selection: $selectedEntryID) {
            TableColumn(l10n.t(L10n.Explorer.nameHeader)) { entry in
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
            
            TableColumn(l10n.t(L10n.Explorer.sizeHeader)) { entry in
                Text(entry.isDirectory ? "--" : formatBytes(entry.uncompressedSize))
                    .foregroundStyle(.secondary)
            }
            .width(100)
            
            TableColumn(l10n.t(L10n.Explorer.kindHeader)) { entry in
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
            onSelectEntry(newID)
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
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
