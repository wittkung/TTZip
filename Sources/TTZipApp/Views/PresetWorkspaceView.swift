// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Preset workspace central configuration view.
public struct PresetWorkspaceView: View {
    @StateObject private var viewModel: PresetWorkspaceViewModel
    
    public init(viewModel: PresetWorkspaceViewModel = PresetWorkspaceViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            PresetMasterListView(
                presets: viewModel.presets,
                selectedPresetID: $viewModel.selectedPresetID,
                onSelectPreset: { preset in viewModel.loadPresetIntoEditor(preset) },
                onCreateNewPreset: { viewModel.createNewPreset() },
                onDuplicatePreset: { preset in viewModel.duplicatePreset(id: preset.id) },
                onResetToDefaults: { viewModel.resetToDefaults() }
            )
            
            if let _ = viewModel.presets.first(where: { $0.id == viewModel.selectedPresetID }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PRO CONFIGURATION")
                                .font(.system(size: 9, weight: .bold, design: .serif))
                                .tracking(2)
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                            Text("Edit: \(viewModel.editorName)")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: { viewModel.undoDraft() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                    Text("Undo (⌘Z)")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(viewModel.canUndoDraft ? TTZipTheme.kintsugiGold : Color.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TTZipTheme.kintsugiGold.opacity(viewModel.canUndoDraft ? 0.12 : 0.05))
                                .clipShape(Capsule())
                            }
                            .disabled(!viewModel.canUndoDraft)
                            .buttonStyle(.plain)
                            
                            Button(action: { viewModel.redoDraft() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.forward.circle")
                                    Text("Redo (⇧⌘Z)")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(viewModel.canRedoDraft ? TTZipTheme.kintsugiGold : Color.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TTZipTheme.kintsugiGold.opacity(viewModel.canRedoDraft ? 0.12 : 0.05))
                                .clipShape(Capsule())
                            }
                            .disabled(!viewModel.canRedoDraft)
                            .buttonStyle(.plain)
                            
                            Button(action: { viewModel.discardDraft() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle")
                                    Text("Discard")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TTZipTheme.cinnabarRed.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .frame(height: 52)
                    
                    Rectangle()
                        .fill(TTZipTheme.kintsugiGold)
                        .frame(height: 1.5)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Preset Name")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TextField("Enter preset name", text: $viewModel.editorName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            
                            PresetEditorCardView(
                                editorFormat: $viewModel.editorFormat,
                                editorLevel: $viewModel.editorLevel,
                                editorSplitVolumeOption: $viewModel.editorSplitVolumeOption,
                                editorSkipMacJunk: $viewModel.editorSkipMacJunk,
                                editorSkipGitDirectory: $viewModel.editorSkipGitDirectory
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Default Password (Optional)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TTSecureTextField("Leave empty for no default password", text: $viewModel.editorDefaultPassword)
                                    .font(.system(size: 12.5))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                        .padding(16)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 10) {
                        Button(action: { viewModel.deleteSelectedPreset() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text("Delete")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TTZipTheme.cinnabarRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TTZipTheme.cinnabarRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.duplicateSelectedPreset() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Duplicate")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TTZipTheme.kintsugiGold.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                                .transition(.opacity)
                        }
                        
                        Button(action: { viewModel.saveActivePreset() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Save Configuration")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(TTZipTheme.bambooGradient)
                            .clipShape(Capsule())
                            .shadow(color: TTZipTheme.bambooGreen.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.02))
                }
                .background(Color.primary.opacity(0.015))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
            }
        }
        .padding(16)
    }
}
