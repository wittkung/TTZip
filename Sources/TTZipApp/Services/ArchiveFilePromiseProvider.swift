// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit
import UniformTypeIdentifiers
import TTZipCore

/// Helper factory to generate NSItemProviders for in-archive entries and disk items.
public enum ArchiveDragItemProviderFactory {
    public static func createItemProvider(
        archivePath: String,
        entryPath: String,
        suggestedFileName: String,
        password: String? = nil
    ) -> NSItemProvider {
        let utType = UTType(filenameExtension: (suggestedFileName as NSString).pathExtension) ?? .data
        let itemProvider = NSItemProvider()
        itemProvider.suggestedName = suggestedFileName
        
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: utType.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_drag_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent(suggestedFileName)
            
            Task.detached(priority: .userInitiated) {
                do {
                    if let data = try await ArchiveSelectiveExtractor.shared.extractSingleEntryData(
                        archivePath: archivePath,
                        entryPath: entryPath,
                        password: password
                    ) {
                        try data.write(to: tempURL, options: [.atomic])
                        completion(tempURL, true, nil)
                    } else {
                        let err = NSError(domain: "TTZip", code: -2, userInfo: [NSLocalizedDescriptionKey: "Entry not found"])
                        completion(nil, false, err)
                    }
                } catch {
                    completion(nil, false, error)
                }
            }
            return Progress(totalUnitCount: 1)
        }
        
        return itemProvider
    }
}
