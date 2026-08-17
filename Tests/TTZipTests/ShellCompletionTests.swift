// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ShellCompletionTests: XCTestCase {
    
    func testZshCompletionScriptGeneration() {
        let script = ShellCompletionGenerator.generateZsh(binaryName: "ttzip-cli", includeAliases: true)
        
        XCTAssertTrue(script.starts(with: "#compdef ttzip-cli"))
        XCTAssertTrue(script.contains("_arguments -C"))
        XCTAssertTrue(script.contains("archive:Create an archive from source files or directories"))
        XCTAssertTrue(script.contains("extract:Extract files from an archive"))
        XCTAssertTrue(script.contains("list:List contents of an archive"))
        XCTAssertTrue(script.contains("cat:Print decompressed contents of archive entry directly to stdout"))
        XCTAssertTrue(script.contains("bench:Run high-precision CPU/memory codec throughput benchmarks"))
        XCTAssertTrue(script.contains("_ttzip_cli \"$@\""))
    }
    
    func testBashCompletionScriptGeneration() {
        let script = ShellCompletionGenerator.generateBash(binaryName: "ttzip-cli", includeAliases: true)
        
        XCTAssertTrue(script.contains("_ttzip_cli_completions()"))
        XCTAssertTrue(script.contains("complete -F _ttzip_cli_completions ttzip-cli"))
        XCTAssertTrue(script.contains("local commands=\""))
        XCTAssertTrue(script.contains("COMPREPLY=( $(compgen -W"))
        XCTAssertTrue(script.contains("archive"))
        XCTAssertTrue(script.contains("extract"))
    }
    
    func testFishCompletionScriptGeneration() {
        let script = ShellCompletionGenerator.generateFish(binaryName: "ttzip-cli", includeAliases: true)
        
        XCTAssertTrue(script.contains("complete -c ttzip-cli -f"))
        XCTAssertTrue(script.contains("complete -c ttzip-cli -n \"__fish_use_subcommand\" -a \"archive\""))
        XCTAssertTrue(script.contains("complete -c ttzip-cli -n \"__fish_use_subcommand\" -a \"extract\""))
        XCTAssertTrue(script.contains("complete -c ttzip-cli -s h -l help"))
    }
    
    func testNushellCompletionScriptGeneration() {
        let script = ShellCompletionGenerator.generateNushell(binaryName: "ttzip-cli", includeAliases: true)
        
        XCTAssertTrue(script.contains("export extern \"ttzip-cli\" ["))
        XCTAssertTrue(script.contains("export extern \"ttzip-cli archive\" ["))
        XCTAssertTrue(script.contains("export extern \"ttzip-cli extract\" ["))
        XCTAssertTrue(script.contains("--help(-h)"))
    }
    
    func testUnifiedShellTargetDispatcher() {
        for target in ShellTarget.allCases {
            let script = ShellCompletionGenerator.generate(for: target)
            XCTAssertFalse(script.isEmpty, "Shell completion for \(target.rawValue) must not be empty")
            XCTAssertTrue(script.contains("ttzip-cli"))
        }
    }
}
