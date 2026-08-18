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
    
    @StateObject private var treeStore = ArchiveTreeStore()
    @State private var selectedEntryID: String?
    @State private var previewFileURL: URL?
    @State private var showPreviewPanel = true
    @State private var isExtractingTemp = false
    @State private var searchText = ""
    @State private var previewTask: Task<Void, Never>? = nil
    @State private var currentTempDir: URL? = nil
    @State private var eventMonitor: Any? = nil
    
    // In-Place Live Edit & Mutation States
    @State private var activeEditSessions: [String: InPlaceEditSession] = [:]
    @State private var syncStatusMessage: String? = nil
    @State private var isMutatingArchive: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
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
            // Header Bar
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
                    Button(action: { openSelectedInExternalEditor(selected) }) {
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
                    Label("Extract to...", systemImage: "square.and.arrow.up")
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
                                Text("Loading archive structure...")
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
                        Table(treeStore.filteredEntries, selection: $selectedEntryID) {
                            TableColumn("File Name (Path)") { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: fileIconName(isDirectory: entry.isDirectory, name: entry.name))
                                        .foregroundStyle(entry.isDirectory ? TTZipTheme.bambooGreen : Color.primary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.name)
                                            .font(TTZipTheme.Typography.body)
                                        Text(entry.path)
                                            .font(TTZipTheme.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .width(min: 240, ideal: 360)
                            
                            TableColumn("Size") { entry in
                                Text(entry.isDirectory ? "--" : formatBytes(entry.uncompressedSize))
                                    .foregroundStyle(.secondary)
                            }
                            .width(100)
                            
                            TableColumn("Encoding") { entry in
                                Text(entry.detectedEncoding)
                                    .font(TTZipTheme.Typography.codeCaption)
                                    .padding(.horizontal, TTZipTheme.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.sm, style: .continuous))
                            }
                            .width(min: 80, ideal: 100, max: 140)
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: selectedEntryID) { _, newID in
                            extractSelectedForPreview(entryID: newID)
                        }
                    }
                }
                .background(Color.clear)
                
                if showPreviewPanel {
                    VStack {
                        if isExtractingTemp {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Extracting preview data...")
                                    .font(TTZipTheme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MediaPreviewView(
                                fileURL: previewFileURL,
                                fileName: selectedEntry?.name ?? "No file selected"
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
                    Text("Ready · Drag files here to add to archive")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Double-click / ⌥O to live edit · Delete key to remove")
                    .font(TTZipTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.vertical, TTZipTheme.Spacing.xs)
            .background(Color.clear)
        }
        .searchable(text: $searchText, prompt: "Search files and folders...")
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDropFiles(providers: providers)
            return true
        }
        .confirmationDialog("Delete Item", isPresented: $showDeleteConfirmation, actions: {
            Button("Delete from Archive", role: .destructive) {
                if let selected = selectedEntry {
                    deleteSelectedEntry(selected)
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to delete '\(selectedEntry?.name ?? "")' from the archive?")
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
    
    // MARK: - In-Place Live Editing & Mutation Operations
    
    private func openSelectedInExternalEditor(_ entry: ArchiveEntry) {
        Task {
            do {
                let session = try await InPlaceArchiveMutationEngine.shared.beginEditingSession(
                    archivePath: archivePath,
                    entryPath: entry.path,
                    password: password
                )
                
                await MainActor.run {
                    self.activeEditSessions[session.sessionId] = session
                    self.syncStatusMessage = "Watching '\(entry.name)' for external changes..."
                }
                
                // Open in default macOS application
                NSWorkspace.shared.open(URL(fileURLWithPath: session.stagedFilePath))
                
                // Start auto sync
                InPlaceArchiveMutationEngine.shared.startWatchingAndAutoSync(
                    session: session,
                    password: password
                ) { updatedSession, result in
                    Task { @MainActor in
                        switch result {
                        case .success:
                            self.syncStatusMessage = "⚡️ Saved & updated '\(entry.name)' in archive"
                            self.reloadArchiveEntries()
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if self.syncStatusMessage?.contains(entry.name) == true {
                                self.syncStatusMessage = nil
                            }
                        case .failure(let err):
                            self.syncStatusMessage = "❌ Sync failed: \(err.localizedDescription)"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncStatusMessage = "Error opening: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private final class PathAccumulator: @unchecked Sendable {

        private var paths: [String] = []
        private let lock = NSLock()
        
        func append(_ path: String) {
            lock.lock()
            paths.append(path)
            lock.unlock()
        }
        
        var allPaths: [String] {
            lock.lock()
            defer { lock.unlock() }
            return paths
        }
    }
    
    private func handleDropFiles(providers: [NSItemProvider]) {
        let accumulator = PathAccumulator()
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.isFileURL {
                    accumulator.append(url.path)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let paths = accumulator.allPaths
            guard !paths.isEmpty else { return }
            self.isMutatingArchive = true
            self.syncStatusMessage = "Adding \(paths.count) items into archive..."

            
            Task {
                do {
                    try await InPlaceArchiveMutationEngine.shared.addFilesToArchive(
                        archivePath: self.archivePath,
                        sourceFilePaths: paths,
                        destinationVirtualFolder: nil,
                        password: self.password
                    )
                    await MainActor.run {
                        self.isMutatingArchive = false
                        self.syncStatusMessage = "Archive updated successfully"
                        self.reloadArchiveEntries()
                    }
                } catch {

                    await MainActor.run {
                        self.isMutatingArchive = false
                        self.syncStatusMessage = "Failed to add items: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func deleteSelectedEntry(_ entry: ArchiveEntry) {
        isMutatingArchive = true
        syncStatusMessage = "Deleting '\(entry.name)' from archive..."
        
        Task {
            do {
                try await InPlaceArchiveMutationEngine.shared.deleteEntriesFromArchive(
                    archivePath: archivePath,
                    entryPathsToDelete: [entry.path],
                    password: password
                )
                await MainActor.run {
                    self.isMutatingArchive = false
                    self.syncStatusMessage = "Deleted '\(entry.name)'"
                    self.selectedEntryID = nil
                    self.reloadArchiveEntries()
                }
            } catch {
                await MainActor.run {
                    self.isMutatingArchive = false
                    self.syncStatusMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func reloadArchiveEntries() {
        Task {
            let reader = ArchiveReader()
            if let newEntries = try? await reader.inspect(archivePath: archivePath, password: password) {
                await MainActor.run {
                    self.entries = newEntries
                    self.treeStore.updateEntries(newEntries, force: true)
                }
            }
        }
    }
    
    private func moveSelectionUp() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx > 0 {
                selectedEntryID = currentList[idx - 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveUp, object: nil)
        }
    }
    
    private func moveSelectionDown() {
        if !searchText.isEmpty {
            let currentList = treeStore.filteredEntries
            guard let currentID = selectedEntryID, let idx = currentList.firstIndex(where: { $0.id == currentID || $0.path == currentID }) else {
                if let first = currentList.first {
                    selectedEntryID = first.id
                }
                return
            }
            if idx < currentList.count - 1 {
                selectedEntryID = currentList[idx + 1].id
            }
        } else {
            NotificationCenter.default.post(name: .archiveExplorerMoveDown, object: nil)
        }
    }
    
    private func fileIconName(isDirectory: Bool, name: String) -> String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp": return "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "m4a", "aac", "flac": return "music.note"
        case "pdf": return "doc.richtext.fill"
        case "swift", "json", "c", "cpp", "h", "md", "py", "sh", "xml", "html", "css": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    private func extractSelectedForPreview(entryID: String?) {
        previewTask?.cancel()
        if let oldTempDir = currentTempDir {
            try? FileManager.default.removeItem(at: oldTempDir)
            currentTempDir = nil
        }
        
        guard let entryID = entryID,
              let entry = entries.first(where: { $0.id == entryID || $0.path == entryID }),
              !entry.isDirectory else {
            previewFileURL = nil
            return
        }
        
        let filename = (entry.path as NSString).lastPathComponent
        isExtractingTemp = true
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipPreview_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        currentTempDir = tempDir
        
        previewTask = Task {
            do {
                try await TTZipEngineFacade.shared.extractSingleEntry(
                    archivePath: archivePath,
                    entryPath: entry.path,
                    destinationDir: tempDir.path,
                    password: password
                )
                guard !Task.isCancelled else { return }
                let expectedFileURL = tempDir.appendingPathComponent(filename)
                await MainActor.run {
                    self.previewFileURL = expectedFileURL
                    self.isExtractingTemp = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.previewFileURL = nil
                    self.isExtractingTemp = false
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
