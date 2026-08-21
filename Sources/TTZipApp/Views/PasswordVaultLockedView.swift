// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Subview displaying master password setup and unlock forms when vault is locked.
public struct PasswordVaultLockedView: View {
    @ObservedObject public var l10n: AppLocalizationState
    @ObservedObject public var viewModel: PasswordVaultViewModel
    @FocusState.Binding public var isMasterPasswordFocused: Bool
    
    public init(
        l10n: AppLocalizationState = .shared,
        viewModel: PasswordVaultViewModel,
        isMasterPasswordFocused: FocusState<Bool>.Binding
    ) {
        self.l10n = l10n
        self.viewModel = viewModel
        self._isMasterPasswordFocused = isMasterPasswordFocused
    }
    
    public var body: some View {
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
                            Text(l10n.t(L10n.Vault.unlockButton))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
