// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct PasswordVaultPopoverView: View {
    @Binding public var passwordInput: String
    @Binding public var errorMessage: String?
    @Binding public var showVaultPopover: Bool
    
    @State private var vaultMasterPasswordInput: String = ""
    @State private var masterPasswordError: Bool = false
    
    public init(passwordInput: Binding<String>, errorMessage: Binding<String?>, showVaultPopover: Binding<Bool>) {
        self._passwordInput = passwordInput
        self._errorMessage = errorMessage
        self._showVaultPopover = showVaultPopover
    }
    
    public var body: some View {
        let isMasterPasswordSet = PasswordVaultManager.shared.isMasterPasswordSet
        let isUnlocked = PasswordVaultManager.shared.isUnlocked
        let vaultEntries = PasswordVaultManager.shared.getEntries()
        
        VStack(spacing: 0) {
            if isMasterPasswordSet && !isUnlocked {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text("Unlock Password Vault")
                            .font(.system(size: 12, weight: .bold))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        
                        TTSecureTextField("Enter vault master password", text: $vaultMasterPasswordInput)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { unlockVault() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(masterPasswordError ? TTZipTheme.cinnabarRed : Color.primary.opacity(0.08), lineWidth: 0.8)
                    )
                    
                    if masterPasswordError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                            Text("Incorrect master password")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: unlockVault) {
                            Text("Unlock")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(vaultMasterPasswordInput.isEmpty ? Color.secondary.opacity(0.2) : TTZipTheme.bambooGreen)
                                .foregroundStyle(vaultMasterPasswordInput.isEmpty ? Color.secondary : Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(vaultMasterPasswordInput.isEmpty)
                    }
                }
                .padding(14)
            } else if !isMasterPasswordSet && vaultEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "key.slash.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No Saved Passwords")
                        .font(.system(size: 12, weight: .bold))
                    Text("Configure your master password and save passwords in the sidebar Vault.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text("Saved Passwords")
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    Rectangle()
                        .fill(TTZipTheme.kintsugiGold.opacity(0.4))
                        .frame(height: 0.8)
                        .padding(.top, 2)
                    
                    if vaultEntries.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.system(size: 20))
                                .foregroundStyle(.tertiary)
                            Text("No saved passwords")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(vaultEntries) { entry in
                                Button {
                                    passwordInput = entry.password
                                    errorMessage = nil
                                    showVaultPopover = false
                                } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(TTZipTheme.bambooGreen.opacity(0.12))
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "key.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(TTZipTheme.bambooGreen)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.label)
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(.primary)
                                            Text(entry.category)
                                                .font(.system(size: 9.5, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.02))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                }
            }
        }
        .frame(width: 280)
    }
    
    private func unlockVault() {
        guard !vaultMasterPasswordInput.isEmpty else { return }
        let success = PasswordVaultManager.shared.unlockVault(with: vaultMasterPasswordInput)
        if success {
            masterPasswordError = false
            vaultMasterPasswordInput = ""
        } else {
            masterPasswordError = true
        }
    }
}
