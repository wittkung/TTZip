import SwiftUI
import TTZipCore
import LocalAuthentication

/// 现代高透社论美学 - 本地密码钥匙串安全宝库
public struct PasswordVaultView: View {
    @StateObject private var viewModel: PasswordVaultViewModel
    @FocusState private var isMasterPasswordFocused: Bool
    
    var onSelectPassword: ((String) -> Void)? = nil
    
    public init(viewModel: PasswordVaultViewModel = PasswordVaultViewModel(), onSelectPassword: ((String) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectPassword = onSelectPassword
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isUnlocked {
                // 1. 未解锁锁定状态：极简高透防护舱 (Crystal Safe Vault)
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(TTZipTheme.bambooGreen.opacity(0.12))
                            .frame(width: 84, height: 84)
                        
                        Circle()
                            .strokeBorder(TTZipTheme.bambooGreen.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 96, height: 96)
                        
                        Image(systemName: viewModel.isMasterPasswordSet ? "lock.shield.fill" : "key.radiowaves.forward.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                    
                    VStack(spacing: 6) {
                        Text(viewModel.isMasterPasswordSet ? "安全密码钥匙串已锁定" : "设置主解锁口令")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        
                        Text(viewModel.isMasterPasswordSet ? "请输入主口令或使用 Touch ID 指纹一键验证解锁" : "首次使用请创建主解密口令，解压密码将基于该口令全量加密存储")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    
                    VStack(spacing: 12) {
                        if !viewModel.isMasterPasswordSet {
                            // 首次开启：设置主口令 + 确认主口令
                            TTSecureTextField("设置新的主解锁口令 (请妥善保管)", text: $viewModel.masterPasswordInput)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                                .frame(width: 320)
                            
                            TTSecureTextField("再次输入以确认主口令", text: $viewModel.confirmMasterPasswordInput)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                                .frame(width: 320)
                            
                            if !viewModel.unlockErrorMessage.isEmpty {
                                Text(viewModel.unlockErrorMessage)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TTZipTheme.cinnabarRed)
                            }
                            
                            Button(action: { viewModel.setupFirstMasterPassword() }) {
                                Text("创建主解锁口令并开启密码库")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 320)
                                    .padding(.vertical, 9)
                                    .background(
                                        LinearGradient(
                                            colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.3), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(viewModel.masterPasswordInput.isEmpty || viewModel.confirmMasterPasswordInput.isEmpty)
                        } else {
                            // 已设置主口令：解锁视图
                            TTSecureTextField("输入主口令解锁密码库", text: $viewModel.masterPasswordInput)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                                .frame(width: 320)
                                .focused($isMasterPasswordFocused)
                            
                            if !viewModel.unlockErrorMessage.isEmpty {
                                Text(viewModel.unlockErrorMessage)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TTZipTheme.cinnabarRed)
                            }
                            
                            HStack(spacing: 10) {
                                Button(action: { viewModel.authenticateWithBiometrics() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "touchid")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Touch ID 解锁")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { viewModel.unlockVault() }) {
                                    Text("解锁密码库")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                                .keyboardShortcut(.return, modifiers: [])
                                .disabled(viewModel.masterPasswordInput.isEmpty)
                            }
                            
                            HStack(spacing: 16) {
                                Button("忘记主口令？重置密码库") {
                                    viewModel.newMasterPasswordInput = ""
                                    viewModel.isResetSheetPresented = true
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                
                                if viewModel.hasBackupVault {
                                    Button("找回历史密码库备份") {
                                        viewModel.oldMasterPasswordInput = ""
                                        viewModel.recoverErrorMessage = ""
                                        viewModel.isRecoverSheetPresented = true
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(36)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
                .padding(40)
                .onAppear {
                    isMasterPasswordFocused = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 2. 已解锁状态：密码库主控制列表
                VStack(alignment: .leading, spacing: 0) {
                    // Header 栏 - 顶部对齐高度 52pt
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("KEYCHAIN VAULT")
                                .font(.system(size: 9, weight: .bold, design: .serif))
                                .tracking(2)
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                            Text("钥匙串密码库")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                        }
                        
                        Toggle(isOn: $viewModel.autoUnlockArchives) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                Text("自动解密归档包")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(TTZipTheme.bambooGreen)
                        .help("解锁密码库后，打开加密压缩包时自动比对库中保存的解压口令")
                        
                        Button(action: { viewModel.lockVault() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                Text("锁定密码库")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.isAddModalPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("添加密码 (⌘N)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: TTZipTheme.bambooGreen.opacity(0.25), radius: 4, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("n", modifiers: [.command])
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    
                    // 统一置顶分割线 (金缮金强调线对齐)
                    Rectangle()
                        .fill(TTZipTheme.kintsugiGold)
                        .frame(height: 1.5)
                    
                    if viewModel.entries.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "key.radiowaves.forward")
                                .font(.system(size: 42, weight: .ultraLight))
                                .foregroundStyle(TTZipTheme.bambooGreen.opacity(0.4))
                            
                            VStack(spacing: 4) {
                                Text("密码库当前无数据")
                                    .font(.system(size: 13, weight: .bold))
                                Text("点击右上角 [添加密码] 保存常用解压口令")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 14)], spacing: 14) {
                                ForEach(viewModel.entries) { entry in
                                    PasswordVaultEntryRowView(
                                        entry: entry,
                                        isVisible: viewModel.visiblePasswordIDs.contains(entry.id),
                                        isCopied: viewModel.copiedID == entry.id,
                                        onToggleVisibility: {
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                if viewModel.visiblePasswordIDs.contains(entry.id) {
                                                    viewModel.visiblePasswordIDs.remove(entry.id)
                                                } else {
                                                    viewModel.visiblePasswordIDs.insert(entry.id)
                                                }
                                            }
                                        },
                                        onCopy: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(entry.password, forType: .string)
                                            PasswordVaultManager.shared.recordUsage(id: entry.id)
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                viewModel.copiedID = entry.id
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                withAnimation(.easeOut(duration: 0.15)) {
                                                    if viewModel.copiedID == entry.id { viewModel.copiedID = nil }
                                                }
                                            }
                                        },
                                        onDelete: {
                                            withAnimation {
                                                viewModel.deleteEntry(id: entry.id)
                                            }
                                        },
                                        onSelect: {
                                            PasswordVaultManager.shared.recordUsage(id: entry.id)
                                            onSelectPassword?(entry.password)
                                        }
                                    )
                                    .padding(14)
                                    .background(Color.primary.opacity(0.025))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                                    )
                                }
                            }
                            .padding(20)
                        }
                    }
                }
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
                .padding(.top, 38)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $viewModel.isAddModalPresented) {
            PasswordVaultAddModalSheet(isPresented: $viewModel.isAddModalPresented) { labelToUse, pwd, catToUse in
                PasswordVaultManager.shared.addEntry(label: labelToUse, password: pwd, category: catToUse)
                viewModel.refreshState()
            }
        }
        .sheet(isPresented: $viewModel.isResetSheetPresented) {
            PasswordVaultResetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isRecoverSheetPresented) {
            PasswordVaultRecoverSheet(viewModel: viewModel)
        }
        .onAppear {
            if !viewModel.isUnlocked {
                isMasterPasswordFocused = true
            }
            viewModel.refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: PasswordVaultManager.vaultDidChangeNotification)) { _ in
            viewModel.refreshState()
        }
    }
}

/// 重置主口令 Sheet
struct PasswordVaultResetSheet: View {
    @ObservedObject var viewModel: PasswordVaultViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("重置密码库主口令")
                    .font(.system(size: 16, weight: .bold))
                Text("重置将清空当前密码库并设置新主口令。历史条目将自动备份以供日后找回。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            TTSecureTextField("输入新的主解锁口令", text: $viewModel.newMasterPasswordInput)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
                .frame(width: 280)
            
            HStack(spacing: 12) {
                Button("取消") {
                    viewModel.isResetSheetPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Button("确认重置") {
                    viewModel.resetVault()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(TTZipTheme.cinnabarRed)
                .clipShape(Capsule())
                .disabled(viewModel.newMasterPasswordInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}

/// 找回历史备份 Sheet
struct PasswordVaultRecoverSheet: View {
    @ObservedObject var viewModel: PasswordVaultViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("找回历史密码库备份")
                    .font(.system(size: 16, weight: .bold))
                Text("请输入该备份创建时使用的主解锁口令进行还原解密。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            TTSecureTextField("输入历史主口令", text: $viewModel.oldMasterPasswordInput)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
                .frame(width: 280)
            
            if !viewModel.recoverErrorMessage.isEmpty {
                Text(viewModel.recoverErrorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TTZipTheme.cinnabarRed)
            }
            
            HStack(spacing: 12) {
                Button("取消") {
                    viewModel.isRecoverSheetPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Button("验证并恢复") {
                    viewModel.recoverVault()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(TTZipTheme.bambooGreen)
                .clipShape(Capsule())
                .disabled(viewModel.oldMasterPasswordInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
