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
    
    public func pauseCurrentTask() {
        self.canPauseTask = false
        self.canResumeTask = true
        self.taskStateName = "Paused"
    }
    
    public func resumeCurrentTask() {
        self.canPauseTask = true
        self.canResumeTask = false
        self.taskStateName = "Processing"
    }
    
    public func cancelCurrentTask() {
        self.canPauseTask = false
        self.canResumeTask = false
        self.taskStateName = "Cancelled"
    }
    
    public func updateTaskStateUI() {
        self.taskStateName = "Idle"
        self.canPauseTask = false
        self.canResumeTask = false
        self.canCancelTask = false
    }
}
