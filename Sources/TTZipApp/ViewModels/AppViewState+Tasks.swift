// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension AppViewState {
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
}

extension AppViewState: ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol {
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
}
