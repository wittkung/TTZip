// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

// MARK: - Manifest Entry Types

/// File system entry type for manifest modeling.
public enum EntryType: String, Sendable, Equatable, Codable {
    case regularFile = "regular"
    case directory = "directory"
    case symbolicLink = "symlink"
    case hardLink = "hardlink"
}

/// Single record in a file tree manifest.
public struct ManifestEntry: Sendable, Equatable, Codable {
    public typealias EntryType = TTZipCore.EntryType

    public let relativePath: String
    public let entryType: EntryType
    public let byteSize: Int64
    public let sha256Checksum: String
    public let posixMode: UInt16
    public let symlinkTarget: String?

    public init(
        relativePath: String,
        entryType: EntryType,
        byteSize: Int64,
        sha256Checksum: String,
        posixMode: UInt16,
        symlinkTarget: String? = nil
    ) {
        self.relativePath = relativePath
        self.entryType = entryType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.posixMode = posixMode
        self.symlinkTarget = symlinkTarget
    }
}

// MARK: - File Tree Manifest

/// Complete manifest snapshot of an extracted directory tree for 1:1 bidirectional differential verification.
public struct FileTreeManifest: Sendable, Equatable, Codable {
    public let rootDirectory: String
    public let entries: [String: ManifestEntry]
    public let totalByteSize: Int64
    public let totalFileCount: Int
    public let totalDirectoryCount: Int
    public let totalSymlinkCount: Int

    public init(
        rootDirectory: String,
        entries: [String: ManifestEntry],
        totalByteSize: Int64,
        totalFileCount: Int,
        totalDirectoryCount: Int,
        totalSymlinkCount: Int
    ) {
        self.rootDirectory = rootDirectory
        self.entries = entries
        self.totalByteSize = totalByteSize
        self.totalFileCount = totalFileCount
        self.totalDirectoryCount = totalDirectoryCount
        self.totalSymlinkCount = totalSymlinkCount
    }
}

// MARK: - Differential Test Report

/// Bidirectional differential test execution report.
public struct DifferentialTestReport: Sendable, Equatable, Codable {
    public let format: ArchiveCompressionFormat
    public let targetOracle: String
    public let isPassed: Bool
    public let ttzipManifest: FileTreeManifest
    public let oracleManifest: FileTreeManifest
    public let divergenceErrors: [String]
    public let hexDiffOutput: String?

    public init(
        format: ArchiveCompressionFormat,
        targetOracle: String,
        isPassed: Bool,
        ttzipManifest: FileTreeManifest,
        oracleManifest: FileTreeManifest,
        divergenceErrors: [String],
        hexDiffOutput: String? = nil
    ) {
        self.format = format
        self.targetOracle = targetOracle
        self.isPassed = isPassed
        self.ttzipManifest = ttzipManifest
        self.oracleManifest = oracleManifest
        self.divergenceErrors = divergenceErrors
        self.hexDiffOutput = hexDiffOutput
    }
}

// MARK: - Differential Manifest Scanner

/// Recursive directory scanner generating normalized `FileTreeManifest` instances.
public enum DifferentialManifestScanner: Sendable {
    
    /// Recursively scans directory and builds normalized `FileTreeManifest`.
    public static func scanDirectory(atPath path: String) throws -> FileTreeManifest {
        let rootURL = URL(fileURLWithPath: path).standardized
        let rootPath = rootURL.path
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        
        var entries: [String: ManifestEntry] = [:]
        var totalByteSize: Int64 = 0
        var totalFileCount: Int = 0
        var totalDirectoryCount: Int = 0
        var totalSymlinkCount: Int = 0
        
        func traverse(dirPath: String) throws {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            for item in contents.sorted() {
                if item == ".noindex" || item == ".DS_Store" {
                    continue
                }
                let fullPath = (dirPath as NSString).appendingPathComponent(item)
                var st = stat()
                guard lstat(fullPath, &st) == 0 else { continue }
                
                var relPath = fullPath
                if relPath.hasPrefix(rootPath) {
                    relPath = String(relPath.dropFirst(rootPath.count))
                }
                while relPath.hasPrefix("/") {
                    relPath = String(relPath.dropFirst())
                }
                let normalizedRelPath = relPath.precomposedStringWithCanonicalMapping
                
                let mode = UInt16(st.st_mode & 0o777)
                let sMode = mode_t(st.st_mode)
                
                if (sMode & S_IFMT) == S_IFLNK {
                    var linkBuf = [CChar](repeating: 0, count: Int(PATH_MAX))
                    let len = readlink(fullPath, &linkBuf, linkBuf.count - 1)
                    let target: String? = len > 0 ? String(decoding: linkBuf.prefix(Int(len)).map { UInt8(bitPattern: $0) }, as: UTF8.self) : nil
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .symbolicLink,
                        byteSize: Int64(st.st_size),
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: target
                    )
                    entries[normalizedRelPath] = entry
                    totalSymlinkCount += 1
                } else if (sMode & S_IFMT) == S_IFDIR {
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .directory,
                        byteSize: 0,
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalDirectoryCount += 1
                    try traverse(dirPath: fullPath)
                } else {
                    let fileSize = Int64(st.st_size)
                    let checksum = computeFileSHA256(path: fullPath, size: Int(st.st_size))
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .regularFile,
                        byteSize: fileSize,
                        sha256Checksum: checksum,
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalByteSize += fileSize
                    totalFileCount += 1
                }
            }
        }
        
