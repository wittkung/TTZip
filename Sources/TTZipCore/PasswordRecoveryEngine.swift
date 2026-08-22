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

/// Multi-threaded password verification and recovery engine.
///
/// Directly delegates to high-throughput multi-core Rust Rayon recovery pipelines.
public final class PasswordRecoveryEngine: @unchecked Sendable {
    public init() {}
    
    /// Tests dictionary candidate passwords against encrypted archive headers.
    public func recoverPassword(
        archivePath: String,
        dictionary: [String]
    ) async throws -> PasswordRecoveryResult {
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let start = Date()
        let is7z = archivePath.lowercased().contains(".7z")
        if !is7z, let fastFound = Self.recoverFastInMemory(passwords: dictionary, archivePath: archivePath) {
            let duration = max(0.001, Date().timeIntervalSince(start))
            return PasswordRecoveryResult(
                foundPassword: fastFound,
                totalAttempts: Int64(dictionary.firstIndex(of: fastFound).map { $0 + 1 } ?? dictionary.count),
                durationSeconds: duration
            )
        }
        
        var attempts: Int64 = 0
        var foundPassword: String? = nil
        for pwd in dictionary {
            attempts += 1
            if await Self.testArchivePassword(archivePath: archivePath, password: pwd) {
                foundPassword = pwd
                break
            }
        }
        
        let duration = max(0.001, Date().timeIntervalSince(start))
        return PasswordRecoveryResult(
            foundPassword: foundPassword,
            totalAttempts: attempts,
            durationSeconds: duration
        )
    }
    
    /// Probes archive header and stream password in-process without full extraction.
    public static func testArchivePassword(archivePath: String, password: String) async -> Bool {
        if let bin7z = SevenZipBinaryResolver.resolveBinaryPath(), archivePath.lowercased().contains(".7z") {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin7z)
            proc.arguments = ["t", "-p\(password)", "-y", archivePath]
            proc.standardInput = FileHandle.nullDevice
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                return proc.terminationStatus == 0
            }
        }
        if !archivePath.lowercased().contains(".7z"), let fast = recoverFastInMemory(passwords: [password], archivePath: archivePath) {
            return fast == password
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("probe_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

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
                    return ttzip_rust_archive_extract_unified(cPath, cDest, &opt) == TTZIP_STATUS_OK
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
}
