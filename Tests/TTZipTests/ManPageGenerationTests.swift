// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ManPageGenerationTests: XCTestCase {
    
    func testCanonical12MdocSectionsPresence() {
        let man = ManPageGenerator.generateManPage()
        
        // Preamble
        XCTAssertTrue(man.contains(".Dd August 17, 2026"))
        XCTAssertTrue(man.contains(".Dt TTZIP-CLI 1"))
        XCTAssertTrue(man.contains(".Os macOS Sonoma+"))
        
        // Section Headers
        XCTAssertTrue(man.contains(".Sh NAME"))
        XCTAssertTrue(man.contains(".Nm ttzip-cli"))
        XCTAssertTrue(man.contains(".Sh SYNOPSIS"))
        XCTAssertTrue(man.contains(".Sh DESCRIPTION"))
        XCTAssertTrue(man.contains(".Sh COMMANDS"))
        XCTAssertTrue(man.contains(".Sh OPTIONS"))
        XCTAssertTrue(man.contains(".Sh SUPPORTED FORMATS"))
        XCTAssertTrue(man.contains(".Sh EXAMPLES"))
        XCTAssertTrue(man.contains(".Sh ENVIRONMENT"))
        XCTAssertTrue(man.contains(".Sh EXIT STATUS"))
        XCTAssertTrue(man.contains(".Sh STANDARDS"))
        XCTAssertTrue(man.contains(".Sh AUTHORS"))
    }
    
    func testMdocSubcommandAndOptionCompleteness() {
        let man = ManPageGenerator.generateManPage()
        
        // Subcommands
        XCTAssertTrue(man.contains(".It Cm archive"))
        XCTAssertTrue(man.contains(".It Cm extract"))
        XCTAssertTrue(man.contains(".It Cm list"))
        XCTAssertTrue(man.contains(".It Cm cat"))
        XCTAssertTrue(man.contains(".It Cm bench"))
        XCTAssertTrue(man.contains(".It Cm test"))
        
        // Exit Statuses
        XCTAssertTrue(man.contains(".It Sy 0"))
        XCTAssertTrue(man.contains(".It Sy 64"))
        XCTAssertTrue(man.contains(".It Sy 141"))
    }
    
    func testMandocLintValidationIfAvailable() throws {
        let mandocPath: String
        if FileManager.default.fileExists(atPath: "/usr/bin/mandoc") {
            mandocPath = "/usr/bin/mandoc"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/mandoc") {
            mandocPath = "/usr/local/bin/mandoc"
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/mandoc") {
            mandocPath = "/opt/homebrew/bin/mandoc"
        } else {
            throw XCTSkip("mandoc utility is not installed in standard system paths.")
        }
        
        let man = ManPageGenerator.generateManPage()
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip-cli.1")
        try man.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mandocPath)
        process.arguments = ["-Tlint", tmpFile.path]
        
        let errPipe = Pipe()
        process.standardError = errPipe
        
        try process.run()
        process.waitUntilExit()
        
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        
        // mandoc -Tlint returns 0 for clean syntax (or style notices)
        XCTAssertTrue(process.terminationStatus == 0 || !errStr.contains("FATAL"), "mandoc -Tlint must not report fatal syntax errors: \(errStr)")
    }
}
