// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public enum MillerColumnDirectoryScanner {
    public static func loadContentsOf(dirURL: URL) async -> [DiskItemInfo] {
        var isDir: ObjCBool = false
        let path = dirURL.path
        
        await RootFolderAccessManager.shared.ensureAccess(for: dirURL, promptIfMissing: false)
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            var diskItems: [DiskItemInfo] = []
            if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for file in files {
                    let itemURL = dirURL.appendingPathComponent(file)
                    diskItems.append(DiskItemInfo(url: itemURL))
                }
            }
            return diskItems.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
        
        let archivePath: String
        let subpath: String
        
        if let components = URLComponents(url: dirURL, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let subItem = queryItems.first(where: { $0.name == "subpath" })?.value {
            archivePath = dirURL.path
            subpath = subItem.hasSuffix("/") ? String(subItem.dropLast()) : subItem
        } else {
            archivePath = dirURL.path
            subpath = ""
        }
        
        guard FileManager.default.fileExists(atPath: archivePath) else { return [] }
        
        let targetPassword = ArchivePasswordStore.shared.getPassword(for: archivePath)
        let inspectionResult = try? await TTZipEngineFacade.shared.inspectArchiveCached(
            archivePath: archivePath,
            password: targetPassword,
            autoVaultUnlock: PasswordVaultManager.shared.autoUnlockArchives
        )
        let fetchedEntries = inspectionResult?.entries
        
        guard let entries = fetchedEntries else {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TTZipEncryptedArchivePromptRequired"),
                    object: archivePath
                )
            }
            return [
                DiskItemInfo(
                    virtualName: "Encrypted Archive (Click to enter password)",
                    virtualURL: dirURL,
                    isDirectory: false,
                    isArchive: false,
                    sizeText: "Password Required",
                    rawSizeBytes: 0,
                    kindText: "Password-Protected Archive"
                )
            ]
        }
        
        let rootComposite = ArchiveComponentTreeBuilder.buildTree(from: entries)
        var targetComponent: ArchiveComponentProtocol = rootComposite
        
        if !subpath.isEmpty {
            let parts = subpath.components(separatedBy: "/").filter { !$0.isEmpty }
            for part in parts {
                let nextDir: ArchiveComponentProtocol?
                if let compositeDir = targetComponent as? ArchiveCompositeDirectory {
                    let child = compositeDir.findChild(named: part)
                    nextDir = (child?.isDirectory == true) ? child : nil
                } else {
                    nextDir = targetComponent.getChildren().first(where: { $0.name == part && $0.isDirectory })
                }
                if let dir = nextDir {
                    targetComponent = dir
                } else {
                    break
                }
            }
        }
        
        let childComponents = targetComponent.getChildren()
        var diskItems: [DiskItemInfo] = []
        let prefix = subpath.isEmpty ? "" : (subpath.hasSuffix("/") ? subpath : subpath + "/")
        
        for child in childComponents {
            let childSubpath = prefix + child.name
            var comp = URLComponents(url: URL(fileURLWithPath: archivePath), resolvingAgainstBaseURL: false)!
            comp.queryItems = [URLQueryItem(name: "subpath", value: childSubpath)]
            let virtualURL = comp.url ?? URL(fileURLWithPath: archivePath)
            
            let visitor = ArchiveComponentVisitor<DiskItemInfo>(
                visitLeaf: { leaf in
                    let ext = (leaf.name as NSString).pathExtension
                    let sizeText = ByteCountFormatter.string(fromByteCount: leaf.sizeBytes, countStyle: .file)
                    let kind = ext.isEmpty ? "File" : "\(ext.uppercased()) File"
                    return DiskItemInfo(
                        virtualName: leaf.name,
                        virtualURL: virtualURL,
                        isDirectory: false,
                        isArchive: false,
                        sizeText: sizeText,
                        rawSizeBytes: leaf.sizeBytes,
                        kindText: kind
                    )
                },
                visitComposite: { composite in
                    return DiskItemInfo(
                        virtualName: composite.name,
                        virtualURL: virtualURL,
                        isDirectory: true,
                        isArchive: false,
                        sizeText: "Folder",
                        rawSizeBytes: composite.sizeBytes,
                        kindText: "Archive Folder"
                    )
                }
            )
            diskItems.append(child.accept(visitor: visitor))
        }
        
        return diskItems.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
