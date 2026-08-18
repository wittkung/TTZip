// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

#if os(macOS) || os(Linux)
import Darwin
#endif

/// High-compression test corpus (enwik8 / enwik9) centralized caching and bootstrap manager.
///
/// Ensures zero Git repository bloat by caching datasets in system test directories (`~/Library/Caches/com.ttzip.tests/fixtures/`)
/// and synchronizing parallel workers using cross-process POSIX `flock`.
public enum EnwikFixtureCacheManager {
    
    // MARK: - Baseline Fingerprints
    
    public static let enwik8ByteCount: Int64 = 100_000_000
    public static let enwik8ExpectedSha256: String = "64cd7e3137eb139d48b7f83a48eef9c22956cfb2fdfbbfebf32b8eb4ec6cfd59"
    
    public static let enwik9ByteCount: Int64 = 1_000_000_000
    public static let enwik9ExpectedSha256: String = "f8d167f5f9e9cfda0c4a4a49df5d6de60c915f02888cf3b2f5673418579ad64b"
    
    // MARK: - Mirror Configurations
    
    public static let defaultMirrors: [(name: String, enwik8Url: String, enwik9Url: String)] = [
        (
            name: "TTZip-GitHub-CDN",
            enwik8Url: "https://github.com/wittkung/TTZip/releases/download/fixtures-v1.0.0/enwik8.zip",
            enwik9Url: "https://github.com/wittkung/TTZip/releases/download/fixtures-v1.0.0/enwik9.zip"
        ),
        (
            name: "Matt-Mahoney-Origin",
            enwik8Url: "http://mattmahoney.net/dc/enwik8.zip",
            enwik9Url: "http://mattmahoney.net/dc/enwik9.zip"
        )
    ]
    
    // MARK: - Cache Directory
    
    /// Root directory URL for test fixture cache.
    public static func cacheDirectoryURL() -> URL {
        #if os(macOS)
        let baseDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let targetDir = baseDir.appendingPathComponent("com.ttzip.tests/fixtures")
        #else
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
        let targetDir = URL(fileURLWithPath: homeDir).appendingPathComponent(".cache/ttzip/fixtures")
        #endif
        
        if !PlatformFileSystem.fileExists(atPath: targetDir.path) {
            try? FileManager.default.createDirectory(atPath: targetDir.path, withIntermediateDirectories: true)
        }
        return targetDir
    }
    
    // MARK: - Corpus Retrieval
    
    /// Retrieves or bootstraps physical local path for specified enwik dataset.
    public static func obtainCorpusPath(
        named corpusId: String,
        allowSyntheticFallback: Bool = true
    ) throws -> String {
        // 1. Direct environment variable override
        let envVar = corpusId.uppercased() == "ENWIK9" ? "TTZIP_ENWIK9_PATH" : "TTZIP_ENWIK8_PATH"
        if let envPath = ProcessInfo.processInfo.environment[envVar], !envPath.isEmpty {
            if PlatformFileSystem.fileExists(atPath: envPath) {
                return envPath
            }
        }
        
        let isEnwik9 = (corpusId.lowercased() == "enwik9")
        let targetSize = isEnwik9 ? enwik9ByteCount : enwik8ByteCount
        let targetFileName = "\(corpusId.lowercased()).xml"
        let targetURL = cacheDirectoryURL().appendingPathComponent(targetFileName)
        let lockFilePath = targetURL.path + ".lock"
        
        // 2. Existing cached file validation
        if let attrs = try? PlatformFileSystem.statFile(path: targetURL.path), attrs.size == targetSize {
            return targetURL.path
        }
        
        // 3. Acquire cross-process lock for download/generation
        return try PlatformFileSystem.withFileLock(atPath: lockFilePath, type: .exclusive) {
            if let attrs = try? PlatformFileSystem.statFile(path: targetURL.path), attrs.size == targetSize {
                return targetURL.path
            }
            
            let tempURL = targetURL.deletingLastPathComponent().appendingPathComponent("\(targetFileName).tmp.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString.prefix(8))")
            defer {
                if PlatformFileSystem.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
            
            // 4. Download from mirrors
            var downloadSucceeded = false
            for mirror in defaultMirrors {
                let urlString = isEnwik9 ? mirror.enwik9Url : mirror.enwik8Url
                guard let url = URL(string: urlString) else { continue }
                
                if let downloadedData = downloadFileSynchronously(url: url) {
                    let zipTempURL = tempURL.appendingPathExtension("zip")
                    defer { try? FileManager.default.removeItem(at: zipTempURL) }
                    
                    if (try? downloadedData.write(to: zipTempURL)) != nil {
                        if extractZipPayload(from: zipTempURL, to: tempURL) {
                            if let attrs = try? PlatformFileSystem.statFile(path: tempURL.path), attrs.size == targetSize {
                                downloadSucceeded = true
                                break
                            }
                        }
                    }
                }
            }
            
            // 5. Fallback to deterministic synthesis generator if remote download fails
            if !downloadSucceeded {
                if allowSyntheticFallback {
                    let config = SyntheticXmlCorpusConfig(
                        totalByteCount: targetSize,
                        repeatDistanceBytes: isEnwik9 ? 32 * 1024 * 1024 : 16 * 1024 * 1024,
                        repeatProbability: 0.70,
                        seed: isEnwik9 ? 0x9876543210FEDCBA : 0x123456789ABCDEF0
                    )
                    try SyntheticXmlCorpusGenerator.generate(config: config, to: tempURL)
                } else {
                    throw NSError(
                        domain: "EnwikFixtureCacheManager",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to download corpus '\(corpusId)' and synthetic fallback is disabled."]
                    )
                }
            }
            
            // 6. Atomic rename
            if rename(tempURL.path, targetURL.path) != 0 {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            
            return targetURL.path
        }
    }
    
    // MARK: - Download & Extraction Helpers
    
    private static func downloadFileSynchronously(url: URL) -> Data? {
        final class ResultBox: @unchecked Sendable {
            var data: Data?
        }
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                box.data = data
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12.0)
        return box.data
    }
    
    private static func extractZipPayload(from zipURL: URL, to outputURL: URL) -> Bool {
        let process = Process()
        let unzipBin = PlatformFileSystem.fileExists(atPath: "/usr/bin/unzip") ? "/usr/bin/unzip" : "unzip"
        process.executableURL = URL(fileURLWithPath: unzipBin)
        process.arguments = ["-p", zipURL.path]
        
        let parentDir = outputURL.deletingLastPathComponent().path
        if !PlatformFileSystem.fileExists(atPath: parentDir) {
            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }
        
        let outFd = open(outputURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard outFd >= 0 else { return false }
        defer { close(outFd) }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let readHandle = pipe.fileHandleForReading
            while true {
                let chunk = readHandle.readData(ofLength: 65536)
                if chunk.isEmpty { break }
                _ = chunk.withUnsafeBytes { rawPtr in
                    write(outFd, rawPtr.baseAddress!, chunk.count)
                }
            }
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
