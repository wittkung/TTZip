import SwiftUI
import TTZipCore

/// ITTime 复刻 报刊风格侧边栏 (WSJ Editorial Sidebar)
public struct MacEditorialSidebar: View {
    @Binding public var activeTab: WorkspaceTab
    public let currentArchivePath: String?
    public var isCompact: Bool = false
    
    // 缓存芯片拓扑与日期字符串，避免重绘 loop 反复计算
    private let tuner = AppleSiliconTuner.shared
    private let formattedDate = Date().formatted(.dateTime.year().month(.wide).day())
    
    public init(activeTab: Binding<WorkspaceTab>, currentArchivePath: String?, isCompact: Bool = false) {
        self._activeTab = activeTab
        self.currentArchivePath = currentArchivePath
        self.isCompact = isCompact
    }
    
    public var body: some View {
        VStack(alignment: isCompact ? .center : .leading, spacing: 0) {
            // 报头 (Masthead)
            if !isCompact {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("THE")
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .tracking(2.5)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        HStack(spacing: 7) {
                            if let logoImg = AppLogoCache.sharedLogoImage {
                                Image(nsImage: logoImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                            }
                            Text("TTZIP")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .tracking(1.5)
                            Text("PRO")
                                .font(.system(size: 10, weight: .heavy, design: .serif))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(TTZipTheme.kintsugiGold.opacity(0.18))
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    
                    Rectangle()
                        .fill(TTZipTheme.kintsugiGold)
                        .frame(height: 1.5)
                }
                .padding(.top, 38)
                .padding(.bottom, 16)
            } else {
                VStack {
                    if let logoImg = AppLogoCache.sharedLogoImage {
                        Image(nsImage: logoImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 38)
                .padding(.bottom, 24)
            }
            
            // 导航项列表
            VStack(alignment: isCompact ? .center : .leading, spacing: 6) {
                if !isCompact {
                    Text("INDEX")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }
                
                SidebarItemView(title: "主页与解压", icon: "archivebox", tab: .home, activeTab: $activeTab, isCompact: isCompact)
                SidebarItemView(title: "新建压缩包", icon: "doc.badge.plus", tab: .compressWorkspace, activeTab: $activeTab, isCompact: isCompact)
                SidebarItemView(title: "预设参数", icon: "slider.horizontal.3", tab: .presets, activeTab: $activeTab, isCompact: isCompact)
                SidebarItemView(title: "性能测试", icon: "speedometer", tab: .benchmark, activeTab: $activeTab, isCompact: isCompact)
                SidebarItemView(title: "密码钥匙串", icon: "key.fill", tab: .vault, activeTab: $activeTab, isCompact: isCompact)
                SidebarItemView(title: "商业授权", icon: "checkmark.seal.fill", tab: .settings, activeTab: $activeTab, isCompact: isCompact)
            }
            
            if !isCompact, let path = currentArchivePath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPEN ARCHIVE")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    
                    Text((path as NSString).lastPathComponent)
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
            }
            
            Spacer()
            
            // 当不是极简模式时展示底部芯片硬件与存储拓扑
            if !isCompact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text(tuner.topology.chipName)
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                    }
                    Text("\(tuner.topology.totalCores) 核 CPU · \(String(format: "%.0f", tuner.topology.unifiedMemoryGB))GB 内存")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text("极速零拷贝加速")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                
                // 底部版权/日期区
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 0.5)
                        .padding(.bottom, 12)
                    
                    Text(formattedDate)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.primary.opacity(0.8))
                    Text("PRINTED IN macOS")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
    }
}

public struct SidebarItemView: View {
    public let title: String
    public let icon: String
    public let tab: WorkspaceTab
    @Binding public var activeTab: WorkspaceTab
    public var isCompact: Bool = false
    
    @State private var isHovered = false
    
    public init(title: String, icon: String, tab: WorkspaceTab, activeTab: Binding<WorkspaceTab>, isCompact: Bool = false) {
        self.title = title
        self.icon = icon
        self.tab = tab
        self._activeTab = activeTab
        self.isCompact = isCompact
    }
    
    public var body: some View {
        let isSelected = activeTab == tab
        
        Button(action: {
            activeTab = tab
        }) {
            if isCompact {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.primary.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.7))
                }
                .frame(width: 36, height: 36)
                .help(title)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .frame(width: 18)
                        .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.6))
                    
                    Text(title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular, design: .serif))
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? Color.primary.opacity(0.04) : (isHovered ? Color.primary.opacity(0.02) : Color.clear)
                )
                .overlay(alignment: .leading) {
                    if isSelected {
                        Rectangle()
                            .fill(TTZipTheme.bambooGreen)
                            .frame(width: 2.5)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .primary : .primary.opacity(0.7))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
