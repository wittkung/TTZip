// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Liquid Glass styled spotlight search bar component (retained for backward compatibility).
public struct LiquidGlassSearchBar: View {
    @Binding public var searchQuery: String
    @ObservedObject public var searchService: SpotlightSearchService
    public var viewModel: AppViewState?
    
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false
    
    public init(searchQuery: Binding<String>, searchService: SpotlightSearchService, viewModel: AppViewState? = nil) {
        self._searchQuery = searchQuery
        self.searchService = searchService
        self.viewModel = viewModel
    }
    
    public var body: some View {
        if let vm = viewModel {
            LiquidGlassOmnibar(
                searchQuery: $searchQuery,
                searchService: searchService,
                viewModel: vm
            )
        } else {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isFocused ? TTZipTheme.bambooGreen : .secondary)
                
                TextField("Search local files and archives...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .focused($isFocused)
                    .onChange(of: searchQuery) { _, newValue in
                        searchService.performSearch(query: newValue)
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isFocused ? Color.primary.opacity(0.05) : (isHovered ? Color.primary.opacity(0.03) : Color.primary.opacity(0.02)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isFocused ? TTZipTheme.bambooGreen.opacity(0.6) : (isHovered ? TTZipTheme.hairlineBorder.opacity(0.8) : TTZipTheme.hairlineBorder), lineWidth: 0.5)
            )
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}
