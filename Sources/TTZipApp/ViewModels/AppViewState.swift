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


/// TTZip GUI 主视图 ViewModel，协调线程安全的 UI 交互与解耦的领域状态树
@MainActor
public final class AppViewState: ObservableObject, ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, ArchiveMediatorComponentProtocol {
    public typealias Memento = AppViewStateMemento
    
    // MARK: - 【3.9 备忘录模式 (Memento Pattern)】UI 布局快照管理者
    public let workspaceCaretaker = AppViewStateCaretaker()
    
    // MARK: - 【3.8 中介者模式 (Mediator Pattern)】中介者句柄
    nonisolated public var mediator: ArchiveMediatorProtocol? {
        get { ArchiveAppMediator.shared }
        set {}
    }

    // MARK: - 领域子状态 (Domain Sub-States)
    public let navigationState: NavigationState
    public let explorerState: ArchiveExplorerState
    public let taskState: TaskExecutionState
    public let overlayState: OverlayState
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 【3.9 备忘录模式 (Memento Pattern)】Originator 快照保存与恢复
    
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
    
    @Published public var recentArchives: [RecentArchiveRecord] = []
    
    // MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】使用 @Injected 解耦核心服务与中介者
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

        
        // 绑定子状态 objectWillChange 事件以便向 Coordinator 外发广播
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
    
