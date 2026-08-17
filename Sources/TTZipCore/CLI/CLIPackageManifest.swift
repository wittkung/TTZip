// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Release packaging and compilation configuration parameters.
public struct CLIPackageConfig: Sendable, Equatable {
    /// Semantic release version string.
    public let version: String
    /// Target Mach-O binary architecture.
    public let targetArchitecture: TargetArch
    /// Whether to strip debug symbols from the Mach-O binary.
    public let stripSymbols: Bool
    /// Whether to generate associated `.dSYM` debug bundles.
    public let generateDsym: Bool
    /// Target output artifact directory.
    public let outputDirectory: String
    /// Target Homebrew Formula file path.
    public let homebrewFormulaPath: String
    
    /// Target processor architecture configuration.
    public enum TargetArch: String, Sendable, CaseIterable {
        case universal = "universal"
        case arm64 = "arm64"
        case x86_64 = "x86_64"
    }
    
    public init(
        version: String,
        targetArchitecture: TargetArch = .universal,
        stripSymbols: Bool = true,
        generateDsym: Bool = true,
        outputDirectory: String,
        homebrewFormulaPath: String = "Formula/ttzip-cli.rb"
    ) {
        self.version = version
        self.targetArchitecture = targetArchitecture
        self.stripSymbols = stripSymbols
        self.generateDsym = generateDsym
        self.outputDirectory = outputDirectory
        self.homebrewFormulaPath = homebrewFormulaPath
    }
}

/// Release artifact manifest and cryptographic verification record.
public struct CLIPackageManifest: Sendable, Codable, Equatable {
    public let version: String
    public let tarballName: String
    public let tarballPath: String
    public let tarballByteSize: Int64
    public let sha256Checksum: String
    public let machOArchitectures: [String]
    public let manPageIncluded: Bool
    public let completionsIncluded: [String]
    public let formulaPath: String
    
    public init(
        version: String,
        tarballName: String,
        tarballPath: String,
        tarballByteSize: Int64,
        sha256Checksum: String,
        machOArchitectures: [String],
        manPageIncluded: Bool,
        completionsIncluded: [String],
        formulaPath: String
    ) {
        self.version = version
        self.tarballName = tarballName
        self.tarballPath = tarballPath
        self.tarballByteSize = tarballByteSize
        self.sha256Checksum = sha256Checksum
        self.machOArchitectures = machOArchitectures
        self.manPageIncluded = manPageIncluded
        self.completionsIncluded = completionsIncluded
        self.formulaPath = formulaPath
    }
}
