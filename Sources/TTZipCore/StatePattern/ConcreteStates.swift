// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - 1. IdleState (Initial idle preparation state)
public struct IdleState: ArchiveTaskStateProtocol {
    public let stateName = "Idle"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 2. PreparingState (Validation and resource allocation state)
public struct PreparingState: ArchiveTaskStateProtocol {
    public let stateName = "Preparing"
    public let canPause = false
    public let canResume = false
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "Task cancelled in preparation stage.")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        context.transitionTo(CompletedState())
    }
}

// MARK: - 3. RunningState (Streaming compression/decompression active state)
public struct RunningState: ArchiveTaskStateProtocol {
    public let stateName = "Running"
    public let canPause = true
    public let canResume = false
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        context.setCheckpointOffset(context.processedBytes)
        guard context.transitionTo(PausedState()) else {
            throw ArchiveError.invalidState
        }
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "Task cancelled while running.")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        context.updateProgress(processedBytes: max(context.processedBytes, context.totalBytes))
        context.transitionTo(CompletedState())
    }
}

// MARK: - 4. PausedState (Paused and suspended state)
public struct PausedState: ArchiveTaskStateProtocol {
    public let stateName = "Paused"
    public let canPause = false
    public let canResume = true
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        context.updateProgress(processedBytes: context.checkpointOffset)
        guard context.transitionTo(RunningState()) else {
            throw ArchiveError.invalidState
        }
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "Task cancelled while paused.")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 5. CancellingState (Cancelling and cleanup in progress state)
public struct CancellingState: ArchiveTaskStateProtocol {
    public let stateName = "Cancelling"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 6. CompletedState (Terminal successful completion state)
public struct CompletedState: ArchiveTaskStateProtocol {
    public let stateName = "Completed"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        throw ArchiveStateError.taskAlreadyCompleted
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.taskAlreadyCompleted
    }
}

// MARK: - 7. FailedState (Terminal failure state)
public struct FailedState: ArchiveTaskStateProtocol {
    public let stateName = "Failed"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public let error: Error
    
    public init(error: Error) {
        self.error = error
    }
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        throw ArchiveStateError.taskAlreadyFailed(reason: self.error.localizedDescription)
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.taskAlreadyFailed(reason: error.localizedDescription)
    }
}
