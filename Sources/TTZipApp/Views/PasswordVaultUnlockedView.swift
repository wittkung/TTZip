// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

/// Subview displaying saved passwords grid, auto-unlock settings, and action toolbars when vault is unlocked.
public struct PasswordVaultUnlockedView: View {
    @ObservedObject public var l10n: AppLocalizationState
    @ObservedObject public var viewModel: PasswordVaultViewModel
    public var onSelectPassword: ((String) -> Void)?
    
    public init(
        l10n: AppLocalizationState = .shared,
        viewModel: PasswordVaultViewModel,
        onSelectPassword: ((String) -> Void)? = nil
    ) {
        self.l10n = l10n
        self.viewModel = viewModel
        self.onSelectPassword = onSelectPassword
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("KEYCHAIN VAULT")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text(l10n.t(L10n.Vault.title))
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
                
                Button(action: { viewModel.isRecoverySheetPresented = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text("Parallel Recovery")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Run multi-core parallel dictionary recovery on encrypted archives")
                
                Button(action: { viewModel.lockVault() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text(l10n.t(L10n.Vault.lockVault))
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
                        Text(l10n.t(L10n.Vault.addPassword) + " (⌘N)")
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
                        Text(l10n.t(L10n.Vault.emptyVault))
                            .font(.system(size: 13, weight: .bold))
                        Text(l10n.t(L10n.Vault.noPasswordsSavedPrompt))
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
