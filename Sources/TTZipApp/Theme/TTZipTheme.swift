import SwiftUI
import AppKit

/// ITTime 品牌家族设计系统 (ITTime Zen + WSJ Editorial Aesthetics)
///
/// 融合了原研哉 (Kenya Hara) 极简无印质感、华尔街日报 (WSJ Broadsheet Layout) 典雅报刊排版
/// 以及东方禅意色阶 (朱砂红 cinnabarRed / 竹翠绿 bambooGreen / 金缮金 kintsugiGold)
public enum TTZipTheme {
    // MARK: - 1. ITTime 东方禅意与 WSJ 色阶 (Zen & WSJ Broadsheet Palette)
    
    /// 琥珀金 (TTZip Archival Amber - #D97706) —— TTZip 专属品牌封存主色
    public static let archiveAmber = Color(red: 0.85, green: 0.47, blue: 0.15)
    /// 朱砂红 (ITTime Cinnabar Red - #D15947) —— 主强调/印章点睛
    public static let cinnabarRed = Color(red: 0.82, green: 0.35, blue: 0.28)
    /// 竹青色 (ITTime Bamboo Green) —— 休息/恢复主色，支持浅色/深色模式动态自适应切换
    /// 浅色模式 (Light Mode)：#789262 (RGB: 120, 146, 98)
    /// 深色模式 (Dark Mode)：#8FA876 (RGB: 143, 168, 118)
    public static let bambooGreen = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // 深色模式 (Dark Mode)：#8FA876 (RGB: 143, 168, 118)
            return NSColor(red: 143.0 / 255.0, green: 168.0 / 255.0, blue: 118.0 / 255.0, alpha: 1.0)
        } else {
            // 浅色模式 (Light Mode)：#789262 (RGB: 120, 146, 98)
            return NSColor(red: 120.0 / 255.0, green: 146.0 / 255.0, blue: 98.0 / 255.0, alpha: 1.0)
        }
    }))
    /// 金缮金 (ITTime Kintsugi Gold) —— 支持浅色/深色模式动态自适应切换
    /// 浅色模式 (Light Mode)：#D4AF37 (RGB: 212, 175, 55)
    /// 深色模式 (Dark Mode)：#E6C35C (RGB: 230, 195, 92)
    public static let kintsugiGold = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // 深色模式 (Dark Mode)：#E6C35C (RGB: 230, 195, 92)
            return NSColor(red: 230.0 / 255.0, green: 195.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0)
        } else {
            // 浅色模式 (Light Mode)：#D4AF37 (RGB: 212, 175, 55)
            return NSColor(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0, alpha: 1.0)
        }
    }))
    
    /// 宣纸白 (WSJ Paper White - #FBFBF9)
    public static let paperWhite = Color(red: 0.98, green: 0.98, blue: 0.97)
    /// 暖泥灰 (WSJ Porcelain Gray - #F2F2EF)
    public static let porcelainGray = Color(red: 0.95, green: 0.95, blue: 0.93)
    /// 松烟炭墨黑 (WSJ Ink Charcoal - #1C1C1E)
    public static let inkCharcoal = Color(red: 0.11, green: 0.11, blue: 0.12)
    
    // 自适应 Primary Accent (TTZip 全局统一主题色：竹翠绿)
    public static var accentColor: Color {
        bambooGreen
    }
    
    /// 卡片与容器背景色
    public static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.65)
    }
    
    /// 次要充盈背景色
    public static var subtleFill: Color {
        Color(nsColor: .labelColor).opacity(0.035)
    }
    
    /// 0.5pt 极细 WSJ Editorial Hairline 边框
    public static var hairlineBorder: Color {
        Color(nsColor: .separatorColor).opacity(0.35)
    }
    
    public static var adaptiveBorder: Color {
        hairlineBorder
    }
    
    // 语义化状态色彩
    public static let statusSuccess = bambooGreen
    public static let statusWarning = kintsugiGold
    public static let statusDanger = cinnabarRed
    public static let statusInfo = Color(red: 0.30, green: 0.55, blue: 0.75) // 靛蓝
    
    /// 竹翠绿渐变
    public static var bambooGradient: LinearGradient {
        LinearGradient(
            colors: [bambooGreen, bambooGreen.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 全局主强调渐变 (竹翠绿)
    public static var primaryGradient: LinearGradient {
        bambooGradient
    }

    // MARK: - 2. WSJ 社论衬线与 SF Pro 混合排版 (WSJ Editorial Typography Ramp)
    
    public enum Typography {
        /// WSJ 报头大标题 (WSJ Broadsheet Headline) - 26pt Serif Light 典雅书卷
        public static let wsjHeadline = Font.system(size: 26, weight: .light, design: .serif)
        /// WSJ 社论二级标题 (WSJ Section Title) - 18pt Serif Medium
        public static let wsjSubheadline = Font.system(size: 18, weight: .medium, design: .serif)
        /// 大标题 (Display Title) - 24pt Light
        public static let displayTitle = Font.system(size: 24, weight: .light, design: .default)
        /// 一级标题 (Title 1) - 18pt Light
        public static let title1 = Font.system(size: 18, weight: .light, design: .default)
        /// 二级标题 (Title 2) - 15pt Medium
        public static let title2 = Font.system(size: 15, weight: .medium, design: .default)
        /// 区域标题 (Section Header) - 13pt Medium
        public static let sectionHeader = Font.system(size: 13, weight: .medium, design: .default)
        /// 正文 (Body) - 13pt Regular
        public static let body = Font.system(size: 13, weight: .regular, design: .default)
        /// 强调正文 (Body Medium) - 13pt Medium
        public static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
        /// 呼应文本 (Callout) - 12pt Regular
        public static let callout = Font.system(size: 12, weight: .regular, design: .default)
        /// 辅助说明 (Subheadline) - 11pt Regular
        public static let subheadline = Font.system(size: 11, weight: .regular, design: .default)
        /// 标注与元数据 (Caption) - 10pt Regular
        public static let caption = Font.system(size: 10, weight: .regular, design: .default)
        /// 代码与路径 (Monospaced Caption) - 11pt Monospaced
        public static let codeCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    // MARK: - 3. WSJ 报刊网格与间距 (WSJ Editorial Grid Spacing)
    
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 36
    }

    // MARK: - 4. 简质圆角阶梯
    
    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 18
    }
}

// MARK: - 5. WSJ Editorial Paper Surface ViewModifier

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
