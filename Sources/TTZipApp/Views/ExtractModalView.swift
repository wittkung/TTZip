// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

@MainActor
private final class ExtractModalEventObserver: ObservableObject, ArchiveEventObserverProtocol {
    @Published var vaultUpdateTrigger: Int = 0
    
    init() {
        ArchiveEventCenter.shared.addObserver(self)
    }
    
    deinit {
        ArchiveEventCenter.shared.removeObserver(self)
    }
    
    nonisolated func onArchiveEvent(_ event: ArchiveEvent) {
        if case .passwordVaultUnlocked = event {
            Task { @MainActor in
                self.vaultUpdateTrigger += 1
            }
        }
    }
}

public struct ExtractModalView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    public let archivePath: String
    @Binding public var isPresented: Bool
    
    @State private var destinationDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "/tmp"
    @State private var autoOpenFolder = true
    @State private var password = ""
    @State private var isExtracting = false
    @State private var statusMessage = ""
    @StateObject private var eventObserver = ExtractModalEventObserver()
    
    public init(archivePath: String, isPresented: Binding<Bool>) {
        self.archivePath = archivePath
        self._isPresented = isPresented
    }
    
    private var vaultEntries: [PasswordVaultEntry] {
        _ = eventObserver.vaultUpdateTrigger
        return PasswordVaultManager.shared.getEntries()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text(l10n.t(L10n.Extract.title))
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t(L10n.Extract.destination))
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .tracking(1)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        HStack(spacing: 8) {
                            TextField(l10n.t(L10n.Extract.destination), text: $destinationDir)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                                 )
                            
                            Button(l10n.t(L10n.Common.chooseFolder) + "...") {
                                pickDirectory()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t(L10n.Extract.passwordPrompt))
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .tracking(1)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        HStack(spacing: 8) {
                            TTSecureTextField(l10n.t(L10n.Extract.enterPasswordPlaceholder), text: $password)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                                )
                            
                            Menu {
                                ForEach(vaultEntries) { entry in
                                    Button("\(entry.label) (\(entry.category))") {
                                        password = entry.password
                                        PasswordVaultManager.shared.recordUsage(id: entry.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 10))
                                    Text(l10n.t(L10n.Vault.title))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(TTZipTheme.bambooGreen.opacity(0.12))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                                .clipShape(Capsule())
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    
                    Toggle(l10n.t(L10n.Extract.autoOpenFolder), isOn: $autoOpenFolder)
                        .font(.system(size: 12, weight: .medium))
                        .toggleStyle(.checkbox)
                }
                .padding(16)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button(l10n.t(L10n.Common.cancel)) { isPresented = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                    
                    Button(action: startExtraction) {
                        HStack(spacing: 6) {
                            if isExtracting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isExtracting ? l10n.t(L10n.Common.processing) : l10n.t(L10n.Extract.action))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(isExtracting ? Color.secondary.opacity(0.2) : TTZipTheme.bambooGreen)
                        .foregroundStyle(isExtracting ? Color.secondary : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isExtracting)
                }
            }
            .padding(20)
        }
        .frame(width: 520)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func pickDirectory() {
        if let path = SystemDialogHelper.pickDirectory(prompt: l10n.t(L10n.Common.selectDestination), defaultPath: destinationDir) {
            destinationDir = path
        }
    }
    
    private func startExtraction() {
        let valCtx = ArchiveValidationContext.forExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password.isEmpty ? nil : password
        )
        let valResult = (try? ArchiveValidationPipeline.buildDefaultExtractPipeline().validate(context: valCtx)) ?? .success
        if case .failure(let err) = valResult {
            self.statusMessage = err.localizedDescription
            return
        }
        
        isExtracting = true
        statusMessage = "Extracting archive files..."
        ArchiveAppMediator.shared.send(event: .requestExtraction(archivePath: archivePath, destinationPath: destinationDir))
        
        Task {
            do {
                let cmdResult = try await TTZipEngineFacade.shared.extractWithCommand(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: password.isEmpty ? nil : password,
                    engineFacade: SecurityProtectionProxy.shared
                )
                await MainActor.run {
                    self.statusMessage = String(format: "✅ Extracted! (%.2fs)", cmdResult.executionDuration)
                    self.isExtracting = false
                    
                    if self.autoOpenFolder {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: self.destinationDir)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isPresented = false
                    }
                }
            } catch {
                ArchiveAppMediator.shared.send(event: .extractionFailed(archivePath: archivePath, error: error.localizedDescription))
                await MainActor.run {
                    self.statusMessage = "Extraction failed: \(error.localizedDescription)"
                    self.isExtracting = false
                }
            }
        }
    }
}
