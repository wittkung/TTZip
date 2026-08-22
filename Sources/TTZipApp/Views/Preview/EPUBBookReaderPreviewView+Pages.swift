// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

public struct EPUBTypographyPopoverView: View {
    @Binding public var fontFamily: String
    @Binding public var fontSize: Int
    @Binding public var themeMode: String
    
    public init(fontFamily: Binding<String>, fontSize: Binding<Int>, themeMode: Binding<String>) {
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._themeMode = themeMode
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Text("Typography & Theme")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Font Family")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    fontChip("Serif", key: "serif")
                    fontChip("Kaiti", key: "kaiti")
                    fontChip("Sans-Serif", key: "sans")
                    fontChip("Fangsong", key: "fangsong")
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Font Size")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(fontSize) pt")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                
                HStack(spacing: 8) {
                    Button(action: { fontSize = max(fontSize - 1, 12) }) {
                        Text("A-")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 24)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: Binding(
                        get: { Double(fontSize) },
                        set: { fontSize = Int($0) }
                    ), in: 12...36, step: 1)
                    .tint(TTZipTheme.bambooGreen)
                    
                    Button(action: { fontSize = min(fontSize + 1, 36) }) {
                        Text("A+")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 24)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    themeOptionButton(name: "Light", key: "light", fill: Color.white, stroke: Color.gray.opacity(0.3))
                    themeOptionButton(name: "Sepia", key: "sepia", fill: Color(red: 0.97, green: 0.94, blue: 0.88), stroke: Color.gray.opacity(0.3))
                    themeOptionButton(name: "Dark", key: "dark", fill: Color(red: 0.12, green: 0.12, blue: 0.12), stroke: Color.gray.opacity(0.3))
                    
                    Button(action: { themeMode = "transparent" }) {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [TTZipTheme.bambooGreen, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(Circle().strokeBorder(themeMode == "transparent" ? TTZipTheme.bambooGreen : Color.clear, lineWidth: 2))
                            
                            Text("Glass")
                                .font(.system(size: 9, weight: themeMode == "transparent" ? .bold : .regular))
                                .foregroundStyle(themeMode == "transparent" ? TTZipTheme.bambooGreen : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 245)
    }
    
    private func fontChip(_ title: String, key: String) -> some View {
        Button(action: { fontFamily = key }) {
            Text(title)
                .font(.system(size: 10, weight: fontFamily == key ? .bold : .medium))
                .foregroundStyle(fontFamily == key ? TTZipTheme.bambooGreen : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(fontFamily == key ? TTZipTheme.bambooGreen.opacity(0.12) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(fontFamily == key ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func themeOptionButton(name: String, key: String, fill: Color, stroke: Color) -> some View {
        Button(action: { themeMode = key }) {
            VStack(spacing: 3) {
                Circle()
                    .fill(fill)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(themeMode == key ? TTZipTheme.bambooGreen : stroke, lineWidth: themeMode == key ? 2 : 1))
                
                Text(name)
                    .font(.system(size: 9, weight: themeMode == key ? .bold : .regular))
                    .foregroundStyle(themeMode == key ? TTZipTheme.bambooGreen : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