        try traverse(dirPath: rootPath)
        
        return FileTreeManifest(
            rootDirectory: rootPath,
            entries: entries,
            totalByteSize: totalByteSize,
            totalFileCount: totalFileCount,
            totalDirectoryCount: totalDirectoryCount,
            totalSymlinkCount: totalSymlinkCount
        )
    }
    
    // MARK: - SHA-256 Checksum Helper
    
    private static func computeFileSHA256(path: String, size: Int) -> String {
        guard size > 0 else {
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return "" }
        defer { close(fd) }
        
        if size < 32 * 1024 * 1024, let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
            defer { munmap(mapped, size) }
            posix_madvise(mapped, size, POSIX_MADV_WILLNEED)
            var hasher = SHA256()
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: mapped, count: size))
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        
        var hasher = SHA256()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var bytesRead = read(fd, buffer, bufferSize)
        while bytesRead > 0 {
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: bytesRead))
            bytesRead = read(fd, buffer, bufferSize)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Differential Manifest Verifier

/// 5-dimension manifest differential verifier.
public enum DifferentialManifestVerifier: Sendable {
    
    /// Compares TTZip output manifest with reference oracle output manifest.
    public static func compare(
        ttzip: FileTreeManifest,
        oracle: FileTreeManifest,
        format: ArchiveCompressionFormat,
        oracleName: String
    ) -> DifferentialTestReport {
        var divergenceErrors: [String] = []
        var hexDiffOutput: String? = nil
        
        let ttzipKeys = Set(ttzip.entries.keys)
        let oracleKeys = Set(oracle.entries.keys)
        
        // 1. Missing entries
        let missingKeys = oracleKeys.subtracting(ttzipKeys).sorted()
        for key in missingKeys {
            let oracleEntry = oracle.entries[key]!
            divergenceErrors.append("Missing entry in TTZip output: '\(key)' (oracle type: \(oracleEntry.entryType.rawValue), size: \(oracleEntry.byteSize)B)")
        }
        
        // 2. Extra entries
        let extraKeys = ttzipKeys.subtracting(oracleKeys).sorted()
        for key in extraKeys {
            let ttzipEntry = ttzip.entries[key]!
            divergenceErrors.append("Unexpected extra entry in TTZip output: '\(key)' (ttzip type: \(ttzipEntry.entryType.rawValue), size: \(ttzipEntry.byteSize)B)")
        }
        
        // 3. 5-dimension comparison across common entries
        let commonKeys = ttzipKeys.intersection(oracleKeys).sorted()
        for key in commonKeys {
            let ttzipEntry = ttzip.entries[key]!
            let oracleEntry = oracle.entries[key]!
            
            // Dimension 1: Entry type
            if ttzipEntry.entryType != oracleEntry.entryType {
                divergenceErrors.append("Entry '\(key)' type mismatch: TTZip is \(ttzipEntry.entryType.rawValue), Oracle is \(oracleEntry.entryType.rawValue)")
                continue
            }
            
            // Dimension 2: File size & SHA-256
            if ttzipEntry.entryType == .regularFile {
                if ttzipEntry.byteSize != oracleEntry.byteSize {
                    divergenceErrors.append("Entry '\(key)' byte size mismatch: TTZip=\(ttzipEntry.byteSize)B, Oracle=\(oracleEntry.byteSize)B")
                }
                
                if ttzipEntry.sha256Checksum != oracleEntry.sha256Checksum {
                    divergenceErrors.append("Entry '\(key)' SHA-256 checksum mismatch: TTZip=\(ttzipEntry.sha256Checksum), Oracle=\(oracleEntry.sha256Checksum)")
                    
                    if hexDiffOutput == nil {
                        let ttzipFilePath = (ttzip.rootDirectory as NSString).appendingPathComponent(key)
                        let oracleFilePath = (oracle.rootDirectory as NSString).appendingPathComponent(key)
                        if let ttzipData = try? Data(contentsOf: URL(fileURLWithPath: ttzipFilePath), options: .mappedIfSafe),
                           let oracleData = try? Data(contentsOf: URL(fileURLWithPath: oracleFilePath), options: .mappedIfSafe) {
                            hexDiffOutput = FastHexDiffEngine.generateDiff(expected: oracleData, actual: ttzipData)
                        }
                    }
                }
            }
            
            // Dimension 3: Symlink target
            if ttzipEntry.entryType == .symbolicLink {
                if ttzipEntry.symlinkTarget != oracleEntry.symlinkTarget {
                    divergenceErrors.append("Entry '\(key)' symlink target mismatch: TTZip target='\(ttzipEntry.symlinkTarget ?? "nil")', Oracle target='\(oracleEntry.symlinkTarget ?? "nil")'")
                }
            }
            
            // Dimension 4: POSIX permissions
            if ttzipEntry.posixMode != oracleEntry.posixMode {
                divergenceErrors.append("Entry '\(key)' POSIX permission mismatch: TTZip=0o\(String(ttzipEntry.posixMode, radix: 8)), Oracle=0o\(String(oracleEntry.posixMode, radix: 8))")
            }
        }
        
        let isPassed = divergenceErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracleName,
            isPassed: isPassed,
            ttzipManifest: ttzip,
            oracleManifest: oracle,
            divergenceErrors: divergenceErrors,
            hexDiffOutput: hexDiffOutput
        )
    }
}

