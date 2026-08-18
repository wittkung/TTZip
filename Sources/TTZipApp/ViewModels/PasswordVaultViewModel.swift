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
    
    @Injected public var repository: KeychainPasswordRepository
    @Injected public var manager: PasswordVaultManager
    
    public init(
        repository: KeychainPasswordRepository = KeychainPasswordRepository.shared,
        manager: PasswordVaultManager = .shared
    ) {
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
        let success = (try? repository.unlock(masterPassword: masterPasswordInput)) ?? manager.unlockVault(with: masterPasswordInput)
        if success {
            isUnlocked = true
            unlockErrorMessage = ""
            masterPasswordInput = ""
            refreshState()
        } else {
            unlockErrorMessage = "Incorrect master password. Please try again."
        }
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
}
