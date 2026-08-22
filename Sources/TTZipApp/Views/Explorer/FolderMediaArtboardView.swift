// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

public struct FolderMediaArtboardView: View {
    public let item: DiskItemInfo
    public let onCompressPath: (String) -> Void
    
    @State var totalSizeBytes: Int64 = 0
    @State var subfolderCount: Int = 0
    @State var fileCount: Int = 0
    @State var isCalculating: Bool = true
    @State var fileTypeDistribution: [(category: String, count: Int)] = []
    @State var showCreateSubfolderAlert: Bool = false
    @State var newSubfolderName: String = "Untitled Folder"
    @State var showCreateFileAlert: Bool = false
    @State var newSubfileName: String = "Untitled.txt"
    
    public init(item: DiskItemInfo, onCompressPath: @escaping (String) -> Void) {
        self.item = item
        self.onCompressPath = onCompressPath
    }
    
    var formattedFolderSize: String {
        if isCalculating { return "Calculating..." }
        return ByteCountFormatterFlyweight.shared.string(fromByteCount: totalSizeBytes)
    }
    
    var formattedDate: String {
        guard let d = item.modificationDate else { return "Unknown" }
        return DateFormatterCache.shared.string(fromShortDateTime: d)
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            
                            Text(item.path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                    }
                    
                    GeometryReader { btnGeo in
                        let w = btnGeo.size.width
                        HStack(spacing: w >= 320 ? 12 : 6) {
                            Button(action: {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder").font(.system(size: 11))
                                        Text("Reveal in Finder")
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                            
                            Button(action: {
                                showCreateSubfolderAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.badge.plus").font(.system(size: 11))
                                        Text("New Folder")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Create new subfolder")
                            
                            Button(action: {
                                showCreateFileAlert = true
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.badge.plus").font(.system(size: 11))
                                        Text("New File")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(TTZipTheme.bambooGreen)
                                } else {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TTZipTheme.bambooGreen)
                                        .padding(5.5)
                                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Create new empty file")
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.path, forType: .string)
                            }) {
                                if w >= 320 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc").font(.system(size: 11))
                                        Text("Copy Path")
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(5.5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Copy Path")
                        }
                    }
                    .frame(height: 24)
                }
                
                Divider()
                
                overviewSection
                
                contentBreakdownSection
                
                Spacer(minLength: 12)
                
                Button(action: { onCompressPath(item.path) }) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("New Archive (⌘N)")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("New Archive")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Compress")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(TTZipTheme.bambooGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
        .alert("New Folder", isPresented: $showCreateSubfolderAlert) {
            TextField("Folder Name", text: $newSubfolderName)
            Button("Cancel", role: .cancel) {
                newSubfolderName = "Untitled Folder"
            }
            Button("Create", action: createNewFolder)
        } message: {
            Text("Creating new folder in:\n\(item.path)")
        }
        .alert("New File", isPresented: $showCreateFileAlert) {
            TextField("File Name (e.g. text.txt)", text: $newSubfileName)
            Button("Cancel", role: .cancel) {
                newSubfileName = "Untitled.txt"
            }
            Button("Create", action: createNewFile)
        } message: {
            Text("Creating new empty file in:\n\(item.path)")
        }
        .task(id: item.path) {
            await calculateStats()
        }
    }
}
