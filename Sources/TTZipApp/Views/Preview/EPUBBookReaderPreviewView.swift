// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import WebKit
import QuickLookUI
import TTZipCore

public struct EBookReaderPreviewView: View {
    public let metadata: EBookMetadata
    
    public init(metadata: EBookMetadata) {
        self.metadata = metadata
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [TTZipTheme.bambooGreen.opacity(0.85), TTZipTheme.bambooGreen.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 2, y: 4)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                        
                        Text(metadata.formatName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 80, height: 110)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(metadata.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(metadata.formatName, systemImage: "book.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        
                        Text(metadata.fileSizeDescription)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(metadata.excerptText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            NSWorkspace.shared.open(metadata.url)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.forward.app.fill")
                                Text("Open in Reader")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([metadata.url])
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                Text("Reveal in Finder")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 0.8))
            .padding(12)
            
            QuickLookNSView(url: metadata.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding([.horizontal, .bottom], 12)
        }
    }
}

public struct InteractiveEPUBReaderView: View {
    public let bookModel: EPUBBookModel
    
    @State private var selectedChapterIndex: Int = 0
    @AppStorage("TTZip_EPUB_FontSize") private var fontSize: Int = 17
    @AppStorage("TTZip_EPUB_FontFamily") private var fontFamily: String = "serif"
    @AppStorage("TTZip_EPUB_ThemeMode") private var themeMode: String = "light"
    @State private var showTypographyPopover: Bool = false
    
    public init(bookModel: EPUBBookModel) {
        self.bookModel = bookModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(Array(bookModel.chapters.enumerated()), id: \.offset) { idx, chapter in
                        Button(action: { selectedChapterIndex = idx }) {
                            HStack {
                                Text(chapter.title)
                                    .lineLimit(1)
                                if selectedChapterIndex == idx {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 5) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            
                            Text(bookModel.chapters.indices.contains(selectedChapterIndex) ? bookModel.chapters[selectedChapterIndex].title : "Chapter")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                        
                        HStack(spacing: 3) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 4)
                
                Button(action: { showTypographyPopover.toggle() }) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            Image(systemName: "textformat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            Text("Typography")
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                        
                        HStack(spacing: 2) {
                            Image(systemName: "textformat")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .help("Customize font, size, and theme")
                .popover(isPresented: $showTypographyPopover, arrowEdge: .bottom) {
                    EPUBTypographyPopoverView(
                        fontFamily: $fontFamily,
                        fontSize: $fontSize,
                        themeMode: $themeMode
                    )
                }
                Spacer(minLength: 4)
                
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        Button(action: {
                            if selectedChapterIndex > 0 { selectedChapterIndex -= 1 }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChapterIndex <= 0)
                        .opacity(selectedChapterIndex <= 0 ? 0.4 : 1.0)
                        
                        Text("\(selectedChapterIndex + 1)/\(bookModel.chapters.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Button(action: {
                            if selectedChapterIndex < bookModel.chapters.count - 1 { selectedChapterIndex += 1 }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChapterIndex >= bookModel.chapters.count - 1)
                        .opacity(selectedChapterIndex >= bookModel.chapters.count - 1 ? 0.4 : 1.0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                    
                    HStack(spacing: 6) {
                        Button(action: {
                            if selectedChapterIndex > 0 { selectedChapterIndex -= 1 }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChapterIndex <= 0)
                        .opacity(selectedChapterIndex <= 0 ? 0.4 : 1.0)
                        
                        Button(action: {
                            if selectedChapterIndex < bookModel.chapters.count - 1 { selectedChapterIndex += 1 }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChapterIndex >= bookModel.chapters.count - 1)
                        .opacity(selectedChapterIndex >= bookModel.chapters.count - 1 ? 0.4 : 1.0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.6))
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 0.8)
                }
            )
            .padding([.horizontal, .top], 8)
            
            if bookModel.chapters.indices.contains(selectedChapterIndex) {
                EPUBNativeWKWebView(
                    chapterURL: bookModel.chapters[selectedChapterIndex].fileURL,
                    baseDirectory: bookModel.extractDir,
                    fontSize: Double(fontSize),
                    fontStyle: fontFamily,
                    readerTheme: themeMode
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)
            } else {
                Spacer()
                Text("No chapter content available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
