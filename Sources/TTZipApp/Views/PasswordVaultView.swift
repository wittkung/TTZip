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
    @ObservedObject private var l10n = AppLocalizationState.shared
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
                PasswordVaultLockedView(
                    l10n: l10n,
                    viewModel: viewModel,
                    isMasterPasswordFocused: $isMasterPasswordFocused
                )
                .onAppear {
                    isMasterPasswordFocused = true
                }
            } else {
                PasswordVaultUnlockedView(
                    l10n: l10n,
                    viewModel: viewModel,
                    onSelectPassword: onSelectPassword
                )
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
        .sheet(isPresented: $viewModel.isRecoverySheetPresented) {
            PasswordVaultRecoveryModalSheet(viewModel: viewModel)
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
