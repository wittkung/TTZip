// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

extension MainView {
    @ToolbarContentBuilder
    var mainToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if viewModel.currentArchivePath != nil {
                Button { pickAndOpenArchive() } label: { Label(l10n.t(L10n.Menu.openArchive), systemImage: "folder.badge.plus") }
                    .keyboardShortcut("o", modifiers: [.command])
                
                Button { withAnimation { viewModel.openCompressWorkspace() } } label: { Label(l10n.t(L10n.Menu.newArchiveMenu), systemImage: "archivebox.circle") }
                    .keyboardShortcut("n", modifiers: [.command])
                
                if viewModel.activeTab == .home {
                    Button {
                        if let targetPath = viewModel.selectedDiskItem?.path ?? viewModel.currentArchivePath {
                            Task { await viewModel.quickExtractArchive(archivePath: targetPath) }
                        } else {
                            viewModel.statusMessage = l10n.t(L10n.Explorer.extractToPrompt)
                        }
                    } label: { Label(l10n.t(L10n.Extract.action), systemImage: "arrow.down.circle.fill") }
                    .keyboardShortcut("e", modifiers: [.command])
                    
                    Button { viewModel.showExtractModal = true } label: { Label(l10n.t(L10n.Explorer.extractToPrompt), systemImage: "slider.horizontal.3") }
                    .keyboardShortcut("e", modifiers: [.option, .command])
                    
                    Button { withAnimation { viewModel.reset() } } label: { Label(l10n.t(L10n.Common.close), systemImage: "xmark.circle") }
                    .keyboardShortcut("w", modifiers: [.command])
                }
            }
        }
    }
    
    func openArchiveFromURL(_ url: URL) {
        let path = url.path
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return }
        viewModel.openArchiveAsFolder(url: url)
    }
    
    func pickAndOpenArchive() {
        if let firstPath = SystemDialogHelper.pickFiles(prompt: l10n.t(L10n.Menu.openArchive), canChooseDirectories: false, allowsMultipleSelection: false).first {
            viewModel.openArchiveAsFolder(url: URL(fileURLWithPath: firstPath))
        }
    }
}
