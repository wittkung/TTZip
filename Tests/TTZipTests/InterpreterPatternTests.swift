import XCTest
@testable import TTZipCore

final class InterpreterPatternTests: XCTestCase {
    
    // MARK: - 1. Lexer 词法分析测试
    
    func testLexerTokenizationBasic() throws {
        let query = "ext:pdf AND size:>50MB AND NOT name:*secret*"
        let lexer = ArchiveFilterDSLLexer(input: query)
        let tokens = try lexer.tokenize()
        
        XCTAssertEqual(tokens.count, 13)
        XCTAssertEqual(tokens[0], .identifier("ext"))
        XCTAssertEqual(tokens[1], .colon)
        XCTAssertEqual(tokens[2], .identifier("pdf"))
        XCTAssertEqual(tokens[3], .and)
        XCTAssertEqual(tokens[4], .identifier("size"))
        XCTAssertEqual(tokens[5], .colon)
        XCTAssertEqual(tokens[6], .greaterThan)
        XCTAssertEqual(tokens[7], .identifier("50MB"))
        XCTAssertEqual(tokens[8], .and)
        XCTAssertEqual(tokens[9], .not)
        XCTAssertEqual(tokens[10], .identifier("name"))
        XCTAssertEqual(tokens[11], .colon)
        XCTAssertEqual(tokens[12], .identifier("*secret*"))
    }
    
    func testLexerQuotedStringsAndOperators() throws {
        let query = "(ext:zip OR ext:7z) AND name:\"confidential plan.pdf\""
        let lexer = ArchiveFilterDSLLexer(input: query)
        let tokens = try lexer.tokenize()
        
        XCTAssertTrue(tokens.contains(.leftParen))
        XCTAssertTrue(tokens.contains(.rightParen))
        XCTAssertTrue(tokens.contains(.or))
        XCTAssertTrue(tokens.contains(.stringLiteral("confidential plan.pdf")))
    }
    
    // MARK: - 2. 终结符表达式求值测试
    
    func testExtensionExpressionSingleAndMultiple() {
        let singleExtExpr = ExtensionExpression(extensions: ["pdf"])
        let multiExtExpr = ExtensionExpression(extensions: ["jpg", "png", "webp"])
        
        let pdfEntry = ArchiveEntry(path: "/docs/report.pdf", uncompressedSize: 1024, isDirectory: false)
        let pngEntry = ArchiveEntry(path: "/images/photo.PNG", uncompressedSize: 2048, isDirectory: false)
        let txtEntry = ArchiveEntry(path: "/notes/todo.txt", uncompressedSize: 512, isDirectory: false)
        
        XCTAssertTrue(singleExtExpr.evaluate(entry: pdfEntry))
        XCTAssertFalse(singleExtExpr.evaluate(entry: pngEntry))
        
        XCTAssertTrue(multiExtExpr.evaluate(entry: pngEntry))
        XCTAssertFalse(multiExtExpr.evaluate(entry: txtEntry))
    }
    
    func testFilenameGlobExpressionWildcards() {
        let globExpr1 = FilenameGlobExpression(pattern: "*report*")
        let globExpr2 = FilenameGlobExpression(pattern: "draft_?.docx")
        
        let entry1 = ArchiveEntry(path: "/docs/annual_report_2026.pdf", uncompressedSize: 100, isDirectory: false)
        let entry2 = ArchiveEntry(path: "/docs/draft_1.docx", uncompressedSize: 100, isDirectory: false)
        let entry3 = ArchiveEntry(path: "/docs/draft_12.docx", uncompressedSize: 100, isDirectory: false)
        
        XCTAssertTrue(globExpr1.evaluate(entry: entry1))
        XCTAssertFalse(globExpr1.evaluate(entry: entry2))
        
        XCTAssertTrue(globExpr2.evaluate(entry: entry2))
        XCTAssertFalse(globExpr2.evaluate(entry: entry3)) // draft_12 有两个字符，? 只匹配一个
    }
    
