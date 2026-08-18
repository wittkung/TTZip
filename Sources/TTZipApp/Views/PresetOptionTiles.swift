// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct PresetFormatOptionTile: View {
    public let format: ArchiveCompressionFormat
    public let name: String
    public let ext: String
    public let desc: String
    @Binding public var activeFormat: ArchiveCompressionFormat
    
    public init(format: ArchiveCompressionFormat, name: String, ext: String, desc: String, activeFormat: Binding<ArchiveCompressionFormat>) {
        self.format = format
        self.name = name
        self.ext = ext
        self.desc = desc
        self._activeFormat = activeFormat
    }
    
    public var body: some View {
        let isSelected = activeFormat == format
        Button(action: { activeFormat = format }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                    Spacer()
                    Text(ext)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(desc)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

public struct PresetLevelOptionTile: View {
    public let level: ArchiveCompressionLevel
    public let name: String
    public let desc: String
    @Binding public var activeLevel: ArchiveCompressionLevel
    
    public init(level: ArchiveCompressionLevel, name: String, desc: String, activeLevel: Binding<ArchiveCompressionLevel>) {
        self.level = level
        self.name = name
        self.desc = desc
        self._activeLevel = activeLevel
    }
    
    public var body: some View {
        let isSelected = activeLevel == level
        Button(action: { activeLevel = level }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
