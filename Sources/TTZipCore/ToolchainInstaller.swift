// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

public enum ToolchainError: Error, LocalizedError, Sendable {
    case homebrewNotInstalledNeedConsent
    case processFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .homebrewNotInstalledNeedConsent:
            return "Homebrew package manager is not installed on this system and requires user consent to install."
        case .processFailed(let msg):
            return "Toolchain deployment failed: \(msg)"
        }
    }
}

/// Helper and detection utility for optional external CLI benchmarking toolchains (7-Zip, pigz, zstd).
public final class ToolchainInstaller: @unchecked Sendable {
    public static let shared = ToolchainInstaller()
    
    private init() {}
    
    /// Path to Homebrew executable if installed.
    public var homebrewExecutablePath: String? {
        #if MAS_BUILD
        return nil
        #else
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for p in candidates {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        return nil
        #endif
    }
    
    public var isHomebrewInstalled: Bool {
        return homebrewExecutablePath != nil
    }
    
    /// Checks GitHub connectivity with 2-second timeout.
    public func testGitHubConnectivity() -> Bool {
        #if MAS_BUILD
        return false
        #else
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-s", "-I", "--connect-timeout", "2", "https://raw.githubusercontent.com"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
        #endif
    }
    
    /// Installs Homebrew package manager.
    public func installHomebrew(statusHandler: @escaping @Sendable (String) -> Void) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("External toolchain management is disabled in Mac App Store sandbox")
        return false
        #else
        if isHomebrewInstalled {
            statusHandler("Homebrew is already present on this system")
            return true
        }
        
        let hasDirectGitHub = testGitHubConnectivity()
        
        if hasDirectGitHub {
            statusHandler("Connecting to official Homebrew repository...")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 && isHomebrewInstalled {
                statusHandler("Homebrew package manager installed successfully")
                return true
            }
        }
        
        statusHandler("Switching to mirror deployment...")
        
        let mirrorProcess = Process()
        mirrorProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        let mirrorCmd = """
        export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
        export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
        """
        mirrorProcess.arguments = ["-c", mirrorCmd]
        
        let mirrorPipe = Pipe()
        mirrorProcess.standardOutput = mirrorPipe
        mirrorProcess.standardError = mirrorPipe
        
        do {
            try mirrorProcess.run()
            mirrorProcess.waitUntilExit()
        } catch {
            // Fallback
        }
        
        if isHomebrewInstalled {
            statusHandler("Homebrew installed successfully via mirror")
            return true
        } else {
            statusHandler("Network installation failed, using built-in engines")
            return false
        }
        #endif
    }
    
    /// Returns terminal installation command recommendations for benchmark tools.
    public func getInstallationGuide(for toolId: String) -> String {
        switch toolId {
        case "7zip_cli":
            return "To run 7-Zip CLI benchmark comparisons, install via terminal:\n  brew install 7-zip"
        case "pigz_cli":
            return "To run pigz benchmark comparisons, install via terminal:\n  brew install pigz"
        case "zstd_cli":
            return "To run zstd benchmark comparisons, install via terminal:\n  brew install zstd"
        case "turbobench_cli":
            return "To run TurboBench benchmark comparisons, build TurboBench from source (https://github.com/powturbo/TurboBench)"
        case "lzbench_cli":
            return "To run lzbench in-memory tests, run:\n  brew install lzbench (or build from source)"
        default:
            return "Install this tool via Homebrew to participate in benchmark comparisons."
        }
    }
    
    /// Probes 7-Zip CLI installation state or returns guidance.
    public func installSevenZipToolchain(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("External toolchain management is disabled in Mac App Store sandbox")
        return false
        #else
        if let cli = CompetitorDetector.detectAllCompetitors().first(where: { $0.toolId == "7zip_cli" }), cli.isInstalled {
            statusHandler("7-Zip toolchain ready: \(cli.cliExecutablePath ?? "")")
            return true
        }
        statusHandler(getInstallationGuide(for: "7zip_cli"))
        return false
        #endif
    }
    
    /// Probes pigz multi-threaded toolchain installation state.
    public func installPigzToolchain(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("External toolchain management is disabled in Mac App Store sandbox")
        return false
        #else
        if let cli = CompetitorDetector.detectAllCompetitors().first(where: { $0.toolId == "pigz_cli" }), cli.isInstalled {
            statusHandler("pigz toolchain ready: \(cli.cliExecutablePath ?? "")")
            return true
        }
        statusHandler(getInstallationGuide(for: "pigz_cli"))
        return false
        #endif
    }
    
    /// Probes all competitor toolchains.
    public func installAllCompetitorToolchains(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("External toolchain management is disabled in Mac App Store sandbox")
        return false
        #else
        let ok7z = (try? await installSevenZipToolchain(userConsentedHomebrew: userConsentedHomebrew, statusHandler: statusHandler)) ?? false
        let okPigz = (try? await installPigzToolchain(userConsentedHomebrew: userConsentedHomebrew, statusHandler: statusHandler)) ?? false
        return ok7z && okPigz
        #endif
    }

