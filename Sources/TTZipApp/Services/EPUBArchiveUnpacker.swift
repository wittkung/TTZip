// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public final class EPUBArchiveUnpacker {
    public static func unpackAndParseEPUB(at epubURL: URL) -> EPUBBookModel? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ttzip_epub_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        try? ArchiveExtractor().extractSync(archivePath: epubURL.path, destinationDir: tempDir.path)
        
        var opfURL: URL? = nil
        let containerURL = tempDir.appendingPathComponent("META-INF/container.xml")
        if let containerData = try? String(contentsOf: containerURL, encoding: .utf8),
           let fullPathMatch = containerData.range(of: "(?<=full-path=\")[^\"]+", options: .regularExpression) {
            let relativeOpf = String(containerData[fullPathMatch])
            opfURL = tempDir.appendingPathComponent(relativeOpf)
        }
        
        if opfURL == nil || !fileManager.fileExists(atPath: opfURL!.path) {
            if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                while let file = enumerator.nextObject() as? URL {
                    if file.pathExtension.lowercased() == "opf" {
                        opfURL = file
                        break
                    }
                }
            }
        }
        
        var manifest: [String: String] = [:]
        var spineItemRefs: [String] = []
        var ncxHref: String? = nil
        var bookTitle = epubURL.deletingPathExtension().lastPathComponent
        
        if let opfURL = opfURL, let opfContent = try? String(contentsOf: opfURL, encoding: .utf8) {
            if let titleRange = opfContent.range(of: "(?<=<dc:title[^>]*>)[^<]+", options: .regularExpression) {
                let extracted = String(opfContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extracted.isEmpty {
                    bookTitle = extracted
                }
            }
            
            let itemPattern = "<item\\s+[^>]*?id=[\"']([^\"']+)[\"'][^>]*?href=[\"']([^\"']+)[\"'][^>]*?>"
            if let regex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: opfContent, options: [], range: NSRange(location: 0, length: opfContent.utf16.count))
                for m in matches {
                    if m.numberOfRanges >= 3,
                       let idRange = Range(m.range(at: 1), in: opfContent),
                       let hrefRange = Range(m.range(at: 2), in: opfContent) {
                        let id = String(opfContent[idRange])
                        let href = String(opfContent[hrefRange])
                        manifest[id] = href
                        
                        if href.lowercased().hasSuffix(".ncx") {
                            ncxHref = href
                        }
                    }
                }
            }
            
            let itemrefPattern = "<itemref\\s+[^>]*?idref=[\"']([^\"']+)[\"'][^>]*?>"
            if let regex = try? NSRegularExpression(pattern: itemrefPattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: opfContent, options: [], range: NSRange(location: 0, length: opfContent.utf16.count))
                for m in matches {
                    if m.numberOfRanges >= 2,
                       let idrefRange = Range(m.range(at: 1), in: opfContent) {
                        spineItemRefs.append(String(opfContent[idrefRange]))
                    }
                }
            }
        }
        
        var ncxTitles: [String: String] = [:]
        if let opfURL = opfURL, let ncxHref = ncxHref {
            let ncxURL = opfURL.deletingLastPathComponent().appendingPathComponent(ncxHref)
            if let ncxContent = try? String(contentsOf: ncxURL, encoding: .utf8) {
                let navPointPattern = "<navLabel>\\s*<text>([^<]+)</text>\\s*</navLabel>\\s*<content\\s+src=[\"']([^\"']+)[\"']"
                if let regex = try? NSRegularExpression(pattern: navPointPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                    let matches = regex.matches(in: ncxContent, options: [], range: NSRange(location: 0, length: ncxContent.utf16.count))
                    for m in matches {
                        if m.numberOfRanges >= 3,
                           let textRange = Range(m.range(at: 1), in: ncxContent),
                           let srcRange = Range(m.range(at: 2), in: ncxContent) {
                            let text = String(ncxContent[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            let src = String(ncxContent[srcRange]).components(separatedBy: "#").first ?? ""
                            if !text.isEmpty && !src.isEmpty {
                                ncxTitles[src] = text
                            }
                        }
                    }
                }
            }
        }
        
        var orderedChapterURLs: [(url: URL, relHref: String)] = []
        if let opfURL = opfURL {
            let opfDir = opfURL.deletingLastPathComponent()
            for idref in spineItemRefs {
                if let relHref = manifest[idref] {
                    let fileURL = opfDir.appendingPathComponent(relHref)
                    if fileManager.fileExists(atPath: fileURL.path) {
                        orderedChapterURLs.append((fileURL, relHref))
                    }
                }
            }
        }
        
        if orderedChapterURLs.isEmpty {
            guard let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
                try? fileManager.removeItem(at: tempDir)
                return nil
            }
            var allURLs: [URL] = []
            while let itemURL = enumerator.nextObject() as? URL {
                let ext = itemURL.pathExtension.lowercased()
                if ext == "html" || ext == "xhtml" || ext == "htm" {
                    allURLs.append(itemURL)
                }
            }
            allURLs.sort { $0.path.compare($1.path, options: .numeric) == .orderedAscending }
            orderedChapterURLs = allURLs.map { ($0, $0.lastPathComponent) }
        }
        
        guard !orderedChapterURLs.isEmpty else {
            try? fileManager.removeItem(at: tempDir)
            return nil
        }
        
        var chapters: [EPUBChapterItem] = []
        for (idx, item) in orderedChapterURLs.enumerated() {
            var chapterTitle: String? = nil
            
            let relFileName = item.relHref.components(separatedBy: "/").last ?? item.relHref
            if let ncxTitle = ncxTitles[item.relHref] ?? ncxTitles[relFileName] {
                chapterTitle = ncxTitle
            }
            
            if chapterTitle == nil || chapterTitle!.isEmpty {
                if let html = try? String(contentsOf: item.url, encoding: .utf8) {
                    if let h1Range = html.range(of: "(?<=<h1[^>]*>)[^<]+", options: .regularExpression) {
                        let extracted = String(html[h1Range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extracted.isEmpty { chapterTitle = extracted }
                    }
                    if chapterTitle == nil, let h2Range = html.range(of: "(?<=<h2[^>]*>)[^<]+", options: .regularExpression) {
                        let extracted = String(html[h2Range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extracted.isEmpty { chapterTitle = extracted }
                    }
                    if chapterTitle == nil, let titleRange = html.range(of: "(?<=<title[^>]*>)[^<]+", options: .regularExpression) {
                        let extracted = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extracted.isEmpty && extracted != bookTitle { chapterTitle = extracted }
                    }
                }
            }
            
            let finalTitle = chapterTitle ?? item.url.deletingPathExtension().lastPathComponent
            let displayTitle = (finalTitle.hasPrefix("第") || finalTitle.contains("章") || finalTitle.lowercased().contains("chapter")) ? finalTitle : "Chapter \(idx + 1) · \(finalTitle)"
            chapters.append(EPUBChapterItem(id: "\(idx)", title: displayTitle, fileURL: item.url))
        }
        
        return EPUBBookModel(url: epubURL, title: bookTitle, chapters: chapters, extractDir: tempDir)
    }
    
    public static func cleanupTempDir(at extractDir: URL) {
        try? FileManager.default.removeItem(at: extractDir)
    }
}
