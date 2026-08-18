// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import LocalAuthentication

/// Keychain and password safe vault view.
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
                        Text(viewModel.isMasterPasswordSet ? "Keychain Vault Locked" : "Setup Master Password")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        
                        Text(viewModel.isMasterPasswordSet ? "Enter master password or use Touch ID to unlock" : "Create a master password. Stored passwords are encrypted with this credential.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    
                    VStack(spacing: 12) {
                        if !viewModel.isMasterPasswordSet {
                            TTSecureTextField("New Master Password", text: $viewModel.masterPasswordInput)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                                .frame(width: 320)
                            
                            TTSecureTextField("Confirm Master Password", text: $viewModel.confirmMasterPasswordInput)
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
                                Text("Create Master Password")
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
                            TTSecureTextField("Enter Master Password", text: $viewModel.masterPasswordInput)
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
                                        Text("Touch ID")
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
                                    Text("Unlock")
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
                                Button("Forgot master password? Reset vault") {
                                    viewModel.newMasterPasswordInput = ""
                                    viewModel.isResetSheetPresented = true
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                
                                if viewModel.hasBackupVault {
                                    Button("Restore vault backup") {
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
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("KEYCHAIN VAULT")
                                .font(.system(size: 9, weight: .bold, design: .serif))
                                .tracking(2)
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                            Text("Password Vault")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                        }
                        
                        Toggle(isOn: $viewModel.autoUnlockArchives) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                Text("Auto-Unlock Archives")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(TTZipTheme.bambooGreen)
                        .help("Auto-matches saved passwords when opening encrypted archives")
                        
                        Button(action: { viewModel.lockVault() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                Text("Lock Vault")
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
                                Text("Add Password (⌘N)")
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
                                Text("No Saved Passwords")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Click [Add Password] to save credentials")
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

/// Reset master password sheet.
struct PasswordVaultResetSheet: View {
    @ObservedObject var viewModel: PasswordVaultViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Reset Master Password")
                    .font(.system(size: 16, weight: .bold))
                Text("Resetting clears the active vault and configures a new master password. An archive backup will be created.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            TTSecureTextField("New Master Password", text: $viewModel.newMasterPasswordInput)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
                .frame(width: 280)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.isResetSheetPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Button("Confirm Reset") {
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

/// Recover vault backup sheet.
struct PasswordVaultRecoverSheet: View {
    @ObservedObject var viewModel: PasswordVaultViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Restore Vault Backup")
                    .font(.system(size: 16, weight: .bold))
                Text("Enter the historical master password used when this backup was created.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            TTSecureTextField("Historical Master Password", text: $viewModel.oldMasterPasswordInput)
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
                Button("Cancel") {
                    viewModel.isRecoverSheetPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Button("Verify & Restore") {
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
