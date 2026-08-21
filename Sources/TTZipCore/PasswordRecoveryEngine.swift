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
    
    public var attemptsPerSecond: Double {
        return durationSeconds > 0 ? Double(totalAttempts) / durationSeconds : 0
    }
}

/// State Pattern & Memento Pattern: Multi-threaded password verification and recovery engine.
///
/// Supports full lifecycle task state machine control (Pause / Resume / Cancel / Checkpoint save & restore).
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
        
        for i in startIndex..<totalCount {
            // Handle PausedState
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
                
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                if Task.isCancelled || sm.currentState is CancellingState || sm.currentState is FailedState {
                    break
                }
            }
            
            // Handle CancellingState
            if Task.isCancelled || sm.currentState is CancellingState {
                if !(sm.currentState is FailedState) {
                    try? sm.cancel()
                }
                throw CommandError.executionFailed(reason: "Password recovery task was cancelled")
            }
            
            let pwd = dictionary[i]
            attempts += 1
            sm.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
            sm.setCheckpointOffset(attempts)
            
            if attempts % 10 == 0 || i == totalCount - 1 {
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
            
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: pwd)
            if isCorrect {
                foundPassword = pwd
                break
            }
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
    
    /// Probes archive header and stream password in-process without extracting entire archive.
    public static func testArchivePassword(archivePath: String, password: String) async -> Bool {
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
                    let status = ttzip_rust_extract_archive(cPath, cDest, &opt)
                    if status == TTZIP_STATUS_OK {
                        return true
                    }
                    return ttzip_extract_archive_advanced(cPath, cDest, false, cPwd) == 0
                }
            }
        }
    }

    /// Fast in-memory multi-core dictionary recovery via native Rust FFI.
    public static func recoverFastInMemory(
        passwords: [String],
        archivePath: String
    ) -> String? {
        guard !passwords.isEmpty, let data = try? Data(contentsOf: URL(fileURLWithPath: archivePath)), data.count >= 30 else {
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
        
        return ptrs.withUnsafeBufferPointer { bufPtr -> String? in
            guard let basePtr = bufPtr.baseAddress else { return nil }
            
            // Check for ZipCrypto 12-byte header
            return data.withUnsafeBytes { rawBytes -> String? in
                guard let baseAddr = rawBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                if baseAddr[0] == 0x50 && baseAddr[1] == 0x4B && baseAddr[2] == 0x03 && baseAddr[3] == 0x04 {
                    let flags = UInt16(baseAddr[6]) | (UInt16(baseAddr[7]) << 8)
                    let isEncrypted = (flags & 0x01) != 0
                    let method = UInt16(baseAddr[8]) | (UInt16(baseAddr[9]) << 8)
                    let fnLen = Int(UInt16(baseAddr[26]) | (UInt16(baseAddr[27]) << 8))
                    let extraLen = Int(UInt16(baseAddr[28]) | (UInt16(baseAddr[29]) << 8))
                    let headerOffset = 30 + fnLen + extraLen
                    
                    if isEncrypted && method != 99 && rawBytes.count >= headerOffset + 12 {
                        let encHeaderPtr = baseAddr + headerOffset
                        let checkByte = baseAddr[17] // CRC byte / time byte
                        let found = ttzip_rust_crypto_recover_zipcrypto(
                            basePtr,
                            passwords.count,
                            encHeaderPtr,
                            checkByte,
                            &outFound,
                            outFound.count
                        )
                        if found {
                            return outFound.withUnsafeBufferPointer { ptr in
                                ptr.baseAddress.map { String(cString: $0) }
                            }
                        }
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
