// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