    func testSizeExpressionUnitsAndOperators() {
        let size50MB = SizeExpression(sizeString: "50MB", operatorType: .greaterThan)!
        let size1GB = SizeExpression(sizeString: "1GB", operatorType: .lessThanOrEqual)!
        
        let smallEntry = ArchiveEntry(path: "/small.zip", uncompressedSize: 10 * 1024 * 1024, isDirectory: false) // 10MB
        let largeEntry = ArchiveEntry(path: "/large.zip", uncompressedSize: 100 * 1024 * 1024, isDirectory: false) // 100MB
        let hugeEntry = ArchiveEntry(path: "/huge.zip", uncompressedSize: 2 * 1024 * 1024 * 1024, isDirectory: false) // 2GB
        
        XCTAssertFalse(size50MB.evaluate(entry: smallEntry))
        XCTAssertTrue(size50MB.evaluate(entry: largeEntry))
        
        XCTAssertTrue(size1GB.evaluate(entry: largeEntry))
        XCTAssertFalse(size1GB.evaluate(entry: hugeEntry))
    }
    
    func testDateRangeExpressionRelativeTimes() {
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-3 * 86400)
        let fortyDaysAgo = now.addingTimeInterval(-40 * 86400)
        
        let recentEntry = ArchiveEntry(path: "/recent.pdf", uncompressedSize: 100, isDirectory: false, modificationDate: threeDaysAgo)
        let oldEntry = ArchiveEntry(path: "/old.pdf", uncompressedSize: 100, isDirectory: false, modificationDate: fortyDaysAgo)
        
        let dateWithin7Days = DateRangeExpression(dateSpec: "7d", operatorType: .lessThan, referenceDate: now)!
        let dateOlderThan30Days = DateRangeExpression(dateSpec: "30d", operatorType: .greaterThan, referenceDate: now)!
        
        XCTAssertTrue(dateWithin7Days.evaluate(entry: recentEntry))
        XCTAssertFalse(dateWithin7Days.evaluate(entry: oldEntry))
        
