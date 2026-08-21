// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct ArchiveExplorerHeaderBar: View {
    public let archivePath: String
    public let syncStatusMessage: String?
    public let selectedEntry: ArchiveEntry?
    @Binding public var showPreviewPanel: Bool
    public let onExtractClicked: () -> Void
    public let onCloseClicked: () -> Void
    public let onOpenInExternalEditor: (ArchiveEntry) -> Void
    
    @ObservedObject private var l10n = AppLocalizationState.shared
    
    public init(
        archivePath: String,
        syncStatusMessage: String?,
        selectedEntry: ArchiveEntry?,
        showPreviewPanel: Binding<Bool>,
        onExtractClicked: @escaping () -> Void,
        onCloseClicked: @escaping () -> Void,
        onOpenInExternalEditor: @escaping (ArchiveEntry) -> Void
    ) {
        self.archivePath = archivePath
        self.syncStatusMessage = syncStatusMessage
        self.selectedEntry = selectedEntry
        self._showPreviewPanel = showPreviewPanel
        self.onExtractClicked = onExtractClicked
        self.onCloseClicked = onCloseClicked
        self.onOpenInExternalEditor = onOpenInExternalEditor
    }
    
    public var body: some View {
        HStack(spacing: TTZipTheme.Spacing.xs) {
            Image(systemName: "archivebox")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(TTZipTheme.bambooGreen)
            Text((archivePath as NSString).lastPathComponent)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            if let status = syncStatusMessage {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(status)
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
                .transition(.opacity)
            }
            
            Spacer()
            
            if let selected = selectedEntry, !selected.isDirectory {
                Button(action: { onOpenInExternalEditor(selected) }) {
                    Label("Open in Editor", systemImage: "arrow.up.forward.app")
                        .font(TTZipTheme.Typography.callout)
                        .padding(.horizontal, TTZipTheme.Spacing.sm)
                        .padding(.vertical, TTZipTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
                .help("Open in default macOS application and watch for live changes")
            }
            
            Toggle(isOn: $showPreviewPanel.animation(.easeOut(duration: 0.2))) {
                Label("Preview Panel", systemImage: "sidebar.right")
                    .font(TTZipTheme.Typography.callout)
            }
            .toggleStyle(.button)
            .controlSize(.regular)
            
            Button(action: onExtractClicked) {
                Label(l10n.t(L10n.Explorer.extractToPrompt), systemImage: "square.and.arrow.up")
                    .font(TTZipTheme.Typography.callout)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, TTZipTheme.Spacing.sm)
                    .padding(.vertical, TTZipTheme.Spacing.xs)
            }
            .buttonStyle(.plain)
            .background(TTZipTheme.primaryGradient)
            .clipShape(Capsule())
            .keyboardShortcut("e", modifiers: [.command])
            
            Button(action: onCloseClicked) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.top, 38)
        .padding(.horizontal, TTZipTheme.Spacing.xl)
        .padding(.bottom, TTZipTheme.Spacing.md)
    }
}
