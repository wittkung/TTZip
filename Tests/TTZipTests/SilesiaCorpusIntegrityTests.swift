// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore

final class SilesiaCorpusIntegrityTests: XCTestCase {
    
    struct SilesiaManifestItem: Codable {
        let name: String
        let size: Int
        let sha256: String
        let category: String
        let description: String
    }
    
    struct SilesiaManifestRoot: Codable {
        let version: String
        let corpusName: String
        let totalFiles: Int
        let totalBytes: Int
        let files: [SilesiaManifestItem]
    }
    
    func testCorpusManifestIntegrity() throws {
        let manifestURL = try SilesiaFixtureLoader.manifestURL()
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(SilesiaManifestRoot.self, from: manifestData)
        
        XCTAssertEqual(manifest.totalFiles, 12, "Manifest must declare exactly 12 standard files")
        XCTAssertEqual(manifest.files.count, 12, "Manifest files array must contain exactly 12 entries")
        
        let calculatedTotalBytes = manifest.files.reduce(0) { $0 + $1.size }
        XCTAssertEqual(manifest.totalBytes, calculatedTotalBytes, "Total bytes declared must equal sum of file sizes")
        XCTAssertEqual(manifest.totalBytes, 211938580, "Total bytes must equal 211,938,580 bytes")
    }
    
    func testAll12FilesByteLengthAndSha256() throws {
        let manifestURL = try SilesiaFixtureLoader.manifestURL()
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SilesiaManifestRoot.self, from: manifestData)
        
        var totalLoadedBytes = 0
        
        for item in manifest.files {
            let fileURL = try SilesiaFixtureLoader.fileURL(named: item.name)
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = fileAttributes[.size] as? Int else {
                XCTFail("Could not read file size for \(item.name)")
                continue
            }
            
            XCTAssertEqual(fileSize, item.size, "File '\(item.name)' size mismatch: expected \(item.size), got \(fileSize)")
            totalLoadedBytes += fileSize
            
            // SHA-256
            let data = try SilesiaFixtureLoader.mappedData(named: item.name)
            let digest = SHA256.hash(data: data)
            let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
            
            XCTAssertEqual(hexDigest, item.sha256, "File '\(item.name)' SHA-256 mismatch: expected \(item.sha256), got \(hexDigest)")
        }
        
        XCTAssertEqual(totalLoadedBytes, 211938580, "Total loaded corpus byte size must match exact 211,938,580 bytes")
    }
}