        XCTAssertFalse(dateOlderThan30Days.evaluate(entry: recentEntry))
        XCTAssertTrue(dateOlderThan30Days.evaluate(entry: oldEntry))
    }
    
    // MARK: - 3. 非终结符逻辑求值测试
    
    func testAndExpressionShortCircuit() {
        let left = MatchNoneExpression()
        let right = MatchAllExpression()
        
        let andExpr = AndExpression(left: left, right: right)
        let entry = ArchiveEntry(path: "/test.txt", uncompressedSize: 10, isDirectory: false)
        
        XCTAssertFalse(andExpr.evaluate(entry: entry))
    }
    
    func testOrExpressionShortCircuit() {
        let left = MatchAllExpression()
        let right = MatchNoneExpression()
        
        let orExpr = OrExpression(left: left, right: right)
        let entry = ArchiveEntry(path: "/test.txt", uncompressedSize: 10, isDirectory: false)
        
        XCTAssertTrue(orExpr.evaluate(entry: entry))
    }
    
    func testNotExpressionInversion() {
        let all = MatchAllExpression()
        let notExpr = NotExpression(operand: all)
        let entry = ArchiveEntry(path: "/test.txt", uncompressedSize: 10, isDirectory: false)
        
        XCTAssertFalse(notExpr.evaluate(entry: entry))
    }
    
    // MARK: - 4. 复杂 AST 树构建与完整语法求解
    
    func testComplexNestedBooleanLogicQuery() throws {
        let query = "(ext:pdf OR ext:docx) AND size:>10MB AND NOT name:*draft*"
        let ast = try ArchiveFilterDSLInterpreter.parse(query)
        
        let validPdf = ArchiveEntry(
            path: "/work/final_report.pdf",
            uncompressedSize: 20 * 1024 * 1024,
            isDirectory: false
        )
        let draftDocx = ArchiveEntry(
            path: "/work/draft_notes.docx",
            uncompressedSize: 15 * 1024 * 1024,
            isDirectory: false
        )
        let smallPdf = ArchiveEntry(
            path: "/work/summary.pdf",
            uncompressedSize: 2 * 1024 * 1024,
            isDirectory: false
        )
        
        XCTAssertTrue(ast.evaluate(entry: validPdf))
        XCTAssertFalse(ast.evaluate(entry: draftDocx)) // 因为符合 name:*draft* 被 NOT 排除
        XCTAssertFalse(ast.evaluate(entry: smallPdf)) // 因为 size <= 10MB 被排除
    }
    
    func testImplicitAndParsing() throws {
        let query = "ext:zip size:>5MB"
        let ast = try ArchiveFilterDSLInterpreter.parse(query)
        
        let targetEntry = ArchiveEntry(path: "/archive.zip", uncompressedSize: 10 * 1024 * 1024, isDirectory: false)
        let smallZip = ArchiveEntry(path: "/archive.zip", uncompressedSize: 1 * 1024 * 1024, isDirectory: false)
        
        XCTAssertTrue(ast.evaluate(entry: targetEntry))
        XCTAssertFalse(ast.evaluate(entry: smallZip))
    }
    
    // MARK: - 5. 语法错误捕获与 Safe Fallback
    
    func testParserSyntaxErrorThrowing() {
        let invalidQuery = "ext:pdf AND ("
        XCTAssertThrowsError(try ArchiveFilterDSLInterpreter.parse(invalidQuery)) { error in
            XCTAssertTrue(error is DSLParseError)
        }
    }
    
    func testSafeFallbackMechanism() {
        let malformedQuery = "ext: AND ( size:>"
        let fallbackAST = ArchiveFilterDSLInterpreter.parseOrFallback(malformedQuery)
        
        let matchingEntry = ArchiveEntry(path: "some_file.txt", uncompressedSize: 10, isDirectory: false)
        // 应该自动转换为 FilenameGlobExpression，不会发生任何 Runtime Exception 或 Crash
        XCTAssertNoThrow(_ = fallbackAST.evaluate(entry: matchingEntry))
    }
    
    // MARK: - 6. ArchiveFilterOptions 集成测试
    
    func testArchiveFilterOptionsMatchesWithDSL() {
        let options = ArchiveFilterOptions(skipMacJunk: true, skipGitDirectory: true)
        
        let normalEntry = ArchiveEntry(path: "/project/src/main.swift", uncompressedSize: 500, isDirectory: false)
        let macJunkEntry = ArchiveEntry(path: "/project/.DS_Store", uncompressedSize: 6148, isDirectory: false)
        let gitEntry = ArchiveEntry(path: "/project/.git/HEAD", uncompressedSize: 23, isDirectory: false)
        
        let dslQuery = "ext:swift"
        
        XCTAssertTrue(options.matches(entry: normalEntry, dslQuery: dslQuery))
        XCTAssertFalse(options.matches(entry: macJunkEntry, dslQuery: dslQuery))
        XCTAssertFalse(options.matches(entry: gitEntry, dslQuery: dslQuery))
    }
    
    // MARK: - 7. 100+ 高并发线程 AST 求值线程安全测试
    
    @MainActor
    func testHighConcurrency100ThreadsASTEvaluationSafety() throws {
        let query = "(ext:pdf OR ext:jpg,png) AND size:>1MB AND NOT name:*tmp*"
        let ast = try ArchiveFilterDSLInterpreter.parse(query)
        
        let expectation = expectation(description: "100 Concurrent Threads Evaluation")
        expectation.expectedFulfillmentCount = 100
        
        let entries: [ArchiveEntry] = (0..<1000).map { i in
            let pathStr = "/files/file_\(i).\(i % 2 == 0 ? "pdf" : "tmp")"
            let sizeVal: Int64 = Int64(i + 1) * Int64(102400)
            return ArchiveEntry(
                path: pathStr,
                uncompressedSize: sizeVal,
                isDirectory: false
            )
        }
        
        for threadId in 0..<100 {
            DispatchQueue.global(qos: .userInitiated).async {
                for i in 0..<entries.count {
                    let entry = entries[(i + threadId) % entries.count]
                    _ = ast.evaluate(entry: entry)
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0)
    }
    
    // MARK: - 8. 10,000 高容量条目性能基准测试
    
    func testPerformanceASTEvaluationHighVolume() throws {
        let query = "(ext:zip OR ext:7z OR ext:tar) AND size:>50MB AND modified:<30d"
        let ast = try ArchiveFilterDSLInterpreter.parse(query)
        
        let now = Date()
        let entries: [ArchiveEntry] = (0..<10000).map { i -> ArchiveEntry in
            let pathStr = "/archive_\(i).zip"
            let sizeVal: Int64 = Int64(i) * Int64(10485760)
            let modDate = now.addingTimeInterval(-Double(i * 3600))
            return ArchiveEntry(
                path: pathStr,
                uncompressedSize: sizeVal,
                isDirectory: false,
                modificationDate: modDate
            )
        }
        
        measure {
            var matchCount = 0
            for entry in entries {
                if ast.evaluate(entry: entry) {
                    matchCount += 1
                }
            }
            XCTAssertGreaterThan(matchCount, 0)
        }
    }
}
