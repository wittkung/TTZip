import XCTest
@testable import TTZipCore

final class CLIPOSIXStandardTests: XCTestCase {
    
    // MARK: - 1. POSIX 参数解析器规范测试
    
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
    
    // MARK: - 2. POSIX Sysexits 退出代码测试
    
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
    
    // MARK: - 3. 流式管道与规范生成器测试
    
    func testStreamPipeIdentification() {
        XCTAssertTrue(StreamPipeAdapter.isStandardStream("-"))
        XCTAssertFalse(StreamPipeAdapter.isStandardStream("regular_file.zip"))
    }
    
    func testShellCompletionsAndManPageGeneration() {
        let zsh = CLICommandSpec.generateZshCompletion()
        XCTAssertTrue(zsh.contains("#compdef ttzip-cli"))
        XCTAssertTrue(zsh.contains("archive"))
        XCTAssertTrue(zsh.contains("extract"))
        
        let bash = CLICommandSpec.generateBashCompletion()
        XCTAssertTrue(bash.contains("_ttzip_cli_completions"))
        
        let man = CLICommandSpec.generateManPage()
        XCTAssertTrue(man.contains(".Dt TTZIP-CLI 1"))
        XCTAssertTrue(man.contains(".Sh NAME"))
    }
}
