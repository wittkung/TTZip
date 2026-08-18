// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuickLook
import UniformTypeIdentifiers

#if canImport(QuickLookUI)
import QuickLookUI
#endif

/// Out-of-process QuickLook preview generator and protocol bridge for macOS Quick Look extensions.
///
/// Delivers zero-cost, sub-50ms data-based HTML5 archive previews directly to macOS QuickLook
/// without hosting a full AppKit / SwiftUI view hierarchy inside the `quicklookd` daemon.
public final class TTZipQuickLookProvider: NSObject, @unchecked Sendable {
    
    public override init() {
        super.init()
    }
    
    /// Generates raw HTML5 data payload for QuickLook preview reply.
    public func provideHTMLPreviewData(for fileURL: URL) async throws -> Data {
        let htmlString = try await QuickLookPreviewEngine.generateHTMLPreview(for: fileURL.path)
        guard let data = htmlString.data(using: .utf8) else {
            throw ArchiveError.invalidFormat
        }
        return data
    }
}
