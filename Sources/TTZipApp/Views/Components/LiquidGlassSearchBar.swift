import SwiftUI
import TTZipCore

/// Liquid Glass 玻璃拟态全局 Spotlight 搜索组件
public struct LiquidGlassSearchBar: View {
    @Binding public var searchQuery: String
    @ObservedObject public var searchService: SpotlightSearchService
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false
    
    public init(searchQuery: Binding<String>, searchService: SpotlightSearchService) {
        self._searchQuery = searchQuery
        self.searchService = searchService
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFocused ? TTZipTheme.bambooGreen : .secondary)
            
            TextField("搜索本地归档与解压项目...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .focused($isFocused)
                .onChange(of: searchQuery) { _, newValue in
                    searchService.performSearch(query: newValue)
                }
            
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isFocused ? Color.primary.opacity(0.05) : (isHovered ? Color.primary.opacity(0.03) : Color.primary.opacity(0.02)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isFocused ? TTZipTheme.bambooGreen.opacity(0.6) : (isHovered ? TTZipTheme.hairlineBorder.opacity(0.8) : TTZipTheme.hairlineBorder), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
