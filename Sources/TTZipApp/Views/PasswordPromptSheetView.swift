import SwiftUI
import TTZipCore

public struct PasswordPromptSheetView: View {
    let archivePath: String
    let onSubmitPassword: (String) async -> Bool
    let onCancel: () -> Void
    
    @State private var passwordInput: String = ""
    @State private var showPasswordMask: Bool = false // 默认关掉 SecureField 遮罩，全放开中文与拼音输入法
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isPasswordFieldFocused: Bool
    
    // 密码库交互 Popover 状态
    @State private var showVaultPopover: Bool = false
    @State private var vaultMasterPasswordInput: String = ""
    @State private var masterPasswordError: Bool = false
    
    @State private var vaultUpdateTrigger: Int = 0
    
    public init(
        archivePath: String,
        onSubmitPassword: @escaping (String) async -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.archivePath = archivePath
        self.onSubmitPassword = onSubmitPassword
        self.onCancel = onCancel
    }
    
    private var isVaultUnlocked: Bool {
        _ = vaultUpdateTrigger
        return PasswordVaultManager.shared.isUnlocked
    }
    
    private var isMasterPasswordSet: Bool {
        _ = vaultUpdateTrigger
        return PasswordVaultManager.shared.isMasterPasswordSet
    }
    
    private var vaultEntries: [PasswordVaultEntry] {
        _ = vaultUpdateTrigger
        return PasswordVaultManager.shared.getEntries()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("归档包已被密码加密")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.8)
                )
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭解密窗口 (Esc)")
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            // 中央主要内容区 - 呼吸感布局
            VStack(alignment: .leading, spacing: 18) {
                // 1. 解密口令说明与输入组件 Bento Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("解密凭据与口令")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .tracking(1.5)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        Spacer()
                        Text("请输入正确的解压口令以读取包内目录")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        // 口令输入框容器 (全放开中文与拼音输入法，绝不使用 SecureField 锁定输入法选词)
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            
                            TextField("输入解压密码 / 解密口令", text: $passwordInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .focused($isPasswordFieldFocused)
                                .onSubmit { submit() }
                            
                            Button {
                                showPasswordMask.toggle()
                            } label: {
                                Image(systemName: showPasswordMask ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("切换口令显示状态")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isPasswordFieldFocused ? TTZipTheme.bambooGreen : Color.primary.opacity(0.08), lineWidth: isPasswordFieldFocused ? 1.2 : 0.8)
                        )
                        
                        // 密码库 Popover 按钮
                        Button {
                            showVaultPopover.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "rectangle.stack.badge.person.crop.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                Text("密码库")
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showVaultPopover, arrowEdge: .bottom) {
                            vaultPopoverContent
                        }
                    }
                    
                    // 2. 密码库一键快捷尝试推荐 Chips (如果存在已保存密码)
                    if isVaultUnlocked && !vaultEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码库常用口令推荐 (单击一键尝试)：")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vaultEntries.prefix(5)) { entry in
                                        Button(action: {
                                            passwordInput = entry.password
                                            submit()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "key.fill")
                                                    .font(.system(size: 8.5))
                                                Text(entry.label)
                                                    .font(.system(size: 10.5, weight: .bold))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4.5)
                                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                                            .foregroundStyle(TTZipTheme.bambooGreen)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().strokeBorder(TTZipTheme.bambooGreen.opacity(0.25), lineWidth: 0.8)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .help("填充密码【\(entry.label)】并自动提交验证")
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(18)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
                
                // 错误提示区
                if let err = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TTZipTheme.cinnabarRed)
                        Text(err)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(TTZipTheme.cinnabarRed)
                    }
                    .padding(.horizontal, 6)
                }
            }
            .padding(22)
            
            // 底部平稳对称脚栏 (Foot Bar) - 彻底解决“头重脚轻”问题！
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
                
                HStack {
                    // 左侧安全保护提示
                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkmark.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        Text("AES-256 / ZipCrypto 硬件加速解密")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    // 右侧主要控制按钮
                    HStack(spacing: 12) {
                        Button("取消") {
                            onCancel()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7.5)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                        .disabled(isVerifying)
                        .keyboardShortcut(.escape, modifiers: [])
                        
                        Button {
                            submit()
                        } label: {
                            HStack(spacing: 6) {
                                if isVerifying {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("正在校验...")
                                        .font(.system(size: 12, weight: .bold))
                                } else {
                                    Text("确认解密 (↵)")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 7.5)
                            .background(
                                passwordInput.isEmpty || isVerifying ?
                                TTZipTheme.bambooGreen.opacity(0.35) : TTZipTheme.bambooGreen
                            )
                            .foregroundStyle(
                                passwordInput.isEmpty || isVerifying ?
                                Color.white.opacity(0.6) : Color.white
                            )
                            .clipShape(Capsule())
                            .shadow(color: passwordInput.isEmpty || isVerifying ? Color.clear : TTZipTheme.bambooGreen.opacity(0.35), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(passwordInput.isEmpty || isVerifying)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.015))
            }
        }
        .frame(width: 540)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [TTZipTheme.kintsugiGold.opacity(0.4), Color.primary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        .onReceive(NotificationCenter.default.publisher(for: PasswordVaultManager.vaultDidChangeNotification)) { _ in
            vaultUpdateTrigger += 1
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            isPasswordFieldFocused = true
        }
    }
    
    private func submit() {
        guard !passwordInput.isEmpty, !isVerifying else { return }
        isVerifying = true
        errorMessage = nil
        
        Task { @MainActor in
            let success = await onSubmitPassword(passwordInput)
            isVerifying = false
            if success {
                ArchiveAppMediator.shared.send(event: .passwordUnlocked(archivePath: archivePath, password: passwordInput))
            } else {
                errorMessage = "解密失败：口令不正确或文件已损坏"
            }
        }
    }
    
    @ViewBuilder
    private var vaultPopoverContent: some View {
        PasswordVaultView { selectedPwd in
            passwordInput = selectedPwd
            showVaultPopover = false
        }
        .frame(width: 400, height: 460)
    }
}
