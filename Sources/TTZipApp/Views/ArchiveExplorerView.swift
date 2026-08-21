// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit
import QuickLook
import UniformTypeIdentifiers

public struct ArchiveExplorerView: View {
    public let archivePath: String
    public var password: String? = nil
    @State public var entries: [ArchiveEntry]
    public let onExtractClicked: () -> Void
    public let onCloseClicked: () -> Void
    
    @ObservedObject var l10n = AppLocalizationState.shared
    @StateObject var treeStore = ArchiveTreeStore()
    @State var selectedEntryID: String?
    @State var previewFileURL: URL?
    @State var showPreviewPanel = true
    @State var isExtractingTemp = false
    @State var searchText = ""
    @State var previewTask: Task<Void, Never>? = nil
    @State var currentTempDir: URL? = nil
    @State var eventMonitor: Any? = nil
    
    // In-Place Live Edit & Mutation States
    @State var activeEditSessions: [String: InPlaceEditSession] = [:]
    @State var syncStatusMessage: String? = nil
    @State var isMutatingArchive: Bool = false
    @State var showDeleteConfirmation: Bool = false
    
    public init(
        archivePath: String,
        password: String? = nil,
        entries: [ArchiveEntry],
        onExtractClicked: @escaping () -> Void,
        onCloseClicked: @escaping () -> Void
    ) {
        self.archivePath = archivePath
        self.password = password
        self._entries = State(initialValue: entries)
        self.onExtractClicked = onExtractClicked
        self.onCloseClicked = onCloseClicked
    }
    
    public var selectedEntry: ArchiveEntry? {
        guard let id = selectedEntryID else { return nil }
        return entries.first(where: { $0.id == id || $0.path == id })
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArchiveExplorerHeaderBar(
                archivePath: archivePath,
                syncStatusMessage: syncStatusMessage,
                selectedEntry: selectedEntry,
                showPreviewPanel: $showPreviewPanel,
                onExtractClicked: onExtractClicked,
                onCloseClicked: onCloseClicked,
                onOpenInExternalEditor: { selected in
                    openSelectedInExternalEditor(selected)
                }
            )
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            HSplitView {
                Group {
                    if searchText.isEmpty {
                        if treeStore.isBuildingTree && treeStore.rootNodes.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.1)
                                Text(l10n.t(L10n.Explorer.loadingArchiveStructure))
                                    .font(TTZipTheme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            NativeArchiveOutlineView(
                                nodes: treeStore.rootNodes,
                                selectedPath: $selectedEntryID,
                                onSelectFile: { node in
                                    extractSelectedForPreview(entryID: node.id)
                                }
                            )
                        }
                    } else {
                        ArchiveExplorerTableView(
                            filteredEntries: treeStore.filteredEntries,
                            selectedEntryID: $selectedEntryID,
                            onSelectEntry: { newID in
                                extractSelectedForPreview(entryID: newID)
                            }
                        )
                    }
                }
                .background(Color.clear)
                
                if showPreviewPanel {
                    VStack {
                        if isExtractingTemp {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text(l10n.t(L10n.Preview.loading))
                                    .font(TTZipTheme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MediaPreviewView(
                                fileURL: previewFileURL,
                                fileName: selectedEntry?.name ?? l10n.t(L10n.Explorer.emptyDirectory)
                            )
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: .infinity)
                    .background(Color.black.opacity(0.02))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            // Footer Bar
            HStack {
                if let selected = selectedEntry {
                    Text("Selected: \(selected.name) (\(formatBytes(selected.uncompressedSize))) · Path: \(selected.path)")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text(l10n.t(L10n.Explorer.dragDropPrompt))
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.vertical, TTZipTheme.Spacing.xs)
            .background(Color.clear)
        }
        .searchable(text: $searchText, prompt: l10n.t(L10n.Common.search))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDropFiles(providers: providers)
            return true
        }
        .confirmationDialog(l10n.t(L10n.Dialogs.confirmDeleteTitle), isPresented: $showDeleteConfirmation, actions: {
            Button(l10n.t(L10n.Common.delete), role: .destructive) {
                if let selected = selectedEntry {
                    deleteSelectedEntry(selected)
                }
            }
            Button(l10n.t(L10n.Common.cancel), role: .cancel) {}
        }, message: {
            Text(l10n.format(L10n.Dialogs.confirmDeleteMessage, selectedEntry?.name ?? ""))
        })
        .onAppear {
            treeStore.updateEntries(entries)
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode >= 123 && event.keyCode <= 126 {
                    if let firstResponder = NSApp.keyWindow?.firstResponder {
                        if firstResponder.isKind(of: NSTextView.self) && (firstResponder as? NSTextView)?.isFieldEditor == true {
                            return event
                        }
                    }
                    switch event.keyCode {
                    case 123:
                        NotificationCenter.default.post(name: .archiveExplorerMoveLeft, object: nil)
                    case 124:
                        NotificationCenter.default.post(name: .archiveExplorerMoveRight, object: nil)
                    case 125:
                        moveSelectionDown()
                    case 126:
                        moveSelectionUp()
                    default:
                        break
                    }
                    return nil
                }
                
                // Delete / Backspace key
                if event.keyCode == 51 || event.keyCode == 117 {
                    if let firstResponder = NSApp.keyWindow?.firstResponder {
                        if firstResponder.isKind(of: NSTextView.self) && (firstResponder as? NSTextView)?.isFieldEditor == true {
                            return event
                        }
                    }
                    if selectedEntry != nil {
                        showDeleteConfirmation = true
                        return nil
                    }
                }
                
                return event
            }
        }
        .onChange(of: entries) { _, newEntries in
            treeStore.updateEntries(newEntries)
        }
        .onChange(of: searchText) { _, newQuery in
            treeStore.filter(query: newQuery)
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            previewTask?.cancel()
            if let tempDir = currentTempDir {
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // Clean up active edit sessions
            for session in activeEditSessions.values {
                InPlaceArchiveMutationEngine.shared.closeEditingSession(session: session)
            }
            activeEditSessions.removeAll()
        }
    }
}
