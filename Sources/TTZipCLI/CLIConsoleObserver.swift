// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Console observer for archive events and real-time progress updates.
///
/// Implements `ArchiveProgressObserverProtocol` and `ArchiveEventObserverProtocol` to provide
/// 60Hz rate-limited ANSI terminal rendering and machine-readable NDJSON telemetry streams.
public final class CLIEventAndProgressConsoleObserver: ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, @unchecked Sendable {
    public static let shared = CLIEventAndProgressConsoleObserver()
    private init() {}
    
    public var isJsonMode: Bool = false
    public var isSilenced: Bool = false
    
    /// Handles continuous progress updates from active compression/extraction pipelines.
    /// - Parameter progress: Structured snapshot containing throughput, bytes, and completed fraction.
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        guard !isSilenced else { return }
        if isJsonMode {
            TerminalRenderEngine.shared.emitNDJSON(event: "progress", payload: [
                "fraction": progress.fractionCompleted,
                "bytes_processed": progress.bytesProcessed,
                "total_bytes": progress.totalBytes,
                "speed_mbs": progress.throughputMBs,
                "current_file": progress.currentFileName
            ])
        } else {
            TerminalRenderEngine.shared.renderProgress(
                fraction: progress.fractionCompleted,
                bytesProcessed: progress.bytesProcessed,
                totalBytes: progress.totalBytes,
                speedMBs: progress.throughputMBs,
                currentFile: (progress.currentFileName as NSString).lastPathComponent,
                operation: progress.operationType.rawValue
            )
        }
    }
    
    /// Handles discrete lifecycle events emitted by the core engine.
    /// - Parameter event: Typed lifecycle event payload.
    public func onArchiveEvent(_ event: ArchiveEvent) {
        guard !isSilenced else { return }
        switch event {
        case .archiveCompleted(let path, let op, let duration, _):
            TerminalRenderEngine.shared.completeProgress(message: String(format: " ✅ %@: %@ (%.2fs)", op.rawValue, (path as NSString).lastPathComponent, duration))
        case .extractionFailed(let path, let err):
            TerminalRenderEngine.shared.completeProgress(message: " ❌ Extraction failed: \((path as NSString).lastPathComponent) (\(err))")
        case .securityThreatIntercepted(let path, let threat):
            TerminalRenderEngine.shared.completeProgress(message: " ⚠️ Security threat intercepted: \((path as NSString).lastPathComponent) (\(threat))")
        case .passwordVaultUnlocked(let path, _, _):
            TerminalRenderEngine.shared.completeProgress(message: " ⚡️ Password vault unlocked: \((path as NSString).lastPathComponent)")
        case .presetChanged(_, let newName):
            TerminalRenderEngine.shared.completeProgress(message: " ⚙️ Preset changed: \(newName)")
        case .taskStateChanged(let taskId, let oldState, let newState):
            if !isJsonMode {
                TerminalRenderEngine.shared.completeProgress(message: " 🔄 Task state changed [\(taskId.uuidString.prefix(8))]: \(oldState) ➔ \(newState)")
            }
        }
    }
}
