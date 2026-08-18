// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

/// Liquid Glass styled unified Address and Search Omnibar.
public struct LiquidGlassOmnibar: View {
    @Binding public var searchQuery: String
    @ObservedObject public var searchService: SpotlightSearchService
    @ObservedObject public var viewModel: AppViewState
    
    @StateObject private var autocompletionEngine = AsyncPathAutocompletionEngine()
    @State private var isEditing: Bool = false
    @State private var inputText: String = ""
    @State private var selectedSuggestionIndex: Int? = nil
    @State private var isHovered: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isShaking: Bool = false
    
    public init(
        searchQuery: Binding<String>,
        searchService: SpotlightSearchService,
        viewModel: AppViewState
    ) {
        self._searchQuery = searchQuery
        self.searchService = searchService
        self.viewModel = viewModel
    }
    
    private var isPathMode: Bool {
        POSIXPathSanitizer.isPathLike(input: inputText)
    }
    
    private var activeMode: AddressBarInputMode {
        isPathMode ? .pathNavigation : .spotlightSearch
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if !isEditing {
                    // Idle Breadcrumb Mode
                    BreadcrumbPathBarView(
                        currentDirectory: viewModel.currentDirectory,
                        onSelectDirectory: { targetURL in
                            DestinationDispatcher.directDispatch(path: targetURL.path, appViewState: viewModel)
                        },
                        onClickToEdit: {
                            startEditing()
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    // Active Omnibar Text Edit Mode
                    HStack(spacing: 6) {
                        Image(systemName: isPathMode ? "folder.badge.gearshape" : "magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isPathMode ? TTZipTheme.kintsugiGold : TTZipTheme.bambooGreen)
                            .animation(.easeInOut(duration: 0.15), value: isPathMode)
                        
                        OmnibarTextField(
                            text: $inputText,
                            placeholder: "Enter directory path (~/...) or search...",
                            isFocused: isEditing,
                            onCommit: {
                                commitNavigation()
                            },
                            onCancel: {
                                cancelEditing()
                            },
                            onTab: {
                                handleTabAutocomplete()
                            },
                            onMoveDown: {
                                handleMoveSelection(direction: 1)
                            },
                            onMoveUp: {
                                handleMoveSelection(direction: -1)
                            },
                            onTextChange: { newText in
                                handleTextChange(newText)
                            }
                        )
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        if !inputText.isEmpty {
                            Button(action: {
                                inputText = ""
                                autocompletionEngine.clear()
                                searchQuery = ""
                                errorMessage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            cancelEditing()
                        }) {
                            Text("Esc")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                        .help("Cancel editing (Esc)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(width: 480, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isEditing ? Color.primary.opacity(0.06) : (isHovered ? Color.primary.opacity(0.035) : Color.primary.opacity(0.02)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(
                        errorMessage != nil ? Color.red.opacity(0.8) :
                        (isEditing ? (isPathMode ? TTZipTheme.kintsugiGold.opacity(0.8) : TTZipTheme.bambooGreen.opacity(0.8)) :
                        (isHovered ? TTZipTheme.hairlineBorder.opacity(0.9) : TTZipTheme.hairlineBorder)),
                        lineWidth: isEditing ? 1.0 : 0.5
                    )
            )
            .offset(x: isShaking ? -6 : 0)
            .animation(isShaking ? Animation.default.repeatCount(4, autoreverses: true).speed(4) : .default, value: isShaking)
            .onHover { hovering in
                isHovered = hovering
            }
            .background(
                // Invisible global keyboard shortcut triggers
                Group {
                    Button("") { startEditing() }
                        .keyboardShortcut("l", modifiers: [.command])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    
                    Button("") { startEditing() }
                        .keyboardShortcut("g", modifiers: [.shift, .command])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                }
            )
            
            // Autocomplete suggestions dropdown overlay
            if isEditing && isPathMode && !autocompletionEngine.suggestions.isEmpty {
                OmnibarSuggestionPopupView(
                    suggestions: autocompletionEngine.suggestions,
                    selectedIndex: selectedSuggestionIndex,
                    onSelectSuggestion: { suggestion in
                        applySuggestion(suggestion)
                    }
                )
                .padding(.top, 4)
                .zIndex(1000)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        withAnimation(.easeOut(duration: 0.18)) {
            errorMessage = nil
            inputText = viewModel.currentDirectory.standardizedFileURL.path
            isEditing = true
            selectedSuggestionIndex = nil
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeOut(duration: 0.18)) {
            isEditing = false
            inputText = ""
            errorMessage = nil
            autocompletionEngine.clear()
            searchQuery = ""
            selectedSuggestionIndex = nil
        }
    }
    
    private func handleTextChange(_ newText: String) {
        errorMessage = nil
        selectedSuggestionIndex = nil
        
        if POSIXPathSanitizer.isPathLike(input: newText) {
            searchQuery = ""
            autocompletionEngine.query(rawInput: newText, baseDirectory: viewModel.currentDirectory)
        } else {
            autocompletionEngine.clear()
            searchQuery = newText
            searchService.performSearch(query: newText)
        }
    }
    
    private func handleTabAutocomplete() -> Bool {
        guard !autocompletionEngine.suggestions.isEmpty else { return false }
        let targetIndex = selectedSuggestionIndex ?? 0
        guard targetIndex < autocompletionEngine.suggestions.count else { return false }
        
        let item = autocompletionEngine.suggestions[targetIndex]
        if item.isDirectory {
            inputText = item.path.hasSuffix("/") ? item.path : (item.path + "/")
            autocompletionEngine.query(rawInput: inputText, baseDirectory: viewModel.currentDirectory)
            return true
        } else {
            inputText = item.path
            return true
        }
    }
    
    private func handleMoveSelection(direction: Int) -> Bool {
        guard !autocompletionEngine.suggestions.isEmpty else { return false }
        
        if let current = selectedSuggestionIndex {
            var next = current + direction
            if next < 0 { next = autocompletionEngine.suggestions.count - 1 }
            if next >= autocompletionEngine.suggestions.count { next = 0 }
            selectedSuggestionIndex = next
        } else {
            selectedSuggestionIndex = (direction > 0) ? 0 : (autocompletionEngine.suggestions.count - 1)
        }
        return true
    }
    
    private func applySuggestion(_ suggestion: PathSuggestionItem) {
        if suggestion.isDirectory {
            _ = DestinationDispatcher.directDispatch(path: suggestion.path, appViewState: viewModel)
            cancelEditing()
        } else if suggestion.isArchive {
            _ = DestinationDispatcher.directDispatch(path: suggestion.path, appViewState: viewModel)
            cancelEditing()
        } else {
            _ = DestinationDispatcher.directDispatch(path: suggestion.path, appViewState: viewModel)
            cancelEditing()
        }
    }
    
    private func commitNavigation() {
        if let selectedIdx = selectedSuggestionIndex, selectedIdx < autocompletionEngine.suggestions.count {
            applySuggestion(autocompletionEngine.suggestions[selectedIdx])
            return
        }
        
        if isPathMode {
            let sanitized = POSIXPathSanitizer.sanitize(rawInput: inputText, relativeTo: viewModel.currentDirectory)
            let result = DestinationDispatcher.classify(path: sanitized, rawInput: inputText)
            
            if result.destinationType == .notFound {
                triggerErrorFeedback("Path not found")
            } else {
                let success = DestinationDispatcher.dispatch(result: result, appViewState: viewModel)
                if success {
                    cancelEditing()
                } else {
                    triggerErrorFeedback("Failed to navigate")
                }
            }
        } else {
            // Spotlight search mode
            searchQuery = inputText
            searchService.performSearch(query: inputText)
        }
    }
    
    private func triggerErrorFeedback(_ message: String) {
        errorMessage = message
        isShaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isShaking = false
        }
    }
}
