// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import LocalAuthentication

@MainActor
public final class PasswordVaultViewModel: ObservableObject {
    @Published public var isUnlocked: Bool = false
    @Published public var masterPasswordInput: String = ""
    @Published public var confirmMasterPasswordInput: String = ""
    @Published public var unlockErrorMessage: String = ""
    
    @Published public var isResetSheetPresented: Bool = false
    @Published public var newMasterPasswordInput: String = ""
    
    @Published public var isRecoverSheetPresented: Bool = false
    @Published public var oldMasterPasswordInput: String = ""
    @Published public var recoverErrorMessage: String = ""
    
    @Published public var entries: [PasswordVaultEntry] = []
    @Published public var isAddModalPresented: Bool = false
    
    @Published public var newLabel: String = ""
    @Published public var newPassword: String = ""
    @Published public var newCategory: String = "General"
    @Published public var copiedID: UUID? = nil
    @Published public var visiblePasswordIDs: Set<UUID> = []
    
    public var repository: KeychainPasswordRepository
    public var manager: PasswordVaultManager
    
    public init(
        repository: KeychainPasswordRepository = KeychainPasswordRepository.shared,
        manager: PasswordVaultManager = .shared
    ) {
        self.repository = repository
        self.manager = manager
        refreshState()
    }
    
    public func refreshState() {
        self.isUnlocked = repository.isUnlocked
        if isUnlocked {
            self.entries = (try? repository.fetchAll()) ?? manager.getEntries()
        }
    }
    
    public var isMasterPasswordSet: Bool {
        manager.isMasterPasswordSet
    }
    
    public var hasBackupVault: Bool {
        manager.hasBackupVault
    }
    
    public var autoUnlockArchives: Bool {
        get { manager.autoUnlockArchives }
        set { manager.autoUnlockArchives = newValue }
    }
    
    public func setupFirstMasterPassword() {
        guard masterPasswordInput == confirmMasterPasswordInput else {
            unlockErrorMessage = "Master passwords do not match. Please try again."
            return
        }
        guard !masterPasswordInput.isEmpty else {
            unlockErrorMessage = "Master password cannot be empty."
            return
        }
        
        manager.setMasterPassword(masterPasswordInput)
        isUnlocked = true
        unlockErrorMessage = ""
        masterPasswordInput = ""
        confirmMasterPasswordInput = ""
        refreshState()
    }
    
