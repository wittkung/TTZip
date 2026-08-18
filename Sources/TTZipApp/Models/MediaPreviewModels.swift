// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI

public struct EBookMetadata {
    public let url: URL
    public let title: String
    public let formatName: String
    public let fileSizeDescription: String
    public let excerptText: String
    public let coverImage: NSImage?
    
    public init(url: URL, title: String, formatName: String, fileSizeDescription: String, excerptText: String, coverImage: NSImage?) {
        self.url = url
        self.title = title
        self.formatName = formatName
        self.fileSizeDescription = fileSizeDescription
        self.excerptText = excerptText
        self.coverImage = coverImage
    }
}

public struct EPUBChapterItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let fileURL: URL
    
    public init(id: String = UUID().uuidString, title: String, fileURL: URL) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
    }
}

public struct EPUBBookModel {
    public let url: URL
    public let title: String
    public let chapters: [EPUBChapterItem]
    public let extractDir: URL
    
    public init(url: URL, title: String, chapters: [EPUBChapterItem], extractDir: URL) {
        self.url = url
        self.title = title
        self.chapters = chapters
        self.extractDir = extractDir
    }
}

public enum MediaPreviewType {
    case image(NSImage)
    case video(URL)
    case audio(URL)
    case pdf(URL)
    case text(String)
    case docxDocument(NSAttributedString, URL)
    case epubBook(EPUBBookModel)
    case ebook(EBookMetadata)
    case quickLook(URL)
    case unsupported(String)
}
