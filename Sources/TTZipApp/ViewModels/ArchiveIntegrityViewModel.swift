// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

@MainActor
public final class ArchiveIntegrityViewModel: ObservableObject {
    @Published public var isVerifying: Bool = false
    @Published public var progressFraction: Double = 0.0
    @Published public var currentVerifyingEntry: String = ""
    @Published public var report: ArchiveIntegrityReport?
    @Published public var errorMessage: String?
    
    public init() {}
    
    public func startIntegrityCheck(archivePath: String, password: String? = nil) {
        isVerifying = true
        progressFraction = 0.0
        currentVerifyingEntry = "Initializing..."
        report = nil
        errorMessage = nil
        
        Task {
            do {
                let checker = ArchiveIntegrityChecker()
                let result = try await checker.checkArchiveIntegrity(
                    archivePath: archivePath,
                    password: password
                ) { [weak self] progress, entry in
                    Task { @MainActor in
                        self?.progressFraction = progress
                        self?.currentVerifyingEntry = entry
                    }
                }
                self.report = result
                self.isVerifying = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isVerifying = false
            }
        }
    }
}
