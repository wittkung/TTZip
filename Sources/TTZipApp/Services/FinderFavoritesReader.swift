import Foundation
import AppKit

public final class FinderFavoritesReader {
    public static func fetchFavorites() -> [FinderFavoriteItem] {
        var results: [FinderFavoriteItem] = []
        let home = NSHomeDirectory()
        
        let standardDefaults: [(String, String, String)] = [
            ("下载", (home as NSString).appendingPathComponent("Downloads"), "arrow.down.circle.fill"),
            ("文稿", (home as NSString).appendingPathComponent("Documents"), "doc.text.fill"),
            ("桌面", (home as NSString).appendingPathComponent("Desktop"), "desktopcomputer"),
            ("个人主页", home, "house.fill"),
            ("图片", (home as NSString).appendingPathComponent("Pictures"), "photo.fill"),
            ("影片", (home as NSString).appendingPathComponent("Movies"), "film.fill"),
            ("音乐", (home as NSString).appendingPathComponent("Music"), "music.note")
        ]
        
        for (name, path, icon) in standardDefaults {
            if FileManager.default.fileExists(atPath: path) {
                results.append(FinderFavoriteItem(name: name, path: path, systemImage: icon))
            }
        }
        
        // Add mounted volumes (e.g. external hard drives, USBs)
        if let mountedVolumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsInternalKey, .volumeLocalizedNameKey], options: .skipHiddenVolumes) {
            for volumeURL in mountedVolumes {
                // Skip root volume and System Data volume
                if volumeURL.path == "/" || volumeURL.path == "/System/Volumes/Data" {
                    continue
                }
                
                let isInternal = (try? volumeURL.resourceValues(forKeys: [.volumeIsInternalKey]).volumeIsInternal) ?? true
                let name = (try? volumeURL.resourceValues(forKeys: [.volumeLocalizedNameKey]).volumeLocalizedName) ?? volumeURL.lastPathComponent
                
                let icon = isInternal ? "internaldrive.fill" : "externaldrive.fill"
                results.append(FinderFavoriteItem(name: name, path: volumeURL.path, systemImage: icon))
            }
        }
        
        return results
    }
}
