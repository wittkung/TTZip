import Foundation

@MainActor
public final class SpotlightSearchService: ObservableObject {
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [DiskItemInfo] = []
    @Published public var isSearching: Bool = false
    
    private var searchTask: Task<Void, Never>? = nil
    
    public init() {}
    
    public func performSearch(query: String, searchDirectory: String = NSHomeDirectory()) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            self.isSearching = false
            return
        }
        
        self.isSearching = true
        searchTask = Task.detached(priority: .userInitiated) {
            let rootURL = URL(fileURLWithPath: searchDirectory)
            var matchedItems: [DiskItemInfo] = []
            
            if let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled || matchedItems.count >= 50 { break }
                    if fileURL.lastPathComponent.localizedCaseInsensitiveContains(trimmed) {
                        matchedItems.append(DiskItemInfo(url: fileURL))
                    }
                }
            }
            
            if Task.isCancelled { return }
            await MainActor.run {
                self.searchResults = matchedItems
                self.isSearching = false
            }
        }
    }
}
