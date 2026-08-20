// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Home explorer container holding toolbar header and directory browser.
public struct HomeExplorerContainerView: View {
    @ObservedObject public var viewModel: AppViewState
    @ObservedObject private var quickLookCoordinator = QuickLookPreviewCoordinator.shared
    public let isRightSidebarVisible: Bool
    
    public init(viewModel: AppViewState, isRightSidebarVisible: Bool) {
        self.viewModel = viewModel
        self.isRightSidebarVisible = isRightSidebarVisible
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("EXPLORER")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("File Explorer")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    RootFolderAccessManager.shared.requestRootAccess(for: RootFolderAccessManager.shared.highestRootURL(for: viewModel.currentDirectory))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Root Access")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(TTZipTheme.kintsugiGold.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Grant root access to parent directory to browse without sandbox prompts")
                
                Button(action: {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    // Trigger global location focus (Cmd+L)
                    if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0, context: nil, characters: "l", charactersIgnoringModifiers: "l", isARepeat: false, keyCode: 37) {
                        NSApp.sendEvent(event)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text(viewModel.currentDirectory.lastPathComponent.isEmpty ? "/" : viewModel.currentDirectory.lastPathComponent)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Current directory (Click or press ⌘L / ⇧⌘G to navigate by path)")
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            DiskDirectoryBrowserView(
                rootDirectory: viewModel.currentDirectory,
                onSelectArchive: { archivePath in
                    let u = URL(fileURLWithPath: archivePath)
                    viewModel.openArchiveAsFolder(url: u)
                },
                onCompressPath: { folderPath in
                    viewModel.openCompressWorkspace(paths: [folderPath])
                },
                onPreviewFile: { path in
                    quickLookCoordinator.previewDiskFile(url: URL(fileURLWithPath: path))
                },
                onSelectItem: { item in
                    viewModel.selectedDiskItem = item
                }
            )
        }
        .quickLookPreview($quickLookCoordinator.activePreviewURL)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .padding(.top, 38)
        .padding(.leading, 0)
        .padding(.trailing, (isRightSidebarVisible && viewModel.selectedDiskItem != nil) ? 4 : TTZipTheme.Spacing.md)
        .padding(.bottom, TTZipTheme.Spacing.md)
    }
}
