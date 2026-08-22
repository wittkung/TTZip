// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

/// 1. Navigation and routing state.
@MainActor
public final class NavigationState: ObservableObject {
    @Published public var activeTab: WorkspaceTab = .home
    @Published public var sidebarSelection: String? = nil
    @Published public var isInspectorVisible: Bool = true
    @Published public var currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
    
    public init() {}
}

/// 2. Archive explorer and in-archive preview state.
@MainActor
public final class ArchiveExplorerState: ObservableObject {
    @Published public var currentArchivePath: String? = nil
    @Published public var activePassword: String? = nil
    @Published public var currentEntries: [ArchiveEntry] = []
    @Published public var activePreviewFileURL: URL? = nil
    @Published public var activePreviewFileName: String? = nil
    @Published public var searchQuery: String = ""
    
    public init() {}
    
    public var filteredEntries: [ArchiveEntry] {
        let pattern = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if pattern.isEmpty {
            return currentEntries
        }
        return currentEntries.filter { $0.path.lowercased().contains(pattern) }
    }
}

/// 3. Background task execution and lifecycle state.
@MainActor
public final class TaskExecutionState: ObservableObject {
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var progressValue: Double = 0.0
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

/// 4. Modal, Sheet, and Popover presentation overlay state.
@MainActor
public final class OverlayState: ObservableObject {
    @Published public var showCompressModal: Bool = false
    @Published public var showExtractModal: Bool = false
    @Published public var showPasswordPrompt: Bool = false
    @Published public var pendingEncryptedPath: String? = nil
    @Published public var selectedDiskItem: DiskItemInfo? = nil
    @Published public var selectedPathsToCompress: [String] = []
    
    // Archive Inspector & Diagnostics
    @Published public var showArchiveInspectorModal: Bool = false
    @Published public var inspectingArchivePath: String? = nil
    
    public init() {}
}
