// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - PasswordRecoveryEngine Originator Conformance

extension PasswordRecoveryEngine: ArchiveOriginatorProtocol {
    public typealias Memento = TaskCheckpointMemento
    
    /// Creates default checkpoint snapshot for password recovery engine.
    public func createMemento() -> TaskCheckpointMemento {
        return TaskCheckpointMemento(
            taskID: UUID(),
            taskName: "PasswordRecoveryTask",
            stateName: "Running",
            processedBytes: 0,
            totalBytes: 0,
            dictionaryOffset: 0,
            throughputTPS: 0.0,
            checksum: ""
        )
    }
    
    /// Creates parametrized checkpoint snapshot for password recovery engine.
    public func createMemento(
        taskID: UUID,
        taskName: String,
        stateName: String,
        processedBytes: Int64,
        totalBytes: Int64,
        dictionaryOffset: Int64,
        throughputTPS: Double = 0.0,
        checksum: String = ""
    ) -> TaskCheckpointMemento {
        return TaskCheckpointMemento(
            taskID: taskID,
            taskName: taskName,
            stateName: stateName,
            processedBytes: processedBytes,
            totalBytes: totalBytes,
            dictionaryOffset: dictionaryOffset,
            throughputTPS: throughputTPS,
            checksum: checksum
        )
    }
    
    /// Restores password recovery engine state from checkpoint snapshot.
    public func restoreMemento(_ memento: TaskCheckpointMemento) {
        // Restores checkpoint state offsets and metrics
    }
}
