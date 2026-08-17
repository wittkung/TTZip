import Foundation

/// 全局临时目录集中清理管理器
public final class TempDirectoryCleanUpManager: Sendable {
    public static let shared = TempDirectoryCleanUpManager()
    
    private init() {}
    
    /// 清理项目创建的全部临时目录 (ttzip_epub_*, ttzip_preview_*, pwd_test_*)
    public func cleanupAllTemporaryDirectories() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        guard let items = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        for item in items {
            let lowerName = item.lastPathComponent.lowercased()
            if lowerName.hasPrefix("ttzip") ||
               lowerName.hasPrefix("pwd_test") ||
               lowerName.hasPrefix("tt_") ||
               lowerName.hasPrefix("measure_") ||
               lowerName.hasPrefix("dest_") ||
               lowerName.hasPrefix("joined_") ||
               lowerName.hasPrefix("warmup_") ||
               lowerName.hasPrefix("iter_") ||
               lowerName.hasPrefix("arc_") ||
               lowerName.hasPrefix("sample_") ||
               lowerName.hasPrefix("huge_") ||
               lowerName.hasPrefix("ditto_") ||
               lowerName.hasPrefix("7zz_") ||
               lowerName.hasPrefix("pigz_") ||
               lowerName.hasPrefix("libdeflate_") ||
               lowerName.hasPrefix("zstd_") ||
               lowerName.hasPrefix("bz2_") ||
               lowerName.hasPrefix("xz_") ||
               lowerName.hasPrefix("lz_") ||
               lowerName.hasPrefix("lz4_") ||
               lowerName.hasPrefix("br_") ||
               lowerName.hasPrefix("lrz_") ||
               lowerName.hasPrefix("inspect_") ||
               lowerName.hasPrefix("repair_") ||
               lowerName.contains("exhaustivedatasetcache") {
                try? fileManager.removeItem(at: item)
            }
        }
    }
}
