// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct PasswordVaultAddModalSheet: View {
    @Binding public var isPresented: Bool
    @State private var newLabel: String = ""
    @State private var newCategory: String = "General"
    @State private var newPassword: String = ""
    
    public let onSave: (String, String, String) -> Void
    
    public init(isPresented: Binding<Bool>, onSave: @escaping (String, String, String) -> Void) {
        self._isPresented = isPresented
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Password to Secure Vault")
                .font(.system(size: 14, weight: .bold, design: .serif))
            
            VStack(alignment: .leading, spacing: 10) {
                TextField("Password description (e.g. Financial Data Backup)", text: $newLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(8)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                
                TextField("Category (e.g. Work / Personal / General)", text: $newCategory)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(8)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                
                HStack(spacing: 8) {
                    TextField("Password", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                    
                    Button("Generate") {
                        newPassword = PasswordVaultManager.shared.generateRandomPassword()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                
                Button("Save to Encrypted Vault") {
                    let pwd = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !pwd.isEmpty else { return }
                    let lbl = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    let labelToUse = lbl.isEmpty ? "Archive Password" : lbl
                    let catToUse = newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(labelToUse, pwd, catToUse)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(TTZipTheme.bambooGreen)
                .disabled(newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
