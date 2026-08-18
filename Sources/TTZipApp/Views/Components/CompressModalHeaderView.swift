// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Editorial style compression modal header component.
public struct CompressModalHeaderView: View {
    @Binding public var selectedPresetID: UUID?
    public let onOpenGuide: () -> Void
    public let onClose: () -> Void
    
    public init(
        selectedPresetID: Binding<UUID?>,
        onOpenGuide: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._selectedPresetID = selectedPresetID
        self.onOpenGuide = onOpenGuide
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ARCHIVE WORKSPACE")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    
                    HStack(spacing: 8) {
                        Text("New Archive")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        
                        Button(action: onOpenGuide) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("📖 Format Guide")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(TTZipTheme.kintsugiGold.opacity(0.14))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Open algorithm and format guide")
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Picker("Preset", selection: $selectedPresetID) {
                        Text("Custom Preset").tag(UUID?.none)
                        ForEach(PresetManager.shared.presets) { preset in
                            Text("\(preset.name) (\(preset.splitVolumeDescription))").tag(UUID?.some(preset.id))
                        }
                    }
                    .frame(width: 170)
                    .controlSize(.small)
                    .tint(TTZipTheme.bambooGreen)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
        }
    }
}