    public func unlockVault() {
        guard !masterPasswordInput.isEmpty else { return }
        let password = masterPasswordInput
        let repo = self.repository
        let mgr = self.manager
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let success = await Task.detached(priority: .userInitiated) {
                return (try? repo.unlock(masterPassword: password)) ?? mgr.unlockVault(with: password)
            }.value
            
            if success {
                self.isUnlocked = true
                self.unlockErrorMessage = ""
                self.masterPasswordInput = ""
                self.refreshState()
            } else {
                self.unlockErrorMessage = "Incorrect master password. Please try again."
            }
        }
    }
    
    public func unlockVaultAsync() async -> Bool {
        guard !masterPasswordInput.isEmpty else { return false }
        let password = masterPasswordInput
        let repo = self.repository
        let mgr = self.manager
        
        let success = await Task.detached(priority: .userInitiated) {
            return (try? repo.unlock(masterPassword: password)) ?? mgr.unlockVault(with: password)
        }.value
        
        if success {
            self.isUnlocked = true
            self.unlockErrorMessage = ""
            self.masterPasswordInput = ""
            self.refreshState()
        } else {
            self.unlockErrorMessage = "Incorrect master password. Please try again."
        }
        return success
    }
    
    public func lockVault() {
        repository.lock()
        isUnlocked = false
        masterPasswordInput = ""
        entries = []
    }
    
    public func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to unlock TTZip Password Vault") { success, _ in
                Task { @MainActor in
                    if success {
                        let ok = self.manager.unlockWithBiometrics()
                        if ok {
                            self.isUnlocked = true
                            self.unlockErrorMessage = ""
                            self.refreshState()
                        } else {
                            self.unlockErrorMessage = "Biometric authentication succeeded, but master password not found."
                        }
                    } else {
                        self.unlockErrorMessage = "Touch ID authentication failed."
                    }
                }
            }
        } else {
            unlockErrorMessage = "Touch ID is not supported or not enabled in System Settings."
        }
    }
    
    public func addEntry() {
        guard !newLabel.isEmpty, !newPassword.isEmpty else { return }
        let finalLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Password" : newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = PasswordVaultEntry(label: finalLabel, password: newPassword, category: finalCategory)
        
        try? repository.save(entry)
        refreshState()
        newLabel = ""
        newPassword = ""
        isAddModalPresented = false
    }
    
    public func deleteEntry(id: UUID) {
        try? repository.delete(id: id)
        refreshState()
    }
    
    public func resetVault() {
        guard !newMasterPasswordInput.isEmpty else { return }
        manager.resetMasterPassword(newMasterPassword: newMasterPasswordInput)
        isUnlocked = true
        isResetSheetPresented = false
        newMasterPasswordInput = ""
        refreshState()
    }
    
    public func recoverVault() {
        guard !oldMasterPasswordInput.isEmpty else { return }
        let ok = manager.recoverBackupVault(withOriginalMasterPassword: oldMasterPasswordInput)
        if ok {
            isUnlocked = true
            isRecoverSheetPresented = false
            oldMasterPasswordInput = ""
            recoverErrorMessage = ""
            refreshState()
        } else {
            recoverErrorMessage = "Failed to verify previous master password."
        }
    }
    
    // MARK: - Multi-Core Parallel Password Recovery
    @Published public var isRecoverySheetPresented: Bool = false
    @Published public var recoveryArchivePath: String = ""
    @Published public var customCandidatesInput: String = ""
    @Published public var isRecoveringPassword: Bool = false
    @Published public var recoveryResult: PasswordRecoveryResult? = nil
    @Published public var recoveryStatusMessage: String = ""
    
    public func runParallelPasswordRecovery(archivePath: String, customCandidates: [String] = []) async {
        guard !archivePath.isEmpty else { return }
        isRecoveringPassword = true
        recoveryResult = nil
        recoveryStatusMessage = "Analyzing archive encryption and launching multi-core workers..."
        
        let vaultCandidates = manager.candidatePasswordsForAutoUnlock()
        var allCandidates = vaultCandidates
        for c in customCandidates {
            let trimmed = c.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !allCandidates.contains(trimmed) {
                allCandidates.append(trimmed)
            }
        }
        
        if allCandidates.isEmpty {
            recoveryStatusMessage = "No password candidates available. Add words or save vault passwords."
            isRecoveringPassword = false
            return
        }
        
        let candidates = allCandidates
        let start = Date()
        
        // 1. Fast path: in-memory multi-core Rust recovery
        if let fastFound = PasswordRecoveryEngine.recoverFastInMemory(passwords: candidates, archivePath: archivePath) {
            let duration = max(0.001, Date().timeIntervalSince(start))
            let res = PasswordRecoveryResult(foundPassword: fastFound, totalAttempts: Int64(candidates.count), durationSeconds: duration)
            self.recoveryResult = res
            self.recoveryStatusMessage = "⚡️ Success! Found password: \(fastFound)"
            self.isRecoveringPassword = false
            return
        }
        
        // 2. Comprehensive parallel recovery engine
        let engine = PasswordRecoveryEngine()
        do {
            let res = try await engine.recoverPassword(archivePath: archivePath, dictionary: candidates)
            self.recoveryResult = res
            if let pwd = res.foundPassword {
                self.recoveryStatusMessage = "⚡️ Success! Found password: \(pwd)"
            } else {
                self.recoveryStatusMessage = "Recovery finished. Tested \(res.totalAttempts) candidates without match."
            }
        } catch {
            self.recoveryStatusMessage = "Recovery failed: \(error.localizedDescription)"
        }
        self.isRecoveringPassword = false
    }
    
    public func saveRecoveredPasswordToVault(label: String, password: String, category: String = "Recovered") {
        guard !password.isEmpty else { return }
        let entry = PasswordVaultEntry(label: label, password: password, category: category)
        try? repository.save(entry)
        refreshState()
    }
}
