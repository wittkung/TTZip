import SwiftUI
import TTZipCore

/// 懒加载与 Keep-Alive 持久化 Tab 容器
/// 避免切换 Tab 时视图反复 Destruct / Init 重新创建 ViewModel 与 DOM 节点
public struct KeepAliveTabContainer<Content: View>: View {
    public let activeTab: WorkspaceTab
    public let content: (WorkspaceTab) -> Content
    
    @State private var visitedTabs: Set<WorkspaceTab> = []
    
    public init(
        activeTab: WorkspaceTab,
        @ViewBuilder content: @escaping (WorkspaceTab) -> Content
    ) {
        self.activeTab = activeTab
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            ForEach(WorkspaceTab.allCases) { tab in
                if visitedTabs.contains(tab) {
                    content(tab)
                        .opacity(activeTab == tab ? 1.0 : 0.0)
                        .allowsHitTesting(activeTab == tab)
                        .accessibilityHidden(activeTab != tab)
                }
            }
        }
        .onAppear {
            visitedTabs.insert(activeTab)
        }
        .onChange(of: activeTab) { _, newTab in
            if !visitedTabs.contains(newTab) {
                visitedTabs.insert(newTab)
            }
        }
    }
}
