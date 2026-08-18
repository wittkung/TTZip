// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

@MainActor
public enum AppLogoCache {
    public static let sharedLogoImage: NSImage? = {
        if let bundleImage = NSImage(named: "AppIcon") {
            return bundleImage
        }
        if let resourcePath = Bundle.main.path(forResource: "TTZip_AppIcon_1024x1024", ofType: "png") {
            return NSImage(contentsOfFile: resourcePath)
        }
        return nil
    }()
}

public struct MainView: View {
    @StateObject private var viewModel = AppViewState()
    @State private var isSidebarVisible: Bool = true
    @State private var isRightSidebarVisible: Bool = true
    @State private var isDropTargeted: Bool = false
    
    public init() {}
    
    @AppStorage("TTZip_UserLeftSidebarWidth") private var userLeftSidebarWidth: Double = 178.0
    @AppStorage("TTZip_UserRightSidebarWidth") private var userRightSidebarWidth: Double = 340.0
    @State private var leftSidebarWidth: CGFloat = 178
    @State private var rightSidebarWidth: CGFloat = 340
    @State private var initialLeftWidth: CGFloat = 178
    @State private var initialRightWidth: CGFloat = 340
    @State private var rightVerticalTopHeight: CGFloat = 300
    
    private var isLeftCompact: Bool { leftSidebarWidth < 140 }
    
    @StateObject private var searchService = SpotlightSearchService()
    @State private var searchQuery: String = ""
    
    public var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let remainingWidth = max(totalWidth - leftSidebarWidth - 2, 200)
            
            let isRightPanelAvailable: Bool = {
                if viewModel.activeTab == .compressWorkspace { return true }
                if viewModel.activeTab == .home { return viewModel.selectedDiskItem != nil }
                return false
            }()
            
            let shouldShowRightPanel = isRightSidebarVisible && isRightPanelAvailable
            
            let effectiveRightWidth: CGFloat = {
                if !shouldShowRightPanel { return 0 }
                let minRightWidth: CGFloat = 140
                let minWorkspaceWidth: CGFloat = 200
                let maxAllowed = max(minRightWidth, remainingWidth - minWorkspaceWidth)
                return min(max(rightSidebarWidth, minRightWidth), maxAllowed)
            }()
            
