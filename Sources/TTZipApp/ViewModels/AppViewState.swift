// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import Combine
import TTZipCore

/// TTZip GUI main view ViewModel coordinating UI interactions with decoupled domain state trees.
@MainActor
public final class AppViewState: ObservableObject {
    // Domain Sub-States
    public let navigationState: NavigationState
    public let explorerState: ArchiveExplorerState
    public let taskState: TaskExecutionState
    public let overlayState: OverlayState
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Forwarding Accessors for Backward Compatibility
    
    public var activeTab: WorkspaceTab {
        get { navigationState.activeTab }
        set { navigationState.activeTab = newValue }
    }
    public var currentDirectory: URL {
        get { navigationState.currentDirectory }
        set { navigationState.currentDirectory = newValue }
    }
    
    public var currentArchivePath: String? {
        get { explorerState.currentArchivePath }
        set { explorerState.currentArchivePath = newValue }
    }
    public var activePassword: String? {
        get { explorerState.activePassword }
        set { explorerState.activePassword = newValue }
    }
    public var currentEntries: [ArchiveEntry] {
        get { explorerState.currentEntries }
        set { explorerState.currentEntries = newValue }
    }
    public var activePreviewFileURL: URL? {
        get { explorerState.activePreviewFileURL }
        set { explorerState.activePreviewFileURL = newValue }
    }
    public var activePreviewFileName: String? {
        get { explorerState.activePreviewFileName }
        set { explorerState.activePreviewFileName = newValue }
    }
    public var searchQuery: String {
        get { explorerState.searchQuery }
        set { explorerState.searchQuery = newValue }
    }
    
    public var isLoading: Bool {
        get { taskState.isLoading }
        set { taskState.isLoading = newValue }
    }
    public var statusMessage: String {
        get { taskState.statusMessage }
        set { taskState.statusMessage = newValue }
    }
    public var progressValue: Double {
        get { taskState.progressValue }
        set { taskState.progressValue = newValue }
    }
    public var canUndo: Bool {
        get { taskState.canUndo }
        set { taskState.canUndo = newValue }
    }
    public var canRedo: Bool {
        get { taskState.canRedo }
        set { taskState.canRedo = newValue }
    }
    public var lastCommandDescription: String? {
        get { taskState.lastCommandDescription }
        set { taskState.lastCommandDescription = newValue }
    }
    public var taskStateName: String {
        get { taskState.taskStateName }
        set { taskState.taskStateName = newValue }
    }
    public var canPauseTask: Bool {
        get { taskState.canPauseTask }
        set { taskState.canPauseTask = newValue }
    }
    public var canResumeTask: Bool {
        get { taskState.canResumeTask }
        set { taskState.canResumeTask = newValue }
    }
    public var canCancelTask: Bool {
        get { taskState.canCancelTask }
        set { taskState.canCancelTask = newValue }
    }
    
    public var showCompressModal: Bool {
        get { overlayState.showCompressModal }
        set { overlayState.showCompressModal = newValue }
    }
    public var showExtractModal: Bool {
        get { overlayState.showExtractModal }
        set { overlayState.showExtractModal = newValue }
    }
    public var showPasswordPrompt: Bool {
        get { overlayState.showPasswordPrompt }
        set { overlayState.showPasswordPrompt = newValue }
    }
    public var pendingEncryptedPath: String? {
        get { overlayState.pendingEncryptedPath }
        set { overlayState.pendingEncryptedPath = newValue }
    }
    public var selectedDiskItem: DiskItemInfo? {
        get { overlayState.selectedDiskItem }
        set { overlayState.selectedDiskItem = newValue }
    }
    public var selectedPathsToCompress: [String] {
        get { overlayState.selectedPathsToCompress }
        set { overlayState.selectedPathsToCompress = newValue }
    }
    public var showArchiveInspectorModal: Bool {
        get { overlayState.showArchiveInspectorModal }
        set { overlayState.showArchiveInspectorModal = newValue }
    }
    public var inspectingArchivePath: String? {
        get { overlayState.inspectingArchivePath }
        set { overlayState.inspectingArchivePath = newValue }
    }
    
    @Published public var recentArchives: [RecentArchiveRecord] = []
    
    public var historyManager: CommandHistoryManager
    public var passwordVaultManager: PasswordVaultManager
    
    let fileViewer: FileViewerServiceProtocol
    let passwordVault: PasswordVaultManaging
    let progressThrottler = ThrottledProgressPublisher(maxFrequencyHz: 60.0)
    let recentArchivesKey = "TTZipRecentArchivesKey"
    
    public init(
        navigationState: NavigationState = NavigationState(),
        explorerState: ArchiveExplorerState = ArchiveExplorerState(),
        taskState: TaskExecutionState = TaskExecutionState(),
        overlayState: OverlayState = OverlayState(),
        fileViewer: FileViewerServiceProtocol = MacNSWorkspaceFileViewer(),
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared,
        historyManager: CommandHistoryManager = CommandHistoryManager.shared,
        passwordVaultManager: PasswordVaultManager = PasswordVaultManager.shared
    ) {
        self.navigationState = navigationState
        self.explorerState = explorerState
        self.taskState = taskState
        self.overlayState = overlayState
        self.fileViewer = fileViewer
        self.passwordVault = passwordVault
        self.historyManager = historyManager
        self.passwordVaultManager = passwordVaultManager

        navigationState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        explorerState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        taskState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        overlayState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        
        loadRecentArchivesFromStorage()
        RootFolderAccessManager.shared.restoreBookmarks()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            RootFolderAccessManager.shared.ensureAccess(for: self.currentDirectory, promptIfMissing: true)
        }
        
        NotificationCenter.default.publisher(for: NSNotification.Name("TTZipPerformUndoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performUndo()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("TTZipPerformRedoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performRedo()
            }
            .store(in: &cancellables)
        
        updateUndoRedoState()
    }
}
