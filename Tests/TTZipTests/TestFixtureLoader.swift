// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// ( SPM Bundle.module )
public enum TestFixtureLoader {
    
    /// Fixtures/Encrypted URL
    public static func encryptedFixtureURL(named filename: String) throws -> URL {
        let name: String
        let ext: String
        
        if let dotIndex = filename.lastIndex(of: ".") {
            name = String(filename[..<dotIndex])
            ext = String(filename[filename.index(after: dotIndex)...])
        } else {
            name = filename
            ext = ""
        }
        
        // 1. Bundle.module
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/Encrypted") {
            return resourceURL
        }
        if let resourceURL = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures/Encrypted") {
            return resourceURL
        }
        #endif
        
        // 2. ( )
        let currentFile = URL(fileURLWithPath: #filePath)
        let testDir = currentFile.deletingLastPathComponent()
        let fallbackPath = testDir.appendingPathComponent("Fixtures/Encrypted/\(filename)")
        if FileManager.default.fileExists(atPath: fallbackPath.path) {
            return fallbackPath
        }
        
        throw NSError(
            domain: "TestFixtureLoader",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Test fixture '\(filename)' not found in Bundle.module or Fixtures/Encrypted/"]
        )
    }
    
    /// ( C open/mmap )
    public static func encryptedFixturePath(named filename: String) throws -> String {
        return try encryptedFixtureURL(named: filename).path
    }
}