    // MARK: - 【3.8 中介者模式 (Mediator Pattern)】接收中介事件
    
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
            self.statusMessage = "✅ 压缩完成: \(outputPath)"
            self.showCompressModal = false
        case .requestExtraction(let archivePath, _):
            self.currentArchivePath = archivePath
            self.showExtractModal = true
        case .extractionFailed(let archivePath, let error):
            self.statusMessage = "❌ 解压失败 (\(archivePath)): \(error)"
        case .presetSelected(let presetId):
            self.statusMessage = "预设已切换: \(presetId)"
        case .securityThreatDetected(let path, let reason):
            self.statusMessage = "⚠️ 安全警告 (\(path)): \(reason)"
        case .taskStateChanged(_, let stateDesc):
            self.statusMessage = "任务状态: \(stateDesc)"
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
            self.statusMessage = "✅ 解压成功: \(archivePath)"
        case .securityScanRequested(let targetPath):
            self.statusMessage = "🔍 安全扫描中: \(targetPath)"
        default:
            break
        }
    }
    
    // MARK: - 【3.5 状态模式 (State Pattern)】状态控制操作 API
    
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
            self.statusMessage = "❌ 暂停任务失败: \(error.localizedDescription)"
        }
    }
    
    public func resumeCurrentTask() {
        guard let sm = activeTaskStateMachine else { return }
        do {
            try sm.resume()
            updateTaskStateUI()
        } catch {
            self.statusMessage = "❌ 恢复任务失败: \(error.localizedDescription)"
        }
    }
    
    public func cancelCurrentTask() {
        guard let sm = activeTaskStateMachine else { return }
        do {
            try sm.cancel()
            updateTaskStateUI()
        } catch {
            self.statusMessage = "❌ 取消任务失败: \(error.localizedDescription)"
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
    
    // MARK: - 【3.2 观察者模式 (Observer Pattern)】事件与进度回调实现
    
    public nonisolated func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        let isFinal = progress.fractionCompleted >= 1.0 || progress.fractionCompleted <= 0.0
        guard isFinal || progressThrottler.shouldEmit() else { return }
        
        Task { @MainActor in
            let pct = Int(progress.fractionCompleted * 100)
            self.statusMessage = "⏳ \(progress.operationType.rawValue)进度: \(pct)% (\(progress.currentFileName))"
            self.progressValue = progress.fractionCompleted
        }
    }
    
    public nonisolated func onBatchProgressUpdated(_ progress: BatchProgressInfo) {
        let isFinal = progress.completedTasks == progress.totalTasks || progress.completedTasks == 0
        guard isFinal || progressThrottler.shouldEmit() else { return }
        
        Task { @MainActor in
            let pct = Int(progress.fractionCompleted * 100)
            self.statusMessage = "📦 批处理进度: \(progress.completedTasks)/\(progress.totalTasks) (\(pct)%)"
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
                self.statusMessage = String(format: "✅ %@完成: %@ (耗时 %.2fs)", op.rawValue, name, duration)
            case .extractionFailed(let path, let err):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "❌ 解压失败: \(name) (\(err))"
            case .securityThreatIntercepted(let path, let threat):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "⚠️ 拦截安全威胁 [\(name)]: \(threat)"
            case .passwordVaultUnlocked(let path, _, _):
                let name = (path as NSString).lastPathComponent
                self.statusMessage = "⚡️ 密码库解锁成功: \(name)"
            case .presetChanged(_, let newName):
                self.statusMessage = "⚙️ 压缩预设已变更: \(newName)"
            case .taskStateChanged(let taskId, let oldState, let newState):
                self.statusMessage = "🔄 任务 [\(taskId.uuidString.prefix(8))] 状态变更: \(oldState) ➔ \(newState)"
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
    
    /// 快捷静默解压到当前同名目录
    public func quickExtractArchive(archivePath: String, targetDir: String? = nil, password: String? = nil) async {
        let archiveURL = URL(fileURLWithPath: archivePath)
        let archiveName = archiveURL.deletingPathExtension().lastPathComponent
        let parentDir = targetDir ?? archiveURL.deletingLastPathComponent().path
        let destDir = (parentDir as NSString).appendingPathComponent(archiveName)
        
        let pwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        let stateMachine = createAndBindTaskStateMachine(taskName: "QuickExtract_\(archiveName)")
        try? stateMachine.start()
        
        await MainActor.run {
            self.statusMessage = "⏳ 正在极速解压 \(archiveName)..."
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
                    self.statusMessage = "⚡️ 已通过密码库口令完成解压: \(archiveName)"
                    ArchivePasswordStore.shared.setPassword(pwd, for: archivePath)
                } else {
                    self.statusMessage = "✅ 解压完成: \(archiveName)"
                }
                self.fileViewer.revealInFinder(at: destDir)
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "🔒 解压失败或需口令: \(error.localizedDescription)"
                self.pendingEncryptedPath = archivePath
                self.showPasswordPrompt = true
            }
        }
    }
    
    /// 单独提取包内某个文件/文件夹
    public func extractSingleEntry(archivePath: String, entryPath: String, isDirectory: Bool, destinationDir: String) async {
        let name = (entryPath as NSString).lastPathComponent
        let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath) ?? activePassword
        
        await MainActor.run {
            self.statusMessage = "⏳ 正在提取包内项目: \(name)..."
        }
        
        do {
            try await SecurityProtectionProxy.shared.extractSingleEntry(archivePath: archivePath, entryPath: entryPath, destinationDir: destinationDir, password: pwd)
            let targetExtractedFile = (destinationDir as NSString).appendingPathComponent(name)
            await MainActor.run {
                self.statusMessage = "✅ 提取完成: \(name)"
                self.fileViewer.revealInFinder(at: targetExtractedFile)
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "❌ 提取失败: \(error.localizedDescription)"
            }
        }
    }
    
    /// 加载并检查归档文件目录树 (支持自动尝试密码库与弹出口令输入框，返回是否成功)
    @discardableResult
    public func loadArchive(path: String, password: String? = nil) async -> Bool {
        closeMediaPreview()
        isLoading = true
        statusMessage = "正在读取归档元数据..."
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
                self.statusMessage = "⚡️ 已从密码库自动识别口令并成功解密"
            } else {
                self.statusMessage = "加载成功，共计 \(res.entries.count) 个条目"
            }
            self.isLoading = false
            self.showPasswordPrompt = false
            self.addRecentArchive(path: path)
            NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: path)
            return true
        } catch {
            self.pendingEncryptedPath = path
            self.showPasswordPrompt = true
            self.statusMessage = "🔒 归档文件已被加密，请输入解压口令以查看内容"
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
    
    /// 取消口令输入时关闭弹框并退出空白的未解密归档页面
    public func cancelPasswordPrompt() {
        showPasswordPrompt = false
        pendingEncryptedPath = nil
        if currentEntries.isEmpty {
            currentArchivePath = nil
            activePassword = nil
            statusMessage = "已取消解密"
        }
    }
    
    /// 打开压缩工作区页签
    public func openCompressWorkspace(paths: [String] = []) {
        selectedPathsToCompress = paths
        activeTab = .compressWorkspace
    }
    
    /// 重置状态回到准备接收文件的空状态
    public func reset() {
        currentArchivePath = nil
        activePassword = nil
        currentEntries = []
        statusMessage = "就绪"
        isLoading = false
        activeTab = .home
    }
    
    // MARK: - 【3.4 命令模式 (Command Pattern)】Undo / Redo 菜单绑定与历史逻辑
    
    public func updateUndoRedoState() {
        self.canUndo = historyManager.canUndo
        self.canRedo = historyManager.canRedo
        self.lastCommandDescription = historyManager.undoHistoryDescriptions.last
    }
    
    @discardableResult
    public func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult {
        guard !self.isLoading else {
            throw CommandError.invalidState(reason: "已有任务正在进行中，请稍候")
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
            self.statusMessage = "✅ 执行命令成功: [\(command.description)]"
            return result
        } catch {
            self.statusMessage = "❌ 执行命令失败: \(error.localizedDescription)"
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
                    self.statusMessage = "↩️ \(res.message)"
                }
            } catch {
                self.statusMessage = "❌ 撤销失败: \(error.localizedDescription)"
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
                    self.statusMessage = "↪️ 重做命令成功: \(res.message)"
                }
            } catch {
                self.statusMessage = "❌ 重做失败: \(error.localizedDescription)"
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

