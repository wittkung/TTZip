// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Compression target configuration view.
public struct CompressTargetConfigSectionView: View {
    @Binding public var outputName: String
    @Binding public var targetDirectory: String
    @Binding public var selectedFormat: ArchiveCompressionFormat
    @Binding public var compressionLevel: ArchiveCompressionLevel
    public let onPickDirectory: () -> Void
    
    public init(
        outputName: Binding<String>,
        targetDirectory: Binding<String>,
        selectedFormat: Binding<ArchiveCompressionFormat>,
        compressionLevel: Binding<ArchiveCompressionLevel>,
        onPickDirectory: @escaping () -> Void
    ) {
        self._outputName = outputName
        self._targetDirectory = targetDirectory
        self._selectedFormat = selectedFormat
        self._compressionLevel = compressionLevel
        self.onPickDirectory = onPickDirectory
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Archive Target Configuration", systemImage: "gearshape.fill")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("Output Name")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 85, alignment: .trailing)
                    
                    TextField("Output Name", text: $outputName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                }
                
                HStack(spacing: 12) {
                    Text("Destination")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 85, alignment: .trailing)
                    
                    HStack(spacing: 6) {
                        TextField("Destination folder path", text: $targetDirectory)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                            )
                        
                        Button("Browse...") { onPickDirectory() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Text("Format")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 85, alignment: .trailing)
                
                HStack(spacing: 8) {
                    formatOptionTile(format: .sevenZip, name: "7-Zip", ext: ".7z (Recommended)")
                    formatOptionTile(format: .zip, name: "ZIP", ext: ".zip (Universal)")
                    formatOptionTile(format: .tarZst, name: "TAR.ZST", ext: ".zst (Fast)")
                    formatOptionTile(format: .tarGz, name: "TAR.GZ", ext: ".tar.gz (Linux)")
                }
            }
            
            HStack(spacing: 12) {
                Text("Level")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 85, alignment: .trailing)
                
                HStack(spacing: 6) {
                    levelOptionTile(level: .store, name: "Store (0x)")
                    levelOptionTile(level: .fast, name: "Fast (1x)")
                    levelOptionTile(level: .normal, name: "Standard (5x)")
                    levelOptionTile(level: .ultra, name: "Ultra (9x)")
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
    
    private func formatOptionTile(format: ArchiveCompressionFormat, name: String, ext: String) -> some View {
        let isSelected = selectedFormat == format
        return Button(action: { selectedFormat = format }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 11, weight: .bold))
                Text(ext).font(.system(size: 9.5)).foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
            .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func levelOptionTile(level: ArchiveCompressionLevel, name: String) -> some View {
        let isSelected = compressionLevel == level
        return Button(action: { compressionLevel = level }) {
            Text(name)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
