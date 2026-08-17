import Foundation
import SwiftUI
import TTZipCore

/// 1. 导航与页面路由状态
@MainActor
public final class NavigationState: ObservableObject {
    @Published public var activeTab: WorkspaceTab = .home
    @Published public var sidebarSelection: String? = nil
    @Published public var isInspectorVisible: Bool = true
    @Published public var currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
    
    public init() {}
}

/// 2. 归档包内资源浏览与预览状态
@MainActor
public final class ArchiveExplorerState: ObservableObject {
    @Published public var currentArchivePath: String? = nil
    @Published public var activePassword: String? = nil
    @Published public var currentEntries: [ArchiveEntry] = []
    @Published public var activePreviewFileURL: URL? = nil
    @Published public var activePreviewFileName: String? = nil
    @Published public var searchQuery: String = ""
    
    public init() {}
    
    /// 运用【3.7 迭代器模式 (Iterator Pattern)】针对 currentEntries 提供迭代器与 Swift Sequence 支持
    public var filteredEntriesIterator: ArrayArchiveIterator {
        let pattern = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return ArrayArchiveIterator(
            entries: currentEntries,
            namePattern: pattern.isEmpty ? nil : pattern
        )
    }
    
    public var filteredEntries: [ArchiveEntry] {
        return Array(filteredEntriesIterator)
    }
}

/// 3. 后台压缩/解压任务执行与控制状态
@MainActor
public final class TaskExecutionState: ObservableObject {
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "就绪"
    @Published public var progressValue: Double = 0.0
    @Published public var activeTaskStateMachine: ArchiveTaskStateMachine? = nil
    @Published public var taskStateName: String = "Idle"
    @Published public var canPauseTask: Bool = false
    @Published public var canResumeTask: Bool = false
    @Published public var canCancelTask: Bool = false
    
    // Command History (Undo / Redo)
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    @Published public var lastCommandDescription: String? = nil
    
    public init() {}
}

/// 4. 弹窗 / Modal / Sheet 覆盖层状态
@MainActor
public final class OverlayState: ObservableObject {
    @Published public var showCompressModal: Bool = false
    @Published public var showExtractModal: Bool = false
    @Published public var showPasswordPrompt: Bool = false
    @Published public var pendingEncryptedPath: String? = nil
    @Published public var selectedDiskItem: DiskItemInfo? = nil
    @Published public var selectedPathsToCompress: [String] = []
    
    public init() {}
}
