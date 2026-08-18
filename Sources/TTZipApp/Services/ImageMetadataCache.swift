// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

@MainActor
public final class ImageMetadataCache {
    public static let shared = ImageMetadataCache()
    
    private var dimensionsCache: [String: String] = [:]
    
    private init() {}
    
    @MainActor
    public func clear() {
        dimensionsCache.removeAll()
    }
    
    public func getDimensions(for path: String) -> String? {
        return dimensionsCache[path]
    }
    
    public func loadDimensionsAsync(path: String, url: URL) async -> String? {
        if let existing = dimensionsCache[path] {
            return existing
        }
        
        let formatted = await Task.detached(priority: .utility) { () -> String? in
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else {
                return nil
            }
            return "\(width) × \(height)"
        }.value
        
        if let formatted = formatted {
            dimensionsCache[path] = formatted
        }
        return formatted
    }
}
