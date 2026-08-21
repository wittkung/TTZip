// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - Differential Manifest Scanner

/// Recursive directory scanner generating normalized `FileTreeManifest` instances,
/// directly backed by hardware-accelerated Safe Rust multi-core Rayon C-ABI engine.
public enum DifferentialManifestScanner: Sendable {
    
    /// Recursively scans directory and builds normalized `FileTreeManifest`.
    public static func scanDirectory(atPath path: String) throws -> FileTreeManifest {
        let rootURL = URL(fileURLWithPath: path).standardized
        let rootPath = rootURL.path
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        
        var outPtr: UnsafeMutablePointer<CChar>? = nil
        let status = rootPath.withCString { cPath in
            ttzip_rust_differential_scan_directory(cPath, &outPtr)
        }
        
        guard status == TTZIP_STATUS_OK, let validPtr = outPtr else {
            if status == TTZIP_STATUS_ERR_FILE_NOT_FOUND {
                throw ArchiveError.fileNotFound
            }
            throw ArchiveError.readFailed(code: status.rawValue)
        }
        
        defer { ttzip_rust_free_differential_string(validPtr) }
        
        let jsonStr = String(cString: validPtr)
        guard let jsonData = jsonStr.data(using: .utf8) else {
            throw ArchiveError.invalidFormat
        }
        
        do {
            return try JSONDecoder().decode(FileTreeManifest.self, from: jsonData)
        } catch {
            throw ArchiveError.invalidFormat
        }
    }
}
