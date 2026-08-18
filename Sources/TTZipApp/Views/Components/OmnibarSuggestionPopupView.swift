// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Liquid Glass styled autocompletion suggestions popup dropdown.
public struct OmnibarSuggestionPopupView: View {
    public let suggestions: [PathSuggestionItem]
    public let selectedIndex: Int?
    public let onSelectSuggestion: (PathSuggestionItem) -> Void
    
    @State private var hoveredID: String? = nil
    
    public init(
        suggestions: [PathSuggestionItem],
        selectedIndex: Int?,
        onSelectSuggestion: @escaping (PathSuggestionItem) -> Void
    ) {
        self.suggestions = suggestions
        self.selectedIndex = selectedIndex
        self.onSelectSuggestion = onSelectSuggestion
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: suggestions.count > 8) {
                VStack(spacing: 1) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                        let isSelected = (selectedIndex == index)
                        let isHovered = (hoveredID == item.id)
                        
                        Button(action: {
                            onSelectSuggestion(item)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: item.systemIconName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(item.isDirectory ? TTZipTheme.kintsugiGold : (item.isArchive ? TTZipTheme.bambooGreen : .secondary))
                                    .frame(width: 16)
                                
                                Text(item.displayName)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(item.parentPath)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                if item.isDirectory {
                                    Text("Tab ⇥")
                                        .font(.system(size: 8.5, weight: .semibold))
                                        .foregroundStyle(TTZipTheme.kintsugiGold.opacity(0.8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(TTZipTheme.kintsugiGold.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? TTZipTheme.kintsugiGold.opacity(0.18) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredID = hovering ? item.id : nil
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: min(CGFloat(suggestions.count * 32 + 8), 260))
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(TTZipTheme.kintsugiGold.opacity(0.4), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}
