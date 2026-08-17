// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Release 打包构建配置
public struct CLIPackageConfig: Sendable, Equatable {
    public let version: String
    public let targetArchitecture: TargetArch
    public let stripSymbols: Bool
    public let generateDsym: Bool
    public let outputDirectory: String
    public let homebrewFormulaPath: String
    
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

/// Release 打包产物清册与校验和 (符合 contracts/release_packaging_manifest.json)
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
