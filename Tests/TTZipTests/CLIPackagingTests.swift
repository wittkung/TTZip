// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class CLIPackagingTests: XCTestCase {
    
    func testPackagingScriptExistsAndIsExecutable() {
        let scriptPath = "scripts/package_cli_release.sh"
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: scriptPath))
        XCTAssertTrue(fm.isExecutableFile(atPath: scriptPath))
    }
    
    func testHomebrewFormulaSyntaxAndDirectives() throws {
        let formulaPath = "Formula/ttzip-cli.rb"
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: formulaPath))
        
        let content = try String(contentsOfFile: formulaPath, encoding: .utf8)
        XCTAssertTrue(content.contains("class TtzipCli < Formula"))
        XCTAssertTrue(content.contains("desc \"High-performance native archive and compression CLI utility for macOS\""))
        XCTAssertTrue(content.contains("license :cannot_be_redistributed"))
        XCTAssertTrue(content.contains("bin.install \"bin/ttzip-cli\""))
        XCTAssertTrue(content.contains("man1.install \"share/man/man1/ttzip-cli.1\""))
        XCTAssertTrue(content.contains("zsh_completion.install \"share/zsh/site-functions/_ttzip-cli\""))
        XCTAssertTrue(content.contains("bash_completion.install \"share/bash-completion/completions/ttzip-cli\""))
        XCTAssertTrue(content.contains("fish_completion.install \"share/fish/vendor_completions.d/ttzip-cli.fish\""))
        XCTAssertTrue(content.contains("test do"))
    }
    
    func testCLIPackageManifestSerialization() throws {
        let manifest = CLIPackageManifest(
            version: "1.0.0",
            tarballName: "ttzip-cli-v1.0.0-darwin-universal.tar.gz",
            tarballPath: "/tmp/ttzip-cli-v1.0.0-darwin-universal.tar.gz",
            tarballByteSize: 15_420_100,
            sha256Checksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            machOArchitectures: ["arm64", "x86_64"],
            manPageIncluded: true,
            completionsIncluded: ["zsh", "bash", "fish", "nushell"],
            formulaPath: "Formula/ttzip-cli.rb"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CLIPackageManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.version, "1.0.0")
        XCTAssertEqual(decoded.machOArchitectures, ["arm64", "x86_64"])
    }
}
