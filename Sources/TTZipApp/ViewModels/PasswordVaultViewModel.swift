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
    @Published public var newCategory: String = "通用"
    @Published public var copiedID: UUID? = nil
    @Published public var visiblePasswordIDs: Set<UUID> = []
    
    // MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】使用 @Injected 解耦 Repository 与 VaultManager
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
            unlockErrorMessage = "两次输入的主口令不一致，请重新输入"
            return
        }
        guard !masterPasswordInput.isEmpty else {
            unlockErrorMessage = "主口令不能为空"
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
            unlockErrorMessage = "解锁口令错误，请重试"
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
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "使用 Touch ID 解锁 TTZip 钥匙串密码库") { success, _ in
                Task { @MainActor in
                    if success {
                        let ok = self.manager.unlockWithBiometrics()
                        if ok {
                            self.isUnlocked = true
                            self.unlockErrorMessage = ""
                            self.refreshState()
                        } else {
                            self.unlockErrorMessage = "指纹验证通过，但未找到预存的解锁主口令，请手动输入口令"
                        }
                    } else {
                        self.unlockErrorMessage = "Touch ID 指纹验证失败"
                    }
                }
            }
        } else {
            unlockErrorMessage = "当前设备不支持 Touch ID 或未在系统设置中启用"
        }
    }
    
    public func addEntry() {
        guard !newLabel.isEmpty, !newPassword.isEmpty else { return }
        let finalLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "解压口令" : newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "通用" : newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
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
            recoverErrorMessage = "验证历史主口令失败，恢复解密中断"
        }
    }
}
