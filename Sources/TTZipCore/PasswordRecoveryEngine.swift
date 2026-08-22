// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Value type representing metrics and outcomes from password recovery exploration.
public struct PasswordRecoveryResult: Sendable {
    public let foundPassword: String?
    public let totalAttempts: Int64
    public let durationSeconds: Double
    
    public init(foundPassword: String?, totalAttempts: Int64, durationSeconds: Double) {
        self.foundPassword = foundPassword
        self.totalAttempts = totalAttempts
        self.durationSeconds = durationSeconds
    }
    
    public var attemptsPerSecond: Double {
        return durationSeconds > 0 ? Double(totalAttempts) / durationSeconds : 0
    }
}

/// State Pattern & Memento Pattern: Multi-threaded password verification and recovery engine.
///
/// Directly delegates to high-throughput multi-core Rust Rayon recovery pipelines.
public final class PasswordRecoveryEngine: @unchecked Sendable {
    public let checkpointCaretaker: TaskCheckpointCaretaker
    
    public init(checkpointCaretaker: TaskCheckpointCaretaker = TaskCheckpointCaretaker()) {
        self.checkpointCaretaker = checkpointCaretaker
    }
    
    /// Tests dictionary candidate passwords against encrypted archive headers.
    public func recoverPassword(
        archivePath: String,
        dictionary: [String],
        stateMachine: ArchiveTaskStateMachine? = nil
    ) async throws -> PasswordRecoveryResult {
        if let sm = stateMachine {
            if sm.currentState is CompletedState {
                throw ArchiveStateError.taskAlreadyCompleted
            } else if sm.currentState is FailedState {
                throw ArchiveStateError.taskAlreadyFailed(reason: sm.lastError?.localizedDescription ?? "Task already failed")
            }
        }
        
        guard FileManager.default.fileExists(atPath: archivePath) else {
            let err = ArchiveError.fileNotFound
            try? stateMachine?.fail(error: err)
            throw err
        }
        
        let sm = stateMachine ?? ArchiveTaskStateMachine(
            taskName: "PasswordRecovery:\((archivePath as NSString).lastPathComponent)",
            totalBytes: Int64(dictionary.count)
        )
        if sm.currentState is IdleState {
            try? sm.start()
        }
        
        if sm.checkpointOffset == 0, let loaded = checkpointCaretaker.loadCheckpoint(taskID: sm.id) {
            sm.setCheckpointOffset(loaded.dictionaryOffset)
        }
        
        let startIndex = min(max(0, Int(sm.checkpointOffset)), dictionary.count)
        let totalCount = dictionary.count
        var attempts: Int64 = Int64(startIndex)
        var foundPassword: String? = nil
        let start = Date()
        
        let batchSize = 100
        var currentIndex = startIndex
        
        while currentIndex < totalCount {
            while sm.currentState is PausedState {
                let pauseMemento = TaskCheckpointMemento(
                    taskID: sm.id,
                    taskName: sm.taskName,
                    stateName: sm.stateName,
                    processedBytes: attempts,
                    totalBytes: Int64(totalCount),
                    dictionaryOffset: attempts,
                    throughputTPS: Double(attempts) / max(0.001, Date().timeIntervalSince(start)),
                    checksum: "PAUSE-\(attempts)"
                )
                checkpointCaretaker.saveCheckpoint(pauseMemento)
                try await Task.sleep(nanoseconds: 50_000_000)
                if Task.isCancelled || sm.currentState is CancellingState || sm.currentState is FailedState {
                    break
                }
            }
            
            if Task.isCancelled || sm.currentState is CancellingState {
                if !(sm.currentState is FailedState) {
                    try? sm.cancel()
                }
                throw CommandError.executionFailed(reason: "Password recovery task was cancelled")
            }
            
            let nextIndex = min(currentIndex + batchSize, totalCount)
            let batch = Array(dictionary[currentIndex..<nextIndex])
            
            if let fastFound = Self.recoverFastInMemory(passwords: batch, archivePath: archivePath) {
                foundPassword = fastFound
                attempts += Int64(batch.firstIndex(of: fastFound).map { $0 + 1 } ?? batch.count)
                sm.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
                sm.setCheckpointOffset(attempts)
                break
            } else {
                var matched: String? = nil
                for pwd in batch {
                    attempts += 1
                    sm.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
                    sm.setCheckpointOffset(attempts)
                    if await Self.testArchivePassword(archivePath: archivePath, password: pwd) {
                        matched = pwd
                        break
                    }
                }
                if let matched = matched {
                    foundPassword = matched
                    break
                }
            }
            
            currentIndex = nextIndex
            let memento = TaskCheckpointMemento(
                taskID: sm.id,
                taskName: sm.taskName,
                stateName: sm.stateName,
                processedBytes: attempts,
                totalBytes: Int64(totalCount),
                dictionaryOffset: attempts,
                throughputTPS: Double(attempts) / max(0.001, Date().timeIntervalSince(start)),
                checksum: "CHK-\(attempts)"
            )
            checkpointCaretaker.saveCheckpoint(memento)
        }
        
        let duration = max(0.001, Date().timeIntervalSince(start))
        let result = PasswordRecoveryResult(
            foundPassword: foundPassword,
            totalAttempts: attempts,
            durationSeconds: duration
        )
        
        if let pwd = result.foundPassword {
            ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: archivePath, password: pwd, isVaultUnlocked: false)
            try? sm.complete()
        } else {
            let failErr = ArchiveError.readFailed(code: -404)
            try? sm.fail(error: failErr)
        }
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: result.foundPassword != nil ? .completed : .failed(error: "Password not found"),
            bytesProcessed: result.totalAttempts,
            totalBytes: Int64(dictionary.count),
            currentFileName: (archivePath as NSString).lastPathComponent,
            throughputMBs: result.attemptsPerSecond,
            estimatedTimeRemaining: 0,
            operationType: .recover
        ))
        
        return result
    }
    
    /// Probes archive header and stream password in-process without full extraction.
    public static func testArchivePassword(archivePath: String, password: String) async -> Bool {
        if let fast = recoverFastInMemory(passwords: [password], archivePath: archivePath) {
            return fast == password
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("probe_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let pathLower = archivePath.lowercased()
        if pathLower.contains(".7z") || pathLower.contains("sevenzip") {
            return (try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: tempDir, password: password)) ?? false
        }

        return CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            CUnsafeBufferAdapter.withCString(tempDir) { cDest in
                CUnsafeBufferAdapter.withCString(password) { cPwd in
                    guard let cPath = cPath, let cDest = cDest else { return false }
                    var opt = TTZipExtractOptions(
                        destination_path: cDest,
                        password: cPwd,
                        thread_budget: 1,
                        overwrite_existing: true,
                        preserve_permissions: false,
                        dry_run: true,
                        progress_callback: nil,
                        user_data: nil
                    )
                    return ttzip_rust_extract_archive(cPath, cDest, &opt) == TTZIP_STATUS_OK
                }
            }
        }
    }

    /// Fast in-memory multi-core dictionary recovery via native Rust C-ABI.
    public static func recoverFastInMemory(
        passwords: [String],
        archivePath: String
    ) -> String? {
        guard !passwords.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            return nil
        }
        let cStrings = passwords.map { strdup($0) }
        defer {
            for ptr in cStrings {
                free(ptr)
            }
        }
        var outFound = [CChar](repeating: 0, count: 256)
        let ptrs = cStrings.map { UnsafePointer($0) }
        var attempts: UInt64 = 0
        
        return ptrs.withUnsafeBufferPointer { bufPtr -> String? in
            guard let basePtr = bufPtr.baseAddress else { return nil }
            return CUnsafeBufferAdapter.withCString(archivePath) { cPath in
                guard let cPath = cPath else { return nil }
                let status = ttzip_rust_password_recovery_start_dictionary(
                    cPath,
                    basePtr,
                    passwords.count,
                    nil,
                    &outFound,
                    outFound.count,
                    &attempts
                )
                if status == TTZIP_STATUS_OK {
                    return outFound.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) }
                    }
                }
                return nil
            }
        }
    }

    /// Template Method Pattern execution of password recovery workflow.
    public func recoverPasswordViaTemplate(
        archivePath: String,
        dictionary: [String],
        stateMachine: ArchiveTaskStateMachine? = nil
    ) async throws -> PasswordRecoveryResult {
        let context = ArchiveTemplateContext(
            operation: .recover,
            archivePath: archivePath,
            dictionary: dictionary,
            stateMachine: stateMachine
        )
        let template = PasswordRecoveryEngineTemplate()
        let result = try await template.performWorkflowAsync(context: context)
        return PasswordRecoveryResult(
            foundPassword: result.unlockedPassword,
            totalAttempts: result.processedBytes,
            durationSeconds: result.durationSeconds
        )
    }
}