// MARK: - Oracle Binary Resolver

/// Dynamic discovery and path resolver for system oracle binaries.
public struct OracleBinaryResolver: Sendable {
    
    public static let standardSearchDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]
    
    /// Resolves executable binary path.
    public static func resolve(binaryName: String) -> String? {
        let fm = FileManager.default
        
        if binaryName.hasPrefix("/") {
            if fm.isExecutableFile(atPath: binaryName) {
                return binaryName
            }
            if fm.fileExists(atPath: binaryName) {
                return binaryName
            }
        }
        
        for dir in standardSearchDirectories {
            let candidate = (dir as NSString).appendingPathComponent(binaryName)
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [binaryName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !str.isEmpty,
                   fm.isExecutableFile(atPath: str) {
                    return str
                }
            }
        }
        
        return nil
    }
    
    /// Resolves oracle version string.
    public static func resolveVersion(for binaryPath: String) async -> String? {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return nil }
        let binaryName = (binaryPath as NSString).lastPathComponent.lowercased()
        let versionArg: String
        if binaryName.contains("unzip") {
            versionArg = "-v"
        } else if binaryName.contains("7z") {
            versionArg = "--help"
        } else {
            versionArg = "--version"
        }
        
        if let result = try? await SubprocessExecutor.shared.executeAsync(
            executablePath: binaryPath,
            arguments: [versionArg]
        ), result.exitCode == 0 {
            let firstLine = result.output.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            return firstLine?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - Differential Oracle Registry

/// Registry of system reference oracles.
public struct DifferentialOracleRegistry: @unchecked Sendable {
    public static let shared = DifferentialOracleRegistry()
    
    public static let mandatoryOracleNames: [String] = ["tar", "unzip"]
    
    public static let knownOracleNames: [String] = [
        "tar",
        "bsdtar",
        "unzip",
        "zip",
        "7zz",
        "7z",
        "zstd",
        "gzip",
        "xz"
    ]
    
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var oracleMap: [String: String] = [:]
    }
    
    private let storage: Storage
    
    public init() {
        self.storage = Storage()
        self.storage.oracleMap = discoverOracles()
    }
    
    public func discoverOracles() -> [String: String] {
        var discovered: [String: String] = [:]
        for name in Self.knownOracleNames {
            if let path = OracleBinaryResolver.resolve(binaryName: name) {
                discovered[name] = path
            }
        }
        
        if discovered["tar"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/tar") {
            discovered["tar"] = "/usr/bin/tar"
        }
        if discovered["unzip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip") {
            discovered["unzip"] = "/usr/bin/unzip"
        }
        if discovered["zip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") {
            discovered["zip"] = "/usr/bin/zip"
        }
        if discovered["bsdtar"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/bsdtar") {
            discovered["bsdtar"] = "/usr/bin/bsdtar"
        }
        if discovered["gzip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/gzip") {
            discovered["gzip"] = "/usr/bin/gzip"
        }
        
        return discovered
    }
    
    public func oraclePath(for name: String) -> String? {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        
        if let direct = storage.oracleMap[name] {
            return direct
        }
        if name.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: name) {
            return name
        }
        let baseName = (name as NSString).lastPathComponent
        if let mapped = storage.oracleMap[baseName] {
            return mapped
        }
        if let resolved = OracleBinaryResolver.resolve(binaryName: name) {
            storage.oracleMap[name] = resolved
            return resolved
        }
        return nil
    }
    
    public func availableOracles() -> [String] {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return Array(storage.oracleMap.keys).sorted()
    }
    
    public func isAvailable(oracle: String) -> Bool {
        return oraclePath(for: oracle) != nil
    }
    
    public func mandatoryOraclesAvailable() -> Bool {
        for name in Self.mandatoryOracleNames {
            if oraclePath(for: name) == nil {
                return false
            }
        }
        return true
    }
    
    public func defaultOracle(for format: ArchiveCompressionFormat) -> String? {
        switch format {
        case .tar:
            return oraclePath(for: "tar") ?? oraclePath(for: "bsdtar")
        case .zip:
            return oraclePath(for: "unzip")
        case .sevenZip:
            return oraclePath(for: "7zz") ?? oraclePath(for: "7z")
        case .zst, .tarZst:
            return oraclePath(for: "zstd") ?? oraclePath(for: "tar")
        case .gz, .tarGz:
            return oraclePath(for: "gzip") ?? oraclePath(for: "tar")
        case .bz2, .tarBz2:
            return oraclePath(for: "tar")
        case .xz, .tarXz:
            return oraclePath(for: "xz") ?? oraclePath(for: "tar")
        default:
            return oraclePath(for: "tar") ?? oraclePath(for: "7zz")
        }
    }
}