    /// Uninstalls designated competitor toolchains.
    public func uninstallCompetitorToolchains(
        tools: [String],
        statusHandler: @escaping @Sendable (String) -> Void
    ) async -> [String: Bool] {
        #if MAS_BUILD
        statusHandler("External toolchain uninstall is disabled in Mac App Store sandbox")
        return [:]
        #else
        var results: [String: Bool] = [:]
        let isAll = tools.contains("all") || tools.contains("ALL")
        let brewPath = homebrewExecutablePath

        let targetTools = isAll ? ["keka", "betterzip", "maczip", "pigz", "7zip", "zstd"] : tools

        for tool in targetTools {
            let lower = tool.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.isEmpty { continue }
            statusHandler("Uninstalling: \(lower)...")

            var success = false

            switch lower {
            case "keka":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "keka"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/Keka.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/Keka.app")

            case "betterzip":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "betterzip"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/BetterZip.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/BetterZip.app")

            case "maczip", "ezip":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "maczip"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/MacZip.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/MacZip.app")

            case "pigz":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "pigz"])
                    success = code == 0
                }

            case "7zip", "7z", "7zz":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "7-zip"])
                    success = code == 0
                }

            case "zstd":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "zstd"])
                    success = code == 0
                }

            default:
                statusHandler("Unknown component: \(lower)")
            }

            results[lower] = success
            if success {
                statusHandler("Completed removal of \(lower)")
            } else {
                statusHandler("\(lower) removal may require manual confirmation")
            }
        }

        return results
        #endif
    }

    #if !MAS_BUILD
    @discardableResult
    private func runProcess(_ binary: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
    #endif
}

// MARK: - SevenZip Resolver

//
//


/// 7-Zip native executable binary resolver supporting embedded bundle extraction and PATH fallback.
public final class SevenZipBinaryResolver: @unchecked Sendable {
    public static let shared = SevenZipBinaryResolver()

    private let lock = NSLock()
    private var cachedPath: String?

    private init() {}

    public static func resolveBinaryPath() -> String? {
        return shared.resolve()
    }

    public func resolve() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let path = cachedPath {
            return path
        }
        
        if let bundlePath = Bundle.main.path(forResource: "7zz", ofType: nil),
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            cachedPath = bundlePath
            return bundlePath
        }
        
        let candidates = [
            "/opt/homebrew/bin/7zz",
            "/opt/homebrew/bin/7z",
            "/usr/local/bin/7zz",
            "/usr/local/bin/7z",
            "/usr/bin/7zz",
            "/usr/bin/7z"
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) || FileManager.default.fileExists(atPath: candidate) {
                cachedPath = candidate
                return candidate
            }
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["7zz"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    cachedPath = str
                    return str
                }
            }
        }
        
        return nil
    }
}

// MARK: - Subprocess Executor

//
//


/// Safe asynchronous subprocess execution and pipe draining service.
public final class SubprocessExecutor: Sendable {
    public static let shared = SubprocessExecutor()
    private init() {}
    
    /// Synchronously executes a subprocess streaming stdout/stderr line-by-line.
    public func executeProcess(
        executablePath: String,
        arguments: [String],
        currentDirectory: String? = nil,
        progressRegexPattern: String? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let dir = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        
        let pipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        defer { try? fileHandle.close() }
        
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput?(text)
        }
        
        try process.run()
        process.waitUntilExit()
        fileHandle.readabilityHandler = nil
        
        return process.terminationStatus
    }
    
    /// Asynchronously executes a subprocess and returns exit code and captured text output.
    public func executeAsync(
        executablePath: String,
        arguments: [String],
        currentDirectory: String? = nil
    ) async throws -> (exitCode: Int32, output: String) {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            if let dir = currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }
            let pipe = Pipe()
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, text)
        }.value
    }
}

// MARK: - Temp CleanUp Manager

//
//


/// Centralized temporary directory cleanup manager.
public final class TempDirectoryCleanUpManager: Sendable {
    public static let shared = TempDirectoryCleanUpManager()
    
    private init() {}
    
    /// Cleans up transient temporary directories generated across operations (`ttzip_*`, `pwd_test_*`, `measure_*`).
    public func cleanupAllTemporaryDirectories() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        guard let items = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        for item in items {
            let lowerName = item.lastPathComponent.lowercased()
            if lowerName.hasPrefix("ttzip") ||
               lowerName.hasPrefix("ttzipedit_") ||
               lowerName.hasPrefix("ttzip_edit_") ||
               lowerName.hasPrefix("pwd_test") ||
               lowerName.hasPrefix("tt_") ||
               lowerName.hasPrefix("measure_") ||
               lowerName.hasPrefix("dest_") ||
               lowerName.hasPrefix("joined_") ||
               lowerName.hasPrefix("warmup_") ||
               lowerName.hasPrefix("iter_") ||
               lowerName.hasPrefix("arc_") ||
               lowerName.hasPrefix("sample_") ||
               lowerName.hasPrefix("huge_") ||
               lowerName.hasPrefix("ditto_") ||
               lowerName.hasPrefix("7zz_") ||
               lowerName.hasPrefix("pigz_") ||
               lowerName.hasPrefix("libdeflate_") ||
               lowerName.hasPrefix("zstd_") ||
               lowerName.hasPrefix("bz2_") ||
               lowerName.hasPrefix("xz_") ||
               lowerName.hasPrefix("lz_") ||
               lowerName.hasPrefix("lz4_") ||
               lowerName.hasPrefix("br_") ||
               lowerName.hasPrefix("lrz_") ||
               lowerName.hasPrefix("inspect_") ||
               lowerName.hasPrefix("repair_") ||
               lowerName.contains("exhaustivedatasetcache") {
                try? fileManager.removeItem(at: item)
            }
        }
    }
}
