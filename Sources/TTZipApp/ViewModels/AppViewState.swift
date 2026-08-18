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

public struct RecentArchiveRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let extensionName: String
    public let date: Date
    
    public init(path: String, date: Date = Date()) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.extensionName = (path as NSString).pathExtension.uppercased()
        self.date = date
    }
}

/// TTZip GUI main view ViewModel coordinating UI interactions with decoupled domain state trees.
@MainActor
public final class AppViewState: ObservableObject, ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, ArchiveMediatorComponentProtocol {
    public typealias Memento = AppViewStateMemento
    
    public let workspaceCaretaker = AppViewStateCaretaker()
    
    nonisolated public var mediator: ArchiveMediatorProtocol? {
        get { ArchiveAppMediator.shared }
        set {}
    }

    // Domain Sub-States
    public let navigationState: NavigationState
    public let explorerState: ArchiveExplorerState
    public let taskState: TaskExecutionState
    public let overlayState: OverlayState
    
    private var cancellables = Set<AnyCancellable>()
    
    public func saveWorkspaceSnapshot() {
        workspaceCaretaker.saveMemento(createMemento())
    }
    
    public func restoreWorkspaceSnapshot() {
        if let previous = workspaceCaretaker.undo() {
            restoreMemento(previous)
        }
    }
    
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
    public var activeTaskStateMachine: ArchiveTaskStateMachine? {
        get { taskState.activeTaskStateMachine }
        set { taskState.activeTaskStateMachine = newValue }
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
    
    @Injected public var historyManager: CommandHistoryManager
    @Injected public var passwordVaultManager: PasswordVaultManager
    @Injected public var appMediator: ArchiveMediatorProtocol
    
    private let fileViewer: FileViewerServiceProtocol
    private let passwordVault: PasswordVaultManaging
    private let progressThrottler = ThrottledProgressPublisher(maxFrequencyHz: 60.0)
    private let recentArchivesKey = "TTZipRecentArchivesKey"
    
    public init(
        navigationState: NavigationState = NavigationState(),
        explorerState: ArchiveExplorerState = ArchiveExplorerState(),
        taskState: TaskExecutionState = TaskExecutionState(),
        overlayState: OverlayState = OverlayState(),
        fileViewer: FileViewerServiceProtocol = MacNSWorkspaceFileViewer(),
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared,
        historyManager: CommandHistoryManager = CommandHistoryManager.shared
    ) {
        self.navigationState = navigationState
        self.explorerState = explorerState
        self.taskState = taskState
        self.overlayState = overlayState
        self.fileViewer = fileViewer
        self.passwordVault = passwordVault

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
        
        ArchiveProgressBroadcaster.shared.addObserver(self, dispatchQueue: .main)
        ArchiveEventCenter.shared.addObserver(self, dispatchQueue: .main)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TTZipPerformUndoNotification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.performUndo()
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TTZipPerformRedoNotification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.performRedo()
            }
        }
        
