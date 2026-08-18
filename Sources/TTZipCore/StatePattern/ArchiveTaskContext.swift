// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive task state machine context (State Pattern Context).
///
/// Encapsulates execution state, byte metrics, checkpoint offsets, throughput telemetry, and thread synchronization.
public final class ArchiveTaskContext: @unchecked Sendable {
    public let id: UUID
    public let taskName: String
    
    private var _currentState: ArchiveTaskStateProtocol
    private var _processedBytes: Int64
    private var _totalBytes: Int64
    private var _checkpointOffset: Int64
    private var _metrics: TaskMetrics
    private var _lastError: Error?
    private var _tempFiles: [String]
    private var _pauseStartTime: Date?
    
    private let stateLock = NSLock()
    private let notificationLock = NSLock()
    private var _pendingNotifications: [(oldStateName: String, newState: ArchiveTaskStateProtocol)] = []
    
    /// State transition callback.
    public var onStateChanged: (@Sendable (ArchiveTaskContext, ArchiveTaskStateProtocol) -> Void)?
    /// Progress update callback.
    public var onProgressUpdated: (@Sendable (ArchiveTaskContext) -> Void)?
    
    public init(
        id: UUID = UUID(),
        taskName: String = "ArchiveTask",
        initialState: ArchiveTaskStateProtocol = IdleState(),
        totalBytes: Int64 = 0
    ) {
        self.id = id
        self.taskName = taskName
        self._currentState = initialState
        self._processedBytes = 0
        self._totalBytes = max(0, totalBytes)
        self._checkpointOffset = 0
        self._metrics = TaskMetrics(totalBytes: max(0, totalBytes))
        self._tempFiles = []
    }
    
    // MARK: - Thread-Safe Property Accessors
    
    public var currentState: ArchiveTaskStateProtocol {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _currentState
    }
    
