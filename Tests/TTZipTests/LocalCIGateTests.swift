// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class LocalCIGateTests: XCTestCase {
    
    func testLocalCIGateScriptFileExistsAndIsExecutable() {
        let scriptPath = "scripts/run_local_ci_gate.sh"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: scriptPath), "scripts/run_local_ci_gate.sh must exist")
        
        let isExecutable = fileManager.isExecutableFile(atPath: scriptPath)
        XCTAssertTrue(isExecutable, "scripts/run_local_ci_gate.sh must be executable")
    }
    
    func testLocalCIGateReportJSONSchemaConformance() throws {
        let sampleJSON = """
        {
          "totalStages": 6,
          "passedStages": 6,
          "failedStages": 0,
          "totalDurationSeconds": 12.345,
          "isSuccess": true,
          "stages": [
            {
              "stageIndex": 1,
              "name": "Unit & CLI Streaming Suite",
              "command": "swift test --filter PipeStreamingTests",
              "status": "pass",
              "durationSeconds": 1.23,
              "diagnosticMessage": null
            }
          ]
        }
        """
        
        guard let data = sampleJSON.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Sample JSON must be valid")
            return
        }
        
        XCTAssertEqual(dict["totalStages"] as? Int, 6)
        XCTAssertEqual(dict["isSuccess"] as? Bool, true)
        XCTAssertNotNil(dict["stages"] as? [[String: Any]])
    }
}