// MARK: - Differential Oracle Test Harness

/// Differential oracle test runner executing bidirectional roundtrip comparisons.
public enum DifferentialOracleTestHarness: Sendable {
    
    /// Executes bidirectional roundtrip verification between TTZip and reference oracles.
    public static func executeRoundtrip(
        format: ArchiveCompressionFormat,
        sourceDir: String,
        oracle: String,
        tempSandbox: String
    ) async throws -> DifferentialTestReport {
        let registry = DifferentialOracleRegistry.shared
        guard let resolvedOraclePath = registry.oraclePath(for: oracle) else {
            throw ArchiveError.fileNotFound
        }
        
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourceDir).standardized
        let sandboxURL = URL(fileURLWithPath: tempSandbox).standardized
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        try fm.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        
        // 1. Baseline scan
        let baselineManifest = try DifferentialManifestScanner.scanDirectory(atPath: sourceURL.path)
        let childItems = try fm.contentsOfDirectory(atPath: sourceURL.path).sorted()
        guard !childItems.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        let fullInputPaths = childItems.map { sourceURL.appendingPathComponent($0).path }
        
        var divergenceErrors: [String] = []
        var capturedHexDiff: String? = nil
        
        // 2. Pass 1: TTZip compress -> Oracle extract
        let ttzipArchiveURL = sandboxURL.appendingPathComponent("ttzip_out_\(UUID().uuidString)\(format.fileExtension)")
        let oracleExtractURL = sandboxURL.appendingPathComponent("oracle_extracted_\(UUID().uuidString)")
        try fm.createDirectory(at: oracleExtractURL, withIntermediateDirectories: true)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: ttzipArchiveURL.path,
            format: format,
            level: .normal,
            inputPaths: fullInputPaths
        )
        guard fm.fileExists(atPath: ttzipArchiveURL.path) else {
            throw ArchiveError.readFailed(code: -1)
        }
        
        try await extractWithOracle(
            oraclePath: resolvedOraclePath,
            format: format,
            archivePath: ttzipArchiveURL.path,
            destinationDir: oracleExtractURL.path
        )
        
        let oracleExtractedManifest = try DifferentialManifestScanner.scanDirectory(atPath: oracleExtractURL.path)
        let pass1Report = DifferentialManifestVerifier.compare(
            ttzip: oracleExtractedManifest,
            oracle: baselineManifest,
            format: format,
            oracleName: "\(oracle) (TTZip->Oracle)"
        )
        divergenceErrors.append(contentsOf: pass1Report.divergenceErrors)
        if capturedHexDiff == nil {
            capturedHexDiff = pass1Report.hexDiffOutput
        }
        
        // 3. Pass 2: Oracle compress -> TTZip extract (if oracle supports creation)
        var ttzipExtractedManifest: FileTreeManifest? = nil
        if canOracleCompress(oracle: resolvedOraclePath, format: format) {
            let oracleArchiveURL = sandboxURL.appendingPathComponent("oracle_out_\(UUID().uuidString)\(format.fileExtension)")
            let ttzipExtractURL = sandboxURL.appendingPathComponent("ttzip_extracted_\(UUID().uuidString)")
            try fm.createDirectory(at: ttzipExtractURL, withIntermediateDirectories: true)
            
            try await compressWithOracle(
                oraclePath: resolvedOraclePath,
                format: format,
                sourceDir: sourceURL.path,
                inputItems: childItems,
                outputPath: oracleArchiveURL.path
            )
            
            if fm.fileExists(atPath: oracleArchiveURL.path) {
                let extractor = ArchiveExtractor()
                try await extractor.extract(
                    archivePath: oracleArchiveURL.path,
                    destinationDir: ttzipExtractURL.path,
                    options: ArchiveFilterOptions(skipMacJunk: false)
                )
                
                let ttzipManifest = try DifferentialManifestScanner.scanDirectory(atPath: ttzipExtractURL.path)
                ttzipExtractedManifest = ttzipManifest
                
                let pass2Report = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: baselineManifest,
                    format: format,
                    oracleName: "\(oracle) (Oracle->TTZip)"
                )
                divergenceErrors.append(contentsOf: pass2Report.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = pass2Report.hexDiffOutput
                }
                
                let crossReport = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: oracleExtractedManifest,
                    format: format,
                    oracleName: oracle
                )
                divergenceErrors.append(contentsOf: crossReport.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = crossReport.hexDiffOutput
                }
            }
        }
        
        var seenErrors = Set<String>()
        var uniqueErrors: [String] = []
        for err in divergenceErrors {
            if !seenErrors.contains(err) {
                seenErrors.insert(err)
                uniqueErrors.append(err)
            }
        }
        
        let isPassed = uniqueErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracle,
            isPassed: isPassed,
            ttzipManifest: ttzipExtractedManifest ?? oracleExtractedManifest,
            oracleManifest: oracleExtractedManifest,
            divergenceErrors: uniqueErrors,
            hexDiffOutput: capturedHexDiff
        )
    }
    
    // MARK: - Oracle Subprocess Execution Helpers
    
    public static func canOracleCompress(oracle: String, format: ArchiveCompressionFormat) -> Bool {
        let name = (oracle as NSString).lastPathComponent.lowercased()
        if name.contains("tar") {
            return format == .tar || format == .gz || format == .tarGz || format == .bz2 || format == .tarBz2 || format == .xz || format == .tarXz || format == .zst || format == .tarZst
        }
        if name.contains("unzip") {
            return DifferentialOracleRegistry.shared.oraclePath(for: "zip") != nil && format == .zip
        }
        if name.contains("zip") {
            return format == .zip
        }
        if name.contains("7z") {
            return format == .sevenZip || format == .zip || format == .tar
        }
        if name == "zstd" {
            return format == .zst || format == .tarZst
        }
        if name == "gzip" {
            return format == .gz || format == .tarGz
        }
        if name == "xz" {
            return format == .xz || format == .tarXz
        }
        return false
    }
    
    public static func extractWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        archivePath: String,
        destinationDir: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        let args: [String]
        
        if name.contains("unzip") {
            args = ["-q", "-o", archivePath, "-d", destinationDir]
        } else if name.contains("tar") {
            args = ["-xf", archivePath, "-C", destinationDir]
        } else if name.contains("7z") {
            args = ["x", "-y", "-o\(destinationDir)", archivePath]
        } else {
            args = ["-xf", archivePath, "-C", destinationDir]
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: oraclePath,
            arguments: args,
            currentDirectory: destinationDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
    
    public static func compressWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        sourceDir: String,
        inputItems: [String],
        outputPath: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        var execPath = oraclePath
        let args: [String]
        
        if name.contains("tar") {
            var flag = "-cf"
            switch format {
            case .gz, .tarGz: flag = "-czf"
            case .bz2, .tarBz2: flag = "-cjf"
            case .xz, .tarXz: flag = "-cJf"
            default: flag = "-cf"
            }
            args = [flag, outputPath, "-C", sourceDir] + inputItems
        } else if name.contains("unzip") {
            guard let zipPath = DifferentialOracleRegistry.shared.oraclePath(for: "zip") else {
                throw ArchiveError.invalidFormat
            }
            execPath = zipPath
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("zip") {
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("7z") {
            args = ["a", "-y", outputPath] + inputItems
        } else {
            throw ArchiveError.invalidFormat
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: execPath,
            arguments: args,
            currentDirectory: sourceDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
}