        updateUndoRedoState()
        ArchiveAppMediator.shared.register(component: self)
    }
    
    // MARK: - Mediator Event Handling
    
    nonisolated public func receive(event: AppMediatorEvent) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.handleAppMediatorEvent(event)
            }
        } else {
            Task { @MainActor in
                self.handleAppMediatorEvent(event)
            }
        }
    }
    
    nonisolated public func receive(event: CoreEngineMediatorEvent) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.handleCoreEngineMediatorEvent(event)
            }
        } else {
            Task { @MainActor in
                self.handleCoreEngineMediatorEvent(event)
            }
        }
    }
    
    public func handleAppMediatorEvent(_ event: AppMediatorEvent) {
        switch event {
        case .requestPasswordPrompt(let path):
            self.pendingEncryptedPath = path
            self.showPasswordPrompt = true
        case .passwordUnlocked(let path, let password):
            if self.pendingEncryptedPath == path || self.currentArchivePath == path {
                self.activePassword = password
                self.showPasswordPrompt = false
            }
        case .requestCompression(let inputPaths, _):
            self.selectedPathsToCompress = inputPaths
            self.showCompressModal = true
        case .compressionCompleted(let outputPath):
            self.statusMessage = "Compression complete: \(outputPath)"
            self.showCompressModal = false
        case .requestExtraction(let archivePath, _):
            self.currentArchivePath = archivePath
            self.showExtractModal = true
        case .extractionFailed(let archivePath, let error):
            self.statusMessage = "Extraction failed (\(archivePath)): \(error)"
        case .presetSelected(let presetId):
            self.statusMessage = "Preset selected: \(presetId)"
        case .securityThreatDetected(let path, let reason):
            self.statusMessage = "Security warning (\(path)): \(reason)"
        case .taskStateChanged(_, let stateDesc):
            self.statusMessage = "Task status: \(stateDesc)"
        case .openTab(let index):
            if index >= 0 && index < WorkspaceTab.allCases.count {
                self.activeTab = WorkspaceTab.allCases[index]
            }
        }
    }
    
    public func handleCoreEngineMediatorEvent(_ event: CoreEngineMediatorEvent) {
        switch event {
        case .extractionFailedNeedPassword(let archivePath):
            self.pendingEncryptedPath = archivePath
            self.showPasswordPrompt = true
        case .vaultPasswordUnlocked(_, let password):
            self.activePassword = password
        case .extractionSucceeded(let archivePath, _):
            self.statusMessage = "Extraction succeeded: \(archivePath)"
        case .securityScanRequested(let targetPath):
            self.statusMessage = "Security scan in progress: \(targetPath)"
        default:
            break
        }
    }
    
    // MARK: - Task State Control
    
    public func bindTaskStateMachine(_ stateMachine: ArchiveTaskStateMachine) {
        self.activeTaskStateMachine = stateMachine
        stateMachine.onStateChanged = { [weak self] _, _ in
            Task { @MainActor in
                self?.updateTaskStateUI()
            }
        }
        updateTaskStateUI()
    }
    
    @discardableResult
    public func createAndBindTaskStateMachine(taskName: String = "ArchiveTask", totalBytes: Int64 = 0) -> ArchiveTaskStateMachine {
        let sm = TTZipEngineFacade.shared.createTaskStateMachine(taskName: taskName, totalBytes: totalBytes)
        bindTaskStateMachine(sm)
        return sm
    }
    
    public func pauseCurrentTask() {
        guard let sm = activeTaskStateMachine else { return }
        do {
            try sm.pause()
            updateTaskStateUI()
        } catch {
            self.statusMessage = "Failed to pause task: \(error.localizedDescription)"
        }
    }
    
    public func resumeCurrentTask() {
        guard let sm = activeTaskStateMachine else { return }
        do {
            try sm.resume()
            updateTaskStateUI()
        } catch {
            self.statusMessage = "Failed to resume task: \(error.localizedDescription)"
        }
    }
    
    public func cancelCurrentTask() {
        guard let sm = activeTaskStateMachine else { return }
        do {
            try sm.cancel()
            updateTaskStateUI()
        } catch {
            self.statusMessage = "Failed to cancel task: \(error.localizedDescription)"
        }
    }
    
    public func updateTaskStateUI() {
        guard let sm = activeTaskStateMachine else {
            self.taskStateName = "Idle"
            self.canPauseTask = false
            self.canResumeTask = false
            self.canCancelTask = false
            return
        }
        self.taskStateName = sm.stateName
        self.canPauseTask = sm.canPause
        self.canResumeTask = sm.canResume
        self.canCancelTask = sm.canCancel
    }
    
    // MARK: - Observer Protocol Implementations
    
    public nonisolated func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        let isFinal = progress.fractionCompleted >= 1.0 || progress.fractionCompleted <= 0.0
        guard isFinal || progressThrottler.shouldEmit() else { return }
        
        Task { @MainActor in
            let pct = Int(progress.fractionCompleted * 100)
            self.statusMessage = "\(progress.operationType.rawValue) progress: \(pct)% (\(progress.currentFileName))"
            self.progressValue = progress.fractionCompleted
        }
    }
    
    public nonisolated func onBatchProgressUpdated(_ progress: BatchProgressInfo) {
        let isFinal = progress.completedTasks == progress.totalTasks || progress.completedTasks == 0
        guard isFinal || progressThrottler.shouldEmit() else { return }
        
        Task { @MainActor in
            let pct = Int(progress.fractionCompleted * 100)
            self.statusMessage = "Batch progress: \(progress.completedTasks)/\(progress.totalTasks) (\(pct)%)"
            if progress.totalTasks > 0 {
                self.progressValue = Double(progress.completedTasks) / Double(progress.totalTasks)
            }
        }
    }
    
    public nonisolated func onArchiveEvent(_ event: ArchiveEvent) {
        progressThrottler.forceEmit()
        Task { @MainActor in
            switch event {
            case .archiveCompleted(let path, let op, let duration, _):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = String(format: "%@ complete: %@ (%.2fs)", op.rawValue, name, duration)
            case .extractionFailed(let path, let err):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "Extraction failed: \(name) (\(err))"
            case .securityThreatIntercepted(let path, let threat):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "Threat intercepted [\(name)]: \(threat)"
            case .passwordVaultUnlocked(let path, _, _):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "Password vault unlocked: \(name)"
            case .presetChanged(_, let newName):
                self.statusMessage = "Preset changed: \(newName)"
            case .taskStateChanged(let taskId, let oldState, let newState):
                self.statusMessage = "Task [\(taskId.uuidString.prefix(8))] state: \(oldState) ➔ \(newState)"
                if let sm = self.activeTaskStateMachine, sm.id == taskId {
                    self.updateTaskStateUI()
                }
            }
        }
    }
    
    public func openArchiveAsFolder(url: URL) {
        self.activePreviewFileURL = nil
        self.activePreviewFileName = nil
        self.currentArchivePath = nil
        self.currentDirectory = url.deletingLastPathComponent()
        self.selectedDiskItem = DiskItemInfo(url: url)
        self.activeTab = .home
        self.addRecentArchive(path: url.path)
    }
    
    public func previewMediaFile(path: String) {
        let url = URL(fileURLWithPath: path)
        self.activePreviewFileURL = url
        self.activePreviewFileName = url.lastPathComponent
        self.activeTab = .home
    }
    
    public func closeMediaPreview() {
        self.activePreviewFileURL = nil
        self.activePreviewFileName = nil
    }
    
    public func quickExtractArchive(
        archivePath: String,
        targetDir: String? = nil,
        password: String? = nil,
        isSmartExtract: Bool = true,
        trashSourceAfterExtract: Bool = false
    ) async {
        let archiveURL = URL(fileURLWithPath: archivePath)
        let archiveName = archiveURL.deletingPathExtension().lastPathComponent
        let parentDir = targetDir ?? archiveURL.deletingLastPathComponent().path
        let parentURL = URL(fileURLWithPath: parentDir)
        
        let pwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        var destDir: String
        if isSmartExtract {
            let entries = (try? await ArchiveReader().inspect(archivePath: archivePath, password: pwd)) ?? []
            let smartRes = SmartExtractResolver.resolve(
                entryPaths: entries.map { $0.path },
                destinationParentURL: parentURL,
                archiveStemName: archiveName
            )
            destDir = smartRes.finalExtractionURL.path
        } else {
            destDir = (parentDir as NSString).appendingPathComponent(archiveName)
        }

        
        let stateMachine = createAndBindTaskStateMachine(taskName: "QuickExtract_\(archiveName)")
        try? stateMachine.start()
        
        await MainActor.run {
            self.statusMessage = "Extracting \(archiveName)..."
        }
        
        do {
            let res = try await SecurityProtectionProxy.shared.quickExtract(
                archivePath: archivePath,
                destinationDir: destDir,
                password: pwd,
                autoVaultUnlock: self.passwordVault.autoUnlockArchives
            )
            try? stateMachine.complete()
            await MainActor.run {
                if res.isVaultUnlocked, let pwd = res.unlockedPassword {
                    self.statusMessage = "Extracted with vault password: \(archiveName)"
                    ArchivePasswordStore.shared.setPassword(pwd, for: archivePath)
                } else {
                    self.statusMessage = "Extraction complete: \(archiveName)"
                }
                self.fileViewer.revealInFinder(at: destDir)
                if trashSourceAfterExtract {
                    try? FileManager.default.trashItem(at: archiveURL, resultingItemURL: nil)
                }
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Extraction failed: \(error.localizedDescription)"
                self.pendingEncryptedPath = archivePath
                self.showPasswordPrompt = true
            }
        }
    }

    
    public func extractSingleEntry(archivePath: String, entryPath: String, isDirectory: Bool, destinationDir: String) async {
        let name = (entryPath as NSString).lastPathComponent
        let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        await MainActor.run {
            self.statusMessage = "Extracting entry: \(name)..."
        }
        
        do {
            try await SecurityProtectionProxy.shared.extractSingleEntry(archivePath: archivePath, entryPath: entryPath, destinationDir: destinationDir, password: pwd)
            let targetExtractedFile = (destinationDir as NSString).appendingPathComponent(name)
            await MainActor.run {
                self.statusMessage = "Extracted entry: \(name)"
                self.fileViewer.revealInFinder(at: targetExtractedFile)
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Extraction failed: \(error.localizedDescription)"
            }
        }
    }
    
    @discardableResult
    public func loadArchive(path: String, password: String? = nil) async -> Bool {
        closeMediaPreview()
        isLoading = true
        statusMessage = "Reading archive metadata..."
        activeTab = .home
        
        do {
            let res = try await TTZipEngineFacade.shared.inspectArchiveCached(
                archivePath: path,
                password: password,
                autoVaultUnlock: self.passwordVault.autoUnlockArchives
            )
            self.currentArchivePath = path
            self.activePassword = res.unlockedPassword
            self.currentEntries = res.entries
            if let pwd = res.unlockedPassword, !pwd.isEmpty {
                self.statusMessage = "Unlocked with vault password"
            } else {
                self.statusMessage = "Loaded \(res.entries.count) entries"
            }
            self.isLoading = false
            self.showPasswordPrompt = false
            self.addRecentArchive(path: path)
            NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: path)
            return true
        } catch {
            self.pendingEncryptedPath = path
            self.showPasswordPrompt = true
            self.statusMessage = "Archive is encrypted. Enter password to view contents."
            self.isLoading = false
            return false
        }
    }
    
    public func addRecentArchive(path: String) {
        let record = RecentArchiveRecord(path: path)
        var updated = recentArchives.filter { $0.path != path }
        updated.insert(record, at: 0)
        if updated.count > 12 {
            updated = Array(updated.prefix(12))
        }
        recentArchives = updated
        saveRecentArchivesToStorage()
    }
    
    public func removeRecentArchive(path: String) {
        recentArchives.removeAll { $0.path == path }
        saveRecentArchivesToStorage()
    }
    
    private func loadRecentArchivesFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: recentArchivesKey),
              let records = try? JSONDecoder().decode([RecentArchiveRecord].self, from: data) else {
            return
        }
        recentArchives = records.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    
    private func saveRecentArchivesToStorage() {
        if let data = try? JSONEncoder().encode(recentArchives) {
            UserDefaults.standard.set(data, forKey: recentArchivesKey)
        }
    }
    
    public func cancelPasswordPrompt() {
        showPasswordPrompt = false
        pendingEncryptedPath = nil
        if currentEntries.isEmpty {
            currentArchivePath = nil
            activePassword = nil
            statusMessage = "Decryption cancelled"
        }
    }
    
    public func openCompressWorkspace(paths: [String] = []) {
        selectedPathsToCompress = paths
        activeTab = .compressWorkspace
    }
    
    public func reset() {
        currentArchivePath = nil
        activePassword = nil
        currentEntries = []
        statusMessage = "Ready"
        isLoading = false
        activeTab = .home
    }
    
    // MARK: - Command Undo / Redo
    
    public func updateUndoRedoState() {
        self.canUndo = historyManager.canUndo
        self.canRedo = historyManager.canRedo
        self.lastCommandDescription = historyManager.undoHistoryDescriptions.last
    }
    
    @discardableResult
    public func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult {
        guard !self.isLoading else {
            throw CommandError.invalidState(reason: "Another task is in progress.")
        }
        self.isLoading = true
        let stateMachine = createAndBindTaskStateMachine(taskName: command.description)
        try? stateMachine.start()
        defer {
            self.isLoading = false
            updateUndoRedoState()
        }
        do {
            let result = try await historyManager.execute(command: command)
            try? stateMachine.complete()
            self.statusMessage = "Command succeeded: [\(command.description)]"
            return result
        } catch {
            self.statusMessage = "Command failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    public func performUndo() {
        guard !self.isLoading && historyManager.canUndo else { return }
        self.isLoading = true
        Task { @MainActor in
            defer {
                self.isLoading = false
                self.updateUndoRedoState()
            }
            do {
                if let res = try await historyManager.undo() {
                    self.statusMessage = "Undone: \(res.message)"
                }
            } catch {
                self.statusMessage = "Undo failed: \(error.localizedDescription)"
            }
        }
    }
    
    public func performRedo() {
        guard !self.isLoading && historyManager.canRedo else { return }
        self.isLoading = true
        Task { @MainActor in
            defer {
                self.isLoading = false
                self.updateUndoRedoState()
            }
            do {
                if let res = try await historyManager.redo() {
                    self.statusMessage = "Redone: \(res.message)"
                }
            } catch {
                self.statusMessage = "Redo failed: \(error.localizedDescription)"
            }
        }
    }
}

extension AppViewState: ArchiveOriginatorProtocol {
    nonisolated public func createMemento() -> AppViewStateMemento {
        MainActor.assumeIsolated {
            AppViewStateMemento(
                activeTab: self.activeTab,
                currentArchivePath: self.currentArchivePath,
                selectedPresetID: nil,
                searchQuery: self.searchQuery,
                isSidebarExpanded: true
            )
        }
    }
    
    nonisolated public func restoreMemento(_ memento: AppViewStateMemento) {
        MainActor.assumeIsolated {
            self.activeTab = memento.activeTab
            self.currentArchivePath = memento.currentArchivePath
            self.searchQuery = memento.searchQuery
        }
    }
}
