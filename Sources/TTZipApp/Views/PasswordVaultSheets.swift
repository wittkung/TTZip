// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

/// Reset master password sheet.
public struct PasswordVaultResetSheet: View {
    @ObservedObject public var viewModel: PasswordVaultViewModel
    
    public init(viewModel: PasswordVaultViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
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
public struct PasswordVaultRecoverSheet: View {
    @ObservedObject public var viewModel: PasswordVaultViewModel
    
    public init(viewModel: PasswordVaultViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
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

/// Multi-core parallel archive password recovery sheet.
public struct PasswordVaultRecoveryModalSheet: View {
    @ObservedObject public var viewModel: PasswordVaultViewModel
    @State private var customDictionaryText: String = ""
    
    public init(viewModel: PasswordVaultViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parallel Multi-Core Password Recovery")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Text("Powered by native Rust Rayon & SIMD multi-threaded dictionary exploration")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Target Encrypted Archive")
                    .font(.system(size: 11, weight: .semibold))
                
                HStack(spacing: 8) {
                    TextField("Select archive (.zip, .7z, etc.)", text: $viewModel.recoveryArchivePath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                    
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.recoveryArchivePath = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Additional Candidate Words (comma or newline separated)")
                    .font(.system(size: 11, weight: .semibold))
                
                TextEditor(text: $customDictionaryText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
            }
            
            if !viewModel.recoveryStatusMessage.isEmpty {
                HStack(spacing: 8) {
                    if viewModel.isRecoveringPassword {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(viewModel.recoveryStatusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.recoveryResult?.foundPassword != nil ? TTZipTheme.bambooGreen : .primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
                if let found = viewModel.recoveryResult?.foundPassword {
                    Button("Save to Vault") {
                        let stem = (viewModel.recoveryArchivePath as NSString).lastPathComponent
                        viewModel.saveRecoveredPasswordToVault(label: "Recovered: \(stem)", password: found)
                        viewModel.isRecoverySheetPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TTZipTheme.kintsugiGold)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("Close") {
                    viewModel.isRecoverySheetPresented = false
                }
                .buttonStyle(.plain)
                
                Button(viewModel.isRecoveringPassword ? "Exploring..." : "Start Recovery") {
                    let words = customDictionaryText
                        .components(separatedBy: CharacterSet(charactersIn: ",\n\r\t "))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    Task {
                        await viewModel.runParallelPasswordRecovery(archivePath: viewModel.recoveryArchivePath, customCandidates: words)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TTZipTheme.bambooGreen)
                .disabled(viewModel.recoveryArchivePath.isEmpty || viewModel.isRecoveringPassword)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