            ZStack(alignment: .top) {
                TTZipFluidBackgroundView(baseColor: TTZipTheme.bambooGreen)
                    .allowsHitTesting(false)
                
                HStack(spacing: 0) {
                    MacEditorialSidebar(
                        activeTab: $viewModel.activeTab,
                        currentArchivePath: viewModel.currentArchivePath,
                        isCompact: isLeftCompact
                    )
                    .frame(width: leftSidebarWidth)
                    
                    ResizableDividerHandle(
                        onDragStart: { initialLeftWidth = leftSidebarWidth },
                        onDragChanged: { translation in
                            leftSidebarWidth = min(max(initialLeftWidth + translation, 60), 280)
                        },
                        onDragEnd: { userLeftSidebarWidth = Double(leftSidebarWidth) }
                    )
                    
                    detailArea
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    
                    if shouldShowRightPanel {
                        ResizableDividerHandle(
                            onDragStart: { initialRightWidth = rightSidebarWidth },
                            onDragChanged: { translation in
                                let newWidth = initialRightWidth - translation
                                let minRightWidth: CGFloat = 140
                                let minWorkspaceWidth: CGFloat = 200
                                let maxAllowed = max(minRightWidth, remainingWidth - minWorkspaceWidth)
                                rightSidebarWidth = min(max(newWidth, minRightWidth), maxAllowed)
                            },
                            onDragEnd: { userRightSidebarWidth = Double(rightSidebarWidth) }
                        )
                        
                        RightInspectorSidePanel(viewModel: viewModel, rightVerticalTopHeight: $rightVerticalTopHeight)
                            .frame(width: effectiveRightWidth)
                            .clipped()
                            .padding(.top, 38)
                            .padding(.leading, 4)
                            .padding(.trailing, 10)
                            .padding(.bottom, TTZipTheme.Spacing.md)
                    }
                }
                
                if isRightPanelAvailable {
                    HStack(spacing: 0) {
                        Spacer()
                        SidebarToggleButton(isSidebarVisible: $isRightSidebarVisible)
                            .padding(.top, 42)
                            .padding(.trailing, isRightSidebarVisible ? 16 : 14)
                        
                        if isRightSidebarVisible {
                            Spacer().frame(width: effectiveRightWidth)
                        }
                    }
                    .ignoresSafeArea()
                }
                
                if viewModel.activeTab == .home {
                    HStack {
                        Spacer().frame(width: 60)
                        Spacer()
                        LiquidGlassOmnibar(searchQuery: $searchQuery, searchService: searchService, viewModel: viewModel)
                        Spacer()
                        Spacer().frame(width: 60)
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 16)
                    .zIndex(998)
                    
                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        liquidGlassSearchResultsOverlay
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(999)
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { NSApp.keyWindow?.makeFirstResponder(nil) })
            .onAppear {
                self.leftSidebarWidth = CGFloat(userLeftSidebarWidth)
                self.rightSidebarWidth = CGFloat(userRightSidebarWidth)
            }
            .onChange(of: viewModel.selectedDiskItem) { _, _ in NSApp.keyWindow?.makeFirstResponder(nil) }
            .onChange(of: viewModel.activeTab) { _, _ in NSApp.keyWindow?.makeFirstResponder(nil) }
            .onChange(of: viewModel.currentDirectory) { _, _ in NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if viewModel.currentArchivePath != nil {
                    Button { pickAndOpenArchive() } label: { Label("Open Archive", systemImage: "folder.badge.plus") }
                        .keyboardShortcut("o", modifiers: [.command])
                    
                    Button { withAnimation { viewModel.openCompressWorkspace() } } label: { Label("New Archive", systemImage: "archivebox.circle") }
                        .keyboardShortcut("n", modifiers: [.command])
                    
                    if viewModel.activeTab == .home {
                        Button {
                            if let targetPath = viewModel.selectedDiskItem?.path ?? viewModel.currentArchivePath {
                                Task { await viewModel.quickExtractArchive(archivePath: targetPath) }
                            } else {
                                viewModel.statusMessage = "Select an archive item to extract"
                            }
                        } label: { Label("Quick Extract", systemImage: "arrow.down.circle.fill") }
                        .keyboardShortcut("e", modifiers: [.command])
                        
                        Button { viewModel.showExtractModal = true } label: { Label("Extract To...", systemImage: "slider.horizontal.3") }
                        .keyboardShortcut("e", modifiers: [.option, .command])
                        
                        Button { withAnimation { viewModel.reset() } } label: { Label("Close", systemImage: "xmark.circle") }
                        .keyboardShortcut("w", modifiers: [.command])
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showExtractModal) {
            let targetPath = viewModel.selectedDiskItem?.path ?? viewModel.currentArchivePath ?? ""
            ExtractModalView(archivePath: targetPath, isPresented: $viewModel.showExtractModal)
        }
        .sheet(isPresented: $viewModel.showArchiveInspectorModal) {
            let targetPath = viewModel.inspectingArchivePath ?? viewModel.selectedDiskItem?.path ?? viewModel.currentArchivePath ?? ""
            ArchiveInspectorContainerView(archivePath: targetPath)
        }
        .overlay {
            if viewModel.showPasswordPrompt, let targetPath = viewModel.pendingEncryptedPath {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { viewModel.cancelPasswordPrompt() }
                    PasswordPromptSheetView(
                        archivePath: targetPath,
                        onSubmitPassword: { pwd async in await viewModel.loadArchive(path: targetPath, password: pwd) },
                        onCancel: { viewModel.cancelPasswordPrompt() }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: viewModel.showPasswordPrompt)
            }
        }
        .onAppear {
            (NSApp.delegate as? AppDelegate)?.registerHandler { url in Task { @MainActor in openArchiveFromURL(url) } }
        }
        .onOpenURL { openArchiveFromURL($0) }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TTZipEncryptedArchivePromptRequired"))) { notif in
            if let path = notif.object as? String {
                viewModel.pendingEncryptedPath = path
                viewModel.showPasswordPrompt = true
                viewModel.statusMessage = "Archive encrypted. Password required to explore contents"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TTZipQuickExtractArchive"))) { notif in
            if let path = notif.object as? String {
                Task { await viewModel.quickExtractArchive(archivePath: path) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TTZipOpenArchiveInspector"))) { notif in
            if let path = notif.object as? String {
                viewModel.overlayState.inspectingArchivePath = path
                viewModel.overlayState.showArchiveInspectorModal = true
            }
        }
    }
    
    @ViewBuilder
    private var detailArea: some View {
        if let previewURL = viewModel.activePreviewFileURL, let name = viewModel.activePreviewFileName {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: { viewModel.closeMediaPreview() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(TTZipTheme.bambooGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 38)
                .padding(.horizontal, TTZipTheme.Spacing.lg)
                .padding(.bottom, 8)
                
                MediaPreviewView(fileURL: previewURL, fileName: name)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            KeepAliveTabContainer(activeTab: viewModel.activeTab) { tab in
                switch tab {
                case .home:
                    HomeExplorerContainerView(viewModel: viewModel, isRightSidebarVisible: isRightSidebarVisible)
                case .compressWorkspace:
                    CompressModalView(
                        isPresented: Binding(
                            get: { true },
                            set: { if !$0 { viewModel.activeTab = .home } }
                        ),
                        initialInputPaths: viewModel.selectedPathsToCompress,
                        onCompleteOpenArchive: { archivePath in
                            viewModel.activeTab = .home
                            let u = URL(fileURLWithPath: archivePath)
                            viewModel.openArchiveAsFolder(url: u)
                        }
                    )
                    .padding(.top, 38)
                    .padding(.horizontal, TTZipTheme.Spacing.md)
                    .padding(.bottom, TTZipTheme.Spacing.md)
                case .presets:
                    PresetWorkspaceView()
                case .benchmark:
                    BenchmarkView()
                case .vault:
                    PasswordVaultView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
    
    private var liquidGlassSearchResultsOverlay: some View {
        VStack(spacing: 0) {
            if searchService.isSearching {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Searching...").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else if searchService.searchResults.isEmpty {
                Text("No matching files found").font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(searchService.searchResults, id: \.path) { item in
                            Button(action: {
                                searchQuery = ""
                                if item.isDirectory {
                                    viewModel.currentDirectory = URL(fileURLWithPath: item.path)
                                } else {
                                    viewModel.selectedDiskItem = item
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(item.isDirectory ? TTZipTheme.bambooGreen : .secondary)
                                    Text(item.name).font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(item.kindText).font(.system(size: 10)).foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TTZipTheme.hairlineBorder, lineWidth: 0.5))
        .padding(.top, 42)
    }
    
    private func openArchiveFromURL(_ url: URL) {
        let path = url.path
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return }
        viewModel.openArchiveAsFolder(url: url)
    }
    
    private func pickAndOpenArchive() {
        if let firstPath = SystemDialogHelper.pickFiles(prompt: "Select Archive", canChooseDirectories: false, allowsMultipleSelection: false).first {
            viewModel.openArchiveAsFolder(url: URL(fileURLWithPath: firstPath))
        }
    }
}
