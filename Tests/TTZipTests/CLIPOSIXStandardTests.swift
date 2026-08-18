// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CLIPOSIXStandardTests: XCTestCase {
    
    // MARK: - 1. POSIX
    
    func testPOSIXLongOptionsAndInlineValues() {
        let args = ["archive", "out.tar.zst", "src/", "--format=tar.zst", "--level=3", "--dry-run", "--json", "--threads=8", "--lang=zh-Hans"]
        let res = POSIXCLIArgumentParser.parse(args: args)
        
        XCTAssertEqual(res.command, .archive)
        XCTAssertEqual(res.options.format, "tar.zst")
        XCTAssertEqual(res.options.level, "3")
        XCTAssertTrue(res.options.dryRun)
        XCTAssertTrue(res.options.jsonOutput)
        XCTAssertEqual(res.options.threads, 8)
        XCTAssertEqual(res.options.language, "zh-Hans")
        XCTAssertEqual(res.options.positionals, ["out.tar.zst", "src/"])
    }
    
    func testPOSIXShortFlagClustersAndValues() {
        let args = ["extract", "archive.zip", "-yq", "-o", "./dist", "-p", "secret123"]
        let res = POSIXCLIArgumentParser.parse(args: args)
        
        XCTAssertEqual(res.command, .extract)
        XCTAssertTrue(res.options.assumeYes)
        XCTAssertEqual(res.options.verbosity, -1) // -q
        XCTAssertEqual(res.options.outputPath, "./dist")
        XCTAssertEqual(res.options.password, "secret123")
        XCTAssertEqual(res.options.positionals, ["archive.zip"])
    }
    
    func testPOSIXDoubleDashDelimiter() {
        let args = ["archive", "out.zip", "--", "-file-with-dash.txt", "--not-a-flag.md"]
        let res = POSIXCLIArgumentParser.parse(args: args)
        
        XCTAssertEqual(res.command, .archive)
        XCTAssertEqual(res.options.positionals, ["out.zip", "-file-with-dash.txt", "--not-a-flag.md"])
    }
    
    func testPOSIXFeature069LongOptions() {
        let args = [
            "archive", "out.tar.zst", "src/",
            "--exclude=*.log", "--exclude", "build/*",
            "--include=*.swift", "--include", "*.h",
            "--strip-components=2",
            "--exclude-vcs",
            "--no-mac-metadata",
            "--flatten",
            "--files-from=manifest.txt",
            "--null",
            "--password-file=secret.txt",
            "--overwrite=backup",
            "--depth=3",
            "--force",
            "--no-pager"
        ]
        let res = POSIXCLIArgumentParser.parse(args: args)
        
        XCTAssertEqual(res.command, .archive)
        XCTAssertEqual(res.options.excludePatterns, ["*.log", "build/*"])
        XCTAssertEqual(res.options.includePatterns, ["*.swift", "*.h"])
        XCTAssertEqual(res.options.stripComponents, 2)
        XCTAssertTrue(res.options.excludeVCS)
        XCTAssertTrue(res.options.noMacMetadata)
        XCTAssertTrue(res.options.flattenPaths)
        XCTAssertEqual(res.options.filesFromPath, "manifest.txt")
        XCTAssertTrue(res.options.nullDelimiter)
        XCTAssertEqual(res.options.passwordFile, "secret.txt")
        XCTAssertEqual(res.options.overwritePolicy, "backup")
        XCTAssertEqual(res.options.treeDepth, 3)
        XCTAssertTrue(res.options.force)
        XCTAssertTrue(res.options.noPager)
        XCTAssertEqual(res.options.positionals, ["out.tar.zst", "src/"])
    }
    
    func testPOSIXFeature069ShortFlags() {
        let args = [
            "extract", "bundle.zip",
            "-j0nf",
            "-x", "*.tmp",
            "-i", "*.json",
            "-T", "file_list.txt",
            "-P", "pwd.txt",
            "-d", "4"
        ]
        let res = POSIXCLIArgumentParser.parse(args: args)
        
        XCTAssertEqual(res.command, .extract)
        XCTAssertTrue(res.options.flattenPaths) // -j
        XCTAssertTrue(res.options.nullDelimiter) // -0
        XCTAssertEqual(res.options.overwritePolicy, "never") // -n
        XCTAssertTrue(res.options.force) // -f
        XCTAssertEqual(res.options.excludePatterns, ["*.tmp"]) // -x
        XCTAssertEqual(res.options.includePatterns, ["*.json"]) // -i
        XCTAssertEqual(res.options.filesFromPath, "file_list.txt") // -T
        XCTAssertEqual(res.options.passwordFile, "pwd.txt") // -P
        XCTAssertEqual(res.options.treeDepth, 4) // -d
        XCTAssertEqual(res.options.positionals, ["bundle.zip"])
    }
    
    func testPOSIXMacMetadataFlagToggle() {
        let args1 = ["archive", "out.zip", "src/", "--no-mac-metadata"]
        let res1 = POSIXCLIArgumentParser.parse(args: args1)
        XCTAssertTrue(res1.options.noMacMetadata)
        
        let args2 = ["archive", "out.zip", "src/", "--no-mac-metadata", "--mac-metadata"]
        let res2 = POSIXCLIArgumentParser.parse(args: args2)
        XCTAssertFalse(res2.options.noMacMetadata)
        
        let args3 = ["extract", "out.zip", "--no-clobber"]
        let res3 = POSIXCLIArgumentParser.parse(args: args3)
        XCTAssertEqual(res3.options.overwritePolicy, "never")
        
        let args4 = ["extract", "out.zip", "--junk-paths"]
        let res4 = POSIXCLIArgumentParser.parse(args: args4)
        XCTAssertTrue(res4.options.flattenPaths)
    }
    
    // MARK: - 2. POSIX Sysexits
    
    func testSysexitsStandardCodes() {
        XCTAssertEqual(CLIExitCode.ok.rawValue, 0)
        XCTAssertEqual(CLIExitCode.usage.rawValue, 64)
        XCTAssertEqual(CLIExitCode.dataError.rawValue, 65)
        XCTAssertEqual(CLIExitCode.noInput.rawValue, 66)
        XCTAssertEqual(CLIExitCode.unavailable.rawValue, 69)
        XCTAssertEqual(CLIExitCode.software.rawValue, 70)
        XCTAssertEqual(CLIExitCode.cantCreate.rawValue, 73)
        XCTAssertEqual(CLIExitCode.ioError.rawValue, 74)
        XCTAssertEqual(CLIExitCode.noPermission.rawValue, 77)
        XCTAssertEqual(CLIExitCode.sigint.rawValue, 130)
    }
    
    // MARK: - 3.
    
    func testStreamPipeIdentification() {
        XCTAssertTrue(StreamPipeAdapter.isStandardStream("-"))
        XCTAssertFalse(StreamPipeAdapter.isStandardStream("regular_file.zip"))
    }
    
    func testShellCompletionsAndManPageGeneration() {
        let zsh = CLICommandSpec.generateZshCompletion()
        XCTAssertTrue(zsh.contains("#compdef ttzip-cli"))
        XCTAssertTrue(zsh.contains("archive"))
        XCTAssertTrue(zsh.contains("extract"))
        XCTAssertTrue(zsh.contains("cat"))
        XCTAssertTrue(zsh.contains("tree"))
        XCTAssertTrue(zsh.contains("hash"))
        XCTAssertTrue(zsh.contains("delete"))
        XCTAssertTrue(zsh.contains("update"))
        
        let bash = CLICommandSpec.generateBashCompletion()
        XCTAssertTrue(bash.contains("_ttzip_cli_completions"))
        XCTAssertTrue(bash.contains("cat"))
        XCTAssertTrue(bash.contains("tree"))
        XCTAssertTrue(bash.contains("hash"))
        XCTAssertTrue(bash.contains("delete"))
        XCTAssertTrue(bash.contains("update"))
        
        let fish = CLICommandSpec.generateFishCompletion()
        XCTAssertTrue(fish.contains("# Fish completion for ttzip-cli"))
        XCTAssertTrue(fish.contains("complete -c ttzip-cli"))
        XCTAssertTrue(fish.contains("cat"))
        XCTAssertTrue(fish.contains("tree"))
        XCTAssertTrue(fish.contains("hash"))
        XCTAssertTrue(fish.contains("delete"))
        XCTAssertTrue(fish.contains("update"))
        
        let nushell = CLICommandSpec.generateNushellCompletion()
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli archive\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli cat\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli tree\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli hash\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli delete\""))
        XCTAssertTrue(nushell.contains("export extern \"ttzip-cli update\""))
        
        let man = CLICommandSpec.generateManPage()
        XCTAssertTrue(man.contains(".Dt TTZIP-CLI 1"))
        XCTAssertTrue(man.contains(".Sh NAME"))
        XCTAssertTrue(man.contains("cat"))
        XCTAssertTrue(man.contains("tree"))
        XCTAssertTrue(man.contains("hash"))
        XCTAssertTrue(man.contains("delete"))
        XCTAssertTrue(man.contains("update"))
    }
}
