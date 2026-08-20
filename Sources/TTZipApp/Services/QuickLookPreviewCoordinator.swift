// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import AppKit
import TTZipCore

/// Coordinates native macOS Quick Look space-bar previews and on-demand streaming extraction for TTZip.
@MainActor
public final class QuickLookPreviewCoordinator: ObservableObject {
    public static let shared = QuickLookPreviewCoordinator()
    
    @Published public var activePreviewURL: URL? = nil
    @Published public var isExtractingPreview: Bool = false
    
    private var currentTargetIdentifier: String? = nil
    
    public init() {
        setupSpaceBarMonitor()
    }
    
    private func setupSpaceBarMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // KeyCode 49 is Space Bar
            if event.keyCode == 49 {
                // If focus is in a text input / editing field, let standard space character pass through
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                
                guard let self = self else { return event }
                if self.activePreviewURL != nil {
                    self.dismissPreview()
                    return nil // Consumed
                }
            }
            return event
        }
    }
    
    /// Previews a local file from disk.
    public func previewDiskFile(url: URL) {
        if activePreviewURL == url {
            dismissPreview()
            return
        }
        currentTargetIdentifier = url.path
        activePreviewURL = url
    }
    
    /// Previews an in-archive virtual entry asynchronously by extracting on demand.
    public func previewArchiveEntry(
        archivePath: String,
        entryPath: String,
        suggestedFileName: String? = nil,
        password: String? = nil
    ) {
        let identifier = "\(archivePath)::\(entryPath)"
        if currentTargetIdentifier == identifier && activePreviewURL != nil {
            dismissPreview()
            return
        }
        
        currentTargetIdentifier = identifier
        isExtractingPreview = true
        let fileName = suggestedFileName ?? (entryPath as NSString).lastPathComponent
        
        Task {
            do {
                if let data = try await ArchiveSelectiveExtractor.shared.extractSingleEntryData(
                    archivePath: archivePath,
                    entryPath: entryPath,
                    password: password
                ) {
                    let stagedURL = try await EphemeralPreviewCacheManager.shared.stageFile(
                        data: data,
                        suggestedFileName: fileName
                    )
                    await MainActor.run {
                        self.activePreviewURL = stagedURL
                        self.isExtractingPreview = false
                    }
                } else {
                    await MainActor.run {
                        self.isExtractingPreview = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isExtractingPreview = false
                }
            }
        }
    }
    
    /// Dismisses the active Quick Look preview.
    public func dismissPreview() {
        activePreviewURL = nil
        currentTargetIdentifier = nil
        isExtractingPreview = false
    }
}
