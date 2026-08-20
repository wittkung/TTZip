// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Home drop zone view for drag-and-drop file processing.
public struct HomeDropZoneView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    @ObservedObject public var viewModel: AppViewState
    @Binding public var isDropTargeted: Bool
    let pickAndOpenArchive: () -> Void
    
    public init(viewModel: AppViewState, isDropTargeted: Binding<Bool>, pickAndOpenArchive: @escaping () -> Void) {
        self.viewModel = viewModel
        self._isDropTargeted = isDropTargeted
        self.pickAndOpenArchive = pickAndOpenArchive
    }
    
    public var body: some View {
        dropZoneCard
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { isDropTargeted },
                set: { val in DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.25)) { isDropTargeted = val } } }
            )) { providers in
                handleDrop(providers: providers)
            }
            .padding(.top, 38)
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.bottom, TTZipTheme.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var dropZoneCard: some View {
        VStack(spacing: TTZipTheme.Spacing.md) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(isDropTargeted ? TTZipTheme.bambooGreen.opacity(0.08) : Color.primary.opacity(0.02))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .strokeBorder(
                        isDropTargeted ? TTZipTheme.bambooGreen : TTZipTheme.hairlineBorder.opacity(0.8),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 1.5 : 1.0, dash: isDropTargeted ? [] : [4, 4])
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isDropTargeted ? 1.05 : 1.0)
                
                Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "archivebox.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(isDropTargeted ? TTZipTheme.bambooGreen : Color.primary.opacity(0.65))
                    .scaleEffect(isDropTargeted ? 1.1 : 1.0)
            }
            
            VStack(spacing: 4) {
                Text(l10n.t(L10n.Explorer.dragDropPrompt))
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                
                Text(l10n.t(L10n.Sidebar.zeroCopyAcceleration))
                    .font(TTZipTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 10) {
                HStack(spacing: TTZipTheme.Spacing.md) {
                    Button(action: pickAndOpenArchive) {
                        Label(l10n.t(L10n.Menu.openArchive), systemImage: "folder.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, TTZipTheme.Spacing.md)
                            .padding(.vertical, 7)
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                    .buttonStyle(.plain)
                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
                    
                    Button(action: { withAnimation { viewModel.openCompressWorkspace() } }) {
                        Label(l10n.t(L10n.Menu.newArchiveMenu), systemImage: "archivebox")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, TTZipTheme.Spacing.md)
                            .padding(.vertical, 7)
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(TTZipTheme.hairlineBorder, lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(TTZipTheme.bambooGreen)
                        .frame(width: 6, height: 6)
                    
                    Text(viewModel.statusMessage.isEmpty ? "Ready" : viewModel.statusMessage)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.03))
                .clipShape(Capsule())
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TTZipTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDropTargeted ? TTZipTheme.bambooGreen.opacity(0.03) : Color.primary.opacity(0.015))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isDropTargeted ? TTZipTheme.bambooGreen.opacity(0.6) : TTZipTheme.hairlineBorder, lineWidth: isDropTargeted ? 1.0 : 0.5)
        )
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        final class SafePathArray: @unchecked Sendable {
            private var array: [String] = []
            private let lock = NSLock()
            func append(_ path: String) { lock.withLock { array.append(path) } }
            var values: [String] { lock.withLock { array } }
        }
        
        let pathsHolder = SafePathArray()
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    pathsHolder.append(url.path)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let droppedPaths = pathsHolder.values
            guard !droppedPaths.isEmpty else { return }
            if droppedPaths.count == 1, let path = droppedPaths.first {
                let ext = (path as NSString).pathExtension.lowercased()
                let archiveExts = ["zip", "7z", "tar", "gz", "bz2", "xz", "zst", "rar", "iso", "cab", "cpio", "ar", "001"]
                if archiveExts.contains(ext) || path.lowercased().contains(".7z.") || path.lowercased().contains(".zip.") {
                    viewModel.openArchiveAsFolder(url: URL(fileURLWithPath: path))
                    return
                }
            }
            viewModel.openCompressWorkspace(paths: droppedPaths)
        }
        return true
    }
}