    public var processedBytes: Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _processedBytes
    }
    
    public var totalBytes: Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _totalBytes
    }
    
    public var checkpointOffset: Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _checkpointOffset
    }
    
    public var metrics: TaskMetrics {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _metrics
    }
    
    public var lastError: Error? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _lastError
    }
    
    public var tempFiles: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _tempFiles
    }
    
    public var canPause: Bool { currentState.canPause }
    public var canResume: Bool { currentState.canResume }
    public var canCancel: Bool { currentState.canCancel }
    public var stateName: String { currentState.stateName }
    
    // MARK: - State Control Operations
    
    public func prepare() throws {
        stateLock.lock()
        let state = _currentState
        stateLock.unlock()
        
        if state is IdleState {
            transitionTo(PreparingState())
        } else {
            throw ArchiveStateError.invalidTransition(from: state.stateName, action: "prepare")
        }
    }
    
    public func start() throws {
        stateLock.lock()
        let state = _currentState
        stateLock.unlock()
        
        if state is IdleState {
            if transitionTo(PreparingState()) {
                transitionTo(RunningState())
            }
        } else if state is PreparingState {
            transitionTo(RunningState())
        } else {
            throw ArchiveStateError.invalidTransition(from: state.stateName, action: "start")
        }
    }
    
    public func pause() throws {
        let state = currentState
        guard state.canPause else {
            throw ArchiveError.invalidState
        }
        try state.pause(context: self)
    }
    
    public func resume() throws {
        let state = currentState
        guard state.canResume else {
            throw ArchiveError.invalidState
        }
        try state.resume(context: self)
    }
    
    public func cancel() throws {
        let state = currentState
        guard state.canCancel else {
            throw ArchiveError.invalidState
        }
        try state.cancel(context: self)
    }
    
    public func fail(error: Error) throws {
        let state = currentState
        try state.fail(context: self, error: error)
    }
    
    public func complete() throws {
        let state = currentState
        try state.complete(context: self)
    }
    
    // MARK: - State Transitions
    
    @discardableResult
    public func transitionTo(_ newState: ArchiveTaskStateProtocol) -> Bool {
        let oldStateName: String
        let callback: (@Sendable (ArchiveTaskContext, ArchiveTaskStateProtocol) -> Void)?
        
        stateLock.lock()
        if _currentState is CompletedState || _currentState is FailedState {
            stateLock.unlock()
            return false
        }
        if _currentState is CancellingState && !(newState is FailedState) {
            stateLock.unlock()
            return false
        }
        
        oldStateName = _currentState.stateName
        _currentState = newState
        
        if let pauseStart = _pauseStartTime, !(newState is PausedState) {
            let duration = Date().timeIntervalSince(pauseStart)
            if duration > 0 {
                _metrics.pauseDuration += duration
            }
            _pauseStartTime = nil
        }
        
        if newState is RunningState {
            if _metrics.startTime == nil {
                _metrics.startTime = Date()
            }
        } else if newState is PausedState {
            if _pauseStartTime == nil {
                _pauseStartTime = Date()
            }
        } else if newState is CompletedState || newState is FailedState {
            if _metrics.endTime == nil {
                _metrics.endTime = Date()
            }
        }
        
        _pendingNotifications.append((oldStateName: oldStateName, newState: newState))
        callback = onStateChanged
        stateLock.unlock()
        
        dispatchPendingNotifications(callback: callback)
        return true
    }
    
    private func dispatchPendingNotifications(callback: ((@Sendable (ArchiveTaskContext, ArchiveTaskStateProtocol) -> Void))?) {
        notificationLock.lock()
        defer { notificationLock.unlock() }
        
        var itemsToProcess: [(oldStateName: String, newState: ArchiveTaskStateProtocol)] = []
        stateLock.lock()
        if !_pendingNotifications.isEmpty {
            itemsToProcess = _pendingNotifications
            _pendingNotifications.removeAll()
        }
        stateLock.unlock()
        
        for item in itemsToProcess {
            callback?(self, item.newState)
            ArchiveEventCenter.shared.postTaskStateChanged(taskId: id, oldState: item.oldStateName, newState: item.newState.stateName)
        }
    }
    
    // MARK: - Progress & Diagnostic Updates
    
    public func setCheckpointOffset(_ offset: Int64) {
        stateLock.lock()
        defer { stateLock.unlock() }
        _checkpointOffset = max(0, offset)
    }
    
    public func setLastError(_ error: Error) {
        stateLock.lock()
        defer { stateLock.unlock() }
        if _currentState is CompletedState { return }
        _lastError = error
    }
    
    public func updateProgress(processedBytes: Int64, totalBytes: Int64? = nil) {
        let progressCallback: (@Sendable (ArchiveTaskContext) -> Void)?
        stateLock.lock()
        _processedBytes = max(0, processedBytes)
        if let tot = totalBytes {
            _totalBytes = max(0, tot)
            _metrics.totalBytes = _totalBytes
        }
        _metrics.processedBytes = _processedBytes
        let duration = _metrics.durationSeconds
        if duration > 0 && !duration.isNaN && !duration.isInfinite {
            let mb = Double(_processedBytes) / (1024.0 * 1024.0)
            let rate = mb / duration
            _metrics.throughputMBs = (rate.isNaN || rate.isInfinite || rate < 0) ? 0.0 : rate
        } else {
            _metrics.throughputMBs = 0.0
        }
        progressCallback = onProgressUpdated
        stateLock.unlock()
        
        progressCallback?(self)
    }
    
    public func addTempFile(_ path: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        if !_tempFiles.contains(path) {
            _tempFiles.append(path)
        }
    }
    
    public func cleanupTempFiles() {
        stateLock.lock()
        let files = _tempFiles
        _tempFiles.removeAll()
        stateLock.unlock()
        
        for file in files {
            try? FileManager.default.removeItem(atPath: file)
        }
    }
}

/// Type alias for `ArchiveTaskContext`.
public typealias ArchiveTaskStateMachine = ArchiveTaskContext
