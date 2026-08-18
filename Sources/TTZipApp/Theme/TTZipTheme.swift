// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit

/// Unified theme design system for TTZip combining Zen minimalism and WSJ editorial typography.
public enum TTZipTheme {
    // MARK: - 1. Color Palette
    
    /// Archival Amber (#D97706) — Brand identity accent.
    public static let archiveAmber = Color(red: 0.85, green: 0.47, blue: 0.15)
    /// Cinnabar Red (#D15947) — Primary emphasis and stamp highlight.
    public static let cinnabarRed = Color(red: 0.82, green: 0.35, blue: 0.28)
    /// Bamboo Green — Dynamic adaptive accent.
    public static let bambooGreen = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(red: 143.0 / 255.0, green: 168.0 / 255.0, blue: 118.0 / 255.0, alpha: 1.0)
        } else {
            return NSColor(red: 120.0 / 255.0, green: 146.0 / 255.0, blue: 98.0 / 255.0, alpha: 1.0)
        }
    }))
    /// Kintsugi Gold — Dynamic adaptive secondary accent.
    public static let kintsugiGold = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(red: 230.0 / 255.0, green: 195.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0)
        } else {
            return NSColor(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0, alpha: 1.0)
        }
    }))
    
    /// Paper White (#FBFBF9).
    public static let paperWhite = Color(red: 0.98, green: 0.98, blue: 0.97)
    /// Porcelain Gray (#F2F2EF).
    public static let porcelainGray = Color(red: 0.95, green: 0.95, blue: 0.93)
    /// Ink Charcoal (#1C1C1E).
    public static let inkCharcoal = Color(red: 0.11, green: 0.11, blue: 0.12)
    
    /// Primary Accent Color.
    public static var accentColor: Color {
        bambooGreen
    }
    
    /// Card and container background.
    public static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.65)
    }
    
    /// Subtle fill.
    public static var subtleFill: Color {
        Color(nsColor: .labelColor).opacity(0.035)
    }
    
    /// Hairline border (0.5pt).
    public static var hairlineBorder: Color {
        Color(nsColor: .separatorColor).opacity(0.35)
    }
    
    public static var adaptiveBorder: Color {
        hairlineBorder
    }
    
    // Semantic status colors
    public static let statusSuccess = bambooGreen
    public static let statusWarning = kintsugiGold
    public static let statusDanger = cinnabarRed
    public static let statusInfo = Color(red: 0.30, green: 0.55, blue: 0.75)
    
    public static var bambooGradient: LinearGradient {
        LinearGradient(
            colors: [bambooGreen, bambooGreen.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public static var primaryGradient: LinearGradient {
        bambooGradient
    }

    // MARK: - 2. Typography Ramp
    
    public enum Typography {
        public static let wsjHeadline = Font.system(size: 26, weight: .light, design: .serif)
        public static let wsjSubheadline = Font.system(size: 18, weight: .medium, design: .serif)
        public static let displayTitle = Font.system(size: 24, weight: .light, design: .default)
        public static let title1 = Font.system(size: 18, weight: .light, design: .default)
        public static let title2 = Font.system(size: 15, weight: .medium, design: .default)
        public static let sectionHeader = Font.system(size: 13, weight: .medium, design: .default)
        public static let body = Font.system(size: 13, weight: .regular, design: .default)
        public static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
        public static let callout = Font.system(size: 12, weight: .regular, design: .default)
        public static let subheadline = Font.system(size: 11, weight: .regular, design: .default)
        public static let caption = Font.system(size: 10, weight: .regular, design: .default)
        public static let codeCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    // MARK: - 3. Spacing Grid
    
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 36
    }

    // MARK: - 4. Corner Radius Ramp
    
    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 18
    }
}

// MARK: - 5. Surface ViewModifier

public struct MUJIPaperCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        cornerRadius: CGFloat = TTZipTheme.Radius.lg,
        padding: CGFloat = TTZipTheme.Spacing.md
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.primary.opacity(0.04) : Color.white.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.08)
                                    : Color.black.opacity(0.05),
                                lineWidth: 0.5
                            )
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.03),
                radius: colorScheme == .dark ? 4 : 6,
                x: 0,
                y: 2
            )
    }
}

public extension View {
    func ttzipLiquidGlass(cornerRadius: CGFloat = TTZipTheme.Radius.lg, padding: CGFloat = TTZipTheme.Spacing.md) -> some View {
        self.modifier(MUJIPaperCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    func ttzipSurface(cornerRadius: CGFloat = TTZipTheme.Radius.lg, padding: CGFloat = TTZipTheme.Spacing.md) -> some View {
        self.modifier(MUJIPaperCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    func ttzipCard(padding: CGFloat = TTZipTheme.Spacing.md, cornerRadius: CGFloat = TTZipTheme.Radius.lg) -> some View {
        self.modifier(MUJIPaperCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
