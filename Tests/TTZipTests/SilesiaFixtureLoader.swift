// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Silesia ( SPM Bundle.module )
public enum SilesiaFixtureLoader {
    
    /// Fixtures/Silesia URL
    public static func corpusDirectoryURL() throws -> URL {
        #if SWIFT_PACKAGE
        if let bundleURL = Bundle.module.url(forResource: "Silesia", withExtension: nil, subdirectory: "Fixtures") {
            return bundleURL
        }
        if let bundleURL = Bundle.module.url(forResource: "silesia_manifest", withExtension: "json", subdirectory: "Fixtures/Silesia") {
            return bundleURL.deletingLastPathComponent()
        }
        #endif
        
        if let envPath = ProcessInfo.processInfo.environment["TTZIP_SILESIA_PATH"], !envPath.isEmpty {
            let envURL = URL(fileURLWithPath: envPath)
            if FileManager.default.fileExists(atPath: envURL.path) {
                return envURL
            }
        }
        
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fallbackURL = sourceFile.deletingLastPathComponent().appendingPathComponent("Fixtures/Silesia")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        
        throw NSError(
            domain: "SilesiaFixtureLoader",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Silesia corpus directory not found in Bundle.module, TTZIP_SILESIA_PATH, or Tests/TTZipTests/Fixtures/Silesia/"]
        )
    }
    
    /// Silesia URL
    public static func fileURL(named filename: String) throws -> URL {
        let dir = try corpusDirectoryURL()
        let file = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw NSError(
                domain: "SilesiaFixtureLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Silesia corpus item '\(filename)' missing at '\(file.path)'"]
            )
        }
        return file
    }
    
    /// Silesia ( C open/mmap )
    public static func filePath(named filename: String) throws -> String {
        return try fileURL(named: filename).path
    }
    
    /// ( )
    public static func mappedData(named filename: String) throws -> Data {
        let url = try fileURL(named: filename)
        return try Data(contentsOf: url, options: .alwaysMapped)
    }
    
    /// silesia_manifest.json URL
    public static func manifestURL() throws -> URL {
        return try fileURL(named: "silesia_manifest.json")
    }
    
    /// 12 Silesia
    public static let standardFileNames: [String] = [
        "dickens",
        "mozilla",
        "mr",
        "nci",
        "ooffice",
        "osdb",
        "reymont",
        "samba",
        "sao",
        "webster",
        "xml",
        "x-ray"
    ]
}
