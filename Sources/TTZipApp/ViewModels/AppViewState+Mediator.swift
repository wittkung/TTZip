// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

extension AppViewState: ArchiveMediatorComponentProtocol {
    nonisolated public var mediator: ArchiveMediatorProtocol? {
        get { ArchiveAppMediator.shared }
        set {}
    }
    
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
}
