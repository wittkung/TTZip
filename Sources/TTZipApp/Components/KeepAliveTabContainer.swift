// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Lazy-loaded and keep-alive persistent tab container.
///
/// Prevents redundant destruction and recreation of view hierarchy and ViewModels during tab switching.
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
