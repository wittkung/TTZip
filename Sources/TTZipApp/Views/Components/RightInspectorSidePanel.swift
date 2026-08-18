// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Right contextual Inspector side panel supporting Home and Compress modes.
public struct RightInspectorSidePanel: View {
    @ObservedObject public var viewModel: AppViewState
    @Binding public var rightVerticalTopHeight: CGFloat
    
    public init(viewModel: AppViewState, rightVerticalTopHeight: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._rightVerticalTopHeight = rightVerticalTopHeight
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("INSPECTOR")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text(viewModel.selectedDiskItem?.isDirectory == true ? "Directory Canvas" : "File Properties & Preview")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if let item = viewModel.selectedDiskItem, item.isArchive {
                    Button(action: {
                        viewModel.overlayState.inspectingArchivePath = item.path
                        viewModel.overlayState.showArchiveInspectorModal = true
                    }) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(TTZipTheme.archiveAmber)
                    }
                    .buttonStyle(.plain)
                    .help("View archive standards and compliance diagnostics...")
                }
                
                if viewModel.selectedDiskItem != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            viewModel.selectedDiskItem = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.activeTab == .compressWorkspace {
                    DiskDirectoryBrowserView(
                        rootDirectory: viewModel.currentDirectory,
                        onSelectArchive: { archivePath in
                            let u = URL(fileURLWithPath: archivePath)
                            viewModel.openArchiveAsFolder(url: u)
                        },
                        onCompressPath: { folderPath in
                            viewModel.openCompressWorkspace(paths: [folderPath])
                        },
                        onPreviewFile: { _ in },
                        onSelectItem: { item in
                            viewModel.selectedDiskItem = item
                        }
                    )
                    .frame(height: rightVerticalTopHeight)
                    .clipped()
                    
                    ResizableHorizontalDividerHandle(
                        height: $rightVerticalTopHeight,
                        minHeight: 120,
                        maxHeight: 650
                    )
                    .padding(.vertical, 2)
                    
                    if let item = viewModel.selectedDiskItem {
                        InspectorColumnView(
                            item: item,
                            onSelectArchive: { archivePath in
                                Task { await viewModel.loadArchive(path: archivePath) }
                            },
                            onCompressPath: { folderPath in
                                viewModel.openCompressWorkspace(paths: [folderPath])
                            },
                            onPreviewFile: { _ in }
                        )
                        .id(item.path)
                        .frame(maxHeight: .infinity)
                        .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("Select an item above to view properties")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.primary.opacity(0.015))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } else {
                    if let item = viewModel.selectedDiskItem {
                        InspectorColumnView(
                            item: item,
                            onSelectArchive: { archivePath in
                                Task { await viewModel.loadArchive(path: archivePath) }
                            },
                            onCompressPath: { folderPath in
                                viewModel.openCompressWorkspace(paths: [folderPath])
                            },
                            onPreviewFile: { _ in }
                        )
                        .id(item.path)
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("Select a file or folder in the explorer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Selected items can be previewed directly")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
