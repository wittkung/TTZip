// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

public struct SystemBinaryDescriptor: Sendable, Codable {
    public let binaryName: String
    public let resolvedPath: String
    public let resolutionSource: String
    public let isAvailable: Bool
    public let versionString: String

    public init(
        binaryName: String,
        resolvedPath: String,
        resolutionSource: String,
        isAvailable: Bool,
        versionString: String
    ) {
        self.binaryName = binaryName
        self.resolvedPath = resolvedPath
        self.resolutionSource = resolutionSource
        self.isAvailable = isAvailable
        self.versionString = versionString
    }
}

/// Unified 5-Tier Dynamic System Binary Resolver.
/// Resolves external CLI binaries without hardcoded paths.
public final class SystemBinaryResolver: @unchecked Sendable {
    public static let shared = SystemBinaryResolver()

    private let lock = NSLock()
    private var cache: [String: String?] = [:]
    private var descriptorCache: [String: SystemBinaryDescriptor] = [:]

    private let candidateDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/opt/local/bin"
    ]

    public init() {}

    /// Resolve absolute executable path for a given binary tool name.
    public func resolve(name: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[name] {
            return cached
        }

        let resolved = performResolution(name: name)
        cache[name] = resolved
        return resolved
    }

    /// Resolve full descriptor with metadata.
    public func resolveDescriptor(name: String) -> SystemBinaryDescriptor {
        lock.lock()
        defer { lock.unlock() }

        if let desc = descriptorCache[name] {
            return desc
        }

        let (path, source) = performResolutionWithSource(name: name)
        let isAvail = path != nil
        let version = isAvail ? (extractVersion(path: path!) ?? "Unknown version") : "Not installed"

        let desc = SystemBinaryDescriptor(
            binaryName: name,
            resolvedPath: path ?? "",
            resolutionSource: source,
            isAvailable: isAvail,
            versionString: version
        )
        descriptorCache[name] = desc
        return desc
    }

    public static func resolveBinaryPath(_ name: String) -> String? {
        shared.resolve(name: name)
    }

    private func performResolution(name: String) -> String? {
        performResolutionWithSource(name: name).path
    }

    private func performResolutionWithSource(name: String) -> (path: String?, source: String) {
        let fm = FileManager.default

        // 1. Environment Variable Override (e.g. TTZIP_ZSTD_PATH, ZSTD_PATH)
        let envKey1 = "TTZIP_\(name.uppercased())_PATH"
        let envKey2 = "\(name.uppercased())_PATH"
        if let envPath = ProcessInfo.processInfo.environment[envKey1] ?? ProcessInfo.processInfo.environment[envKey2],
           fm.isExecutableFile(atPath: envPath) {
            return (envPath, "environment")
        }

        // 2. Main / Module Bundle Resources
        if let bundlePath = Bundle.main.path(forResource: name, ofType: nil),
           fm.isExecutableFile(atPath: bundlePath) {
            return (bundlePath, "bundle")
        }

        // 3. System PATH lookup via which
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathEnv.split(separator: ":").map(String.init)
            for p in paths {
                let fullPath = (p as NSString).appendingPathComponent(name)
                if fm.isExecutableFile(atPath: fullPath) {
                    return (fullPath, "path")
                }
            }
        }

        // 4. Standard Directory Fallback Search
        for dir in candidateDirectories {
            let fullPath = (dir as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: fullPath) {
                return (fullPath, "standard_directory")
            }
        }

        return (nil, "unavailable")
    }

    private func extractVersion(path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output.components(separatedBy: .newlines).first
            }
        } catch {
            return nil
        }
        return nil
    }
}
