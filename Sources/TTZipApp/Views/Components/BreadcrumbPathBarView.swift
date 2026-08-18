// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Interactive clickable breadcrumb bar representing current filesystem path.
public struct BreadcrumbPathBarView: View {
    public let currentDirectory: URL
    public let onSelectDirectory: (URL) -> Void
    public let onClickToEdit: () -> Void
    
    @State private var hoveredSegmentID: String? = nil
    
    public init(
        currentDirectory: URL,
        onSelectDirectory: @escaping (URL) -> Void,
        onClickToEdit: @escaping () -> Void
    ) {
        self.currentDirectory = currentDirectory
        self.onSelectDirectory = onSelectDirectory
        self.onClickToEdit = onClickToEdit
    }
    
    public var segments: [BreadcrumbSegment] {
        let homePath = NSHomeDirectory()
        let fullPath = currentDirectory.standardizedFileURL.path
        
        var result: [BreadcrumbSegment] = []
        
        if fullPath.hasPrefix(homePath) {
            // Home directory based breadcrumbs
            let subPath = String(fullPath.dropFirst(homePath.count))
            let parts = subPath.split(separator: "/").map(String.init)
            
            result.append(BreadcrumbSegment(
                id: homePath,
                title: "~",
                fullURL: URL(fileURLWithPath: homePath),
                isRoot: true,
                isLast: parts.isEmpty
            ))
            
            var accumulated = homePath
            for (idx, part) in parts.enumerated() {
                accumulated += "/" + part
                let isLast = (idx == parts.count - 1)
                result.append(BreadcrumbSegment(
                    id: accumulated,
                    title: part,
                    fullURL: URL(fileURLWithPath: accumulated),
                    isRoot: false,
                    isLast: isLast
                ))
            }
        } else {
            // Root filesystem based breadcrumbs
            let parts = fullPath.split(separator: "/").map(String.init)
            result.append(BreadcrumbSegment(
                id: "/",
                title: "/",
                fullURL: URL(fileURLWithPath: "/"),
                isRoot: true,
                isLast: parts.isEmpty
            ))
            
            var accumulated = ""
            for (idx, part) in parts.enumerated() {
                accumulated += "/" + part
                let isLast = (idx == parts.count - 1)
                result.append(BreadcrumbSegment(
                    id: accumulated,
                    title: part,
                    fullURL: URL(fileURLWithPath: accumulated),
                    isRoot: false,
                    isLast: isLast
                ))
            }
        }
        
        return result
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10.5))
                .foregroundStyle(TTZipTheme.kintsugiGold)
                .padding(.trailing, 2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        HStack(spacing: 2) {
                            Button(action: {
                                onSelectDirectory(segment.fullURL)
                            }) {
                                Text(segment.title)
                                    .font(.system(size: 11, weight: segment.isLast ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(segment.isLast ? TTZipTheme.kintsugiGold : (hoveredSegmentID == segment.id ? Color.primary : Color.secondary))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(hoveredSegmentID == segment.id ? Color.primary.opacity(0.08) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredSegmentID = hovering ? segment.id : nil
                            }
                            
                            if !segment.isLast {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            Button(action: onClickToEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .padding(3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to edit path or search (⌘L / ⇧⌘G)")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onClickToEdit()
        }
    }
}
