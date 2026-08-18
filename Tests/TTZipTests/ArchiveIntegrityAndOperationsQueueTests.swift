// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveIntegrityAndOperationsQueueTests: XCTestCase {

    // MARK: - Task T004: ArchiveIntegrityReport Tests

    func testArchiveIntegrityReportInitializationAndProperties() {
        let corruptedDetail = CorruptedEntryDetail(
            entryPath: "images/corrupt.png",
            errorType: .crc32Mismatch,
            expectedChecksum: "0x12345678",
            actualChecksum: "0x87654321",
            diagnosticMessage: "Decompressed data checksum does not match central directory CRC32."
        )

        let report = ArchiveIntegrityReport(
            archivePath: "/Users/test/data/archive.7z",
            totalEntriesCount: 100,
            verifiedEntriesCount: 99,
            corruptedEntriesCount: 1,
            overallStatus: .corrupted,
            verificationDurationSeconds: 1.45,
            averageThroughputMBs: 3450.5,
            corruptedEntries: [corruptedDetail]
        )

        XCTAssertEqual(report.archivePath, "/Users/test/data/archive.7z")
        XCTAssertEqual(report.totalEntriesCount, 100)
        XCTAssertEqual(report.verifiedEntriesCount, 99)
        XCTAssertEqual(report.corruptedEntriesCount, 1)
        XCTAssertEqual(report.overallStatus, .corrupted)
        XCTAssertEqual(report.verificationDurationSeconds, 1.45)
        XCTAssertEqual(report.averageThroughputMBs, 3450.5)
        XCTAssertEqual(report.corruptedEntries.count, 1)
        XCTAssertEqual(report.corruptedEntries[0].entryPath, "images/corrupt.png")
        XCTAssertEqual(report.corruptedEntries[0].errorType, .crc32Mismatch)
        XCTAssertEqual(report.corruptedEntries[0].expectedChecksum, "0x12345678")
        XCTAssertEqual(report.corruptedEntries[0].actualChecksum, "0x87654321")
        XCTAssertEqual(report.corruptedEntries[0].diagnosticMessage, "Decompressed data checksum does not match central directory CRC32.")
        XCTAssertFalse(report.isClean)
    }

    func testArchiveIntegrityCleanReport() {
        let cleanReport = ArchiveIntegrityReport(
            archivePath: "/Users/test/valid.zip",
            totalEntriesCount: 50,
            verifiedEntriesCount: 50,
            corruptedEntriesCount: 0,
            overallStatus: .passed,
            verificationDurationSeconds: 0.12,
            averageThroughputMBs: 8500.0,
            corruptedEntries: []
        )

        XCTAssertTrue(cleanReport.isClean)
        XCTAssertEqual(cleanReport.overallStatus, .passed)
        XCTAssertEqual(cleanReport.corruptedEntriesCount, 0)
    }

    func testIntegrityStatusAndErrorTypeEnumValues() {
        let allStatuses = IntegrityStatus.allCases.map(\.rawValue)
        XCTAssertEqual(allStatuses, ["passed", "corrupted", "unreadable", "encrypted_missing_key"])

        let allErrors = IntegrityCorruptionErrorType.allCases.map(\.rawValue)
        XCTAssertEqual(allErrors, ["crc32_mismatch", "header_damaged", "block_truncated", "invalid_dictionary"])
    }

    func testArchiveIntegrityReportCodableJSONSchemaConformance() throws {
        let detail = CorruptedEntryDetail(
            entryPath: "payload.bin",
            errorType: .blockTruncated,
            expectedChecksum: "0xaabbccdd",
            actualChecksum: "0x00000000",
            diagnosticMessage: "Premature EOF encountered while streaming block."
        )

        let report = ArchiveIntegrityReport(
            archivePath: "/tmp/sample.zip",
            totalEntriesCount: 10,
            verifiedEntriesCount: 9,
            corruptedEntriesCount: 1,
            overallStatus: .corrupted,
            verificationDurationSeconds: 0.55,
            averageThroughputMBs: 1200.0,
            corruptedEntries: [detail]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(report)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to deserialize JSON dictionary")
            return
        }

        XCTAssertEqual(json["archivePath"] as? String, "/tmp/sample.zip")
        XCTAssertEqual(json["totalEntriesCount"] as? Int, 10)
        XCTAssertEqual(json["verifiedEntriesCount"] as? Int, 9)
        XCTAssertEqual(json["corruptedEntriesCount"] as? Int, 1)
        XCTAssertEqual(json["overallStatus"] as? String, "corrupted")
        XCTAssertEqual(json["verificationDurationSeconds"] as? Double, 0.55)
        XCTAssertEqual(json["averageThroughputMBs"] as? Double, 1200.0)

        guard let entries = json["corruptedEntries"] as? [[String: Any]], entries.count == 1 else {
            XCTFail("Expected 1 corrupted entry in JSON")
            return
        }

        XCTAssertEqual(entries[0]["entryPath"] as? String, "payload.bin")
        XCTAssertEqual(entries[0]["errorType"] as? String, "block_truncated")
        XCTAssertEqual(entries[0]["expectedChecksum"] as? String, "0xaabbccdd")
        XCTAssertEqual(entries[0]["actualChecksum"] as? String, "0x00000000")
        XCTAssertEqual(entries[0]["diagnosticMessage"] as? String, "Premature EOF encountered while streaming block.")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ArchiveIntegrityReport.self, from: data)
        XCTAssertEqual(decoded, report)
    }

    // MARK: - Task T005: GlobalOperationsQueueModels Tests

    func testQueueOperationTypesAndPriorityEnums() {
        let opTypes = QueueOperationType.allCases.map(\.rawValue)
        XCTAssertEqual(opTypes, ["compress", "extract", "test", "repair", "batch_compress", "batch_extract"])

        let executionStates = ArchiveTaskExecutionState.allCases.map(\.rawValue)
        XCTAssertEqual(executionStates, ["queued", "running", "paused", "completed", "failed", "cancelled"])

        let priorities = QueueTaskPriority.allCases.map(\.rawValue)
        XCTAssertEqual(priorities, ["critical", "userInitiated", "utility", "background"])

        XCTAssertEqual(QueueTaskPriority(priorityLevel: .critical), .critical)
        XCTAssertEqual(QueueTaskPriority(priorityLevel: .userInitiated), .userInitiated)
        XCTAssertEqual(QueueTaskPriority(priorityLevel: .utility), .utility)
        XCTAssertEqual(QueueTaskPriority(priorityLevel: .background), .background)
        XCTAssertEqual(QueueTaskPriority.critical.priorityLevel, .critical)
        XCTAssertEqual(QueueTaskPriority.userInitiated.priorityLevel, .userInitiated)
    }

    func testGlobalOperationsQueueEventCodableJSONSchemaConformance() throws {
        let taskUUID = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        let event = GlobalOperationsQueueEvent(
            taskId: taskUUID,
            taskName: "Photos_Backup.7z",
            operationType: .compress,
            state: .running,
            priority: .userInitiated,
            bytesProcessed: 50_000_000,
            totalBytes: 100_000_000,
            fractionCompleted: 0.5,
            throughputMBs: 4500.0,
            estimatedTimeRemainingSeconds: 0.011,
            errorMessage: nil
        )

        XCTAssertEqual(event.typedOperationType, .compress)
        XCTAssertEqual(event.typedState, .running)
        XCTAssertEqual(event.typedPriority, .userInitiated)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(event)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }

        XCTAssertEqual(json["taskId"] as? String, "12345678-1234-1234-1234-123456789ABC")
        XCTAssertEqual(json["taskName"] as? String, "Photos_Backup.7z")
        XCTAssertEqual(json["operationType"] as? String, "compress")
        XCTAssertEqual(json["state"] as? String, "running")
        XCTAssertEqual(json["priority"] as? String, "userInitiated")
        XCTAssertEqual(json["bytesProcessed"] as? Int64, 50_000_000)
        XCTAssertEqual(json["totalBytes"] as? Int64, 100_000_000)
        XCTAssertEqual(json["fractionCompleted"] as? Double, 0.5)
        XCTAssertEqual(json["throughputMBs"] as? Double, 4500.0)
        XCTAssertEqual(json["estimatedTimeRemainingSeconds"] as? Double, 0.011)
        XCTAssertNil(json["errorMessage"])

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GlobalOperationsQueueEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }

    func testQueuedArchiveOperationLifecycleAndTelemetryConversion() {
        let opId = UUID()
        var operation = QueuedArchiveOperation(
            id: opId,
            name: "Archive.tar.zst",
            operationType: .compress,
            priority: .userInitiated,
            state: .queued,
            bytesProcessed: 0,
            totalBytes: 200_000_000,
            throughputMBs: 0.0
        )

        XCTAssertEqual(operation.fractionCompleted, 0.0)
        XCTAssertEqual(operation.state, .queued)

        // Progress update
        operation.state = .running
        operation.bytesProcessed = 100_000_000
        operation.throughputMBs = 8500.0
        XCTAssertEqual(operation.fractionCompleted, 0.5)

        let event = operation.toTelemetryEvent(estimatedTimeRemaining: 0.012)
        XCTAssertEqual(event.taskId, opId.uuidString)
        XCTAssertEqual(event.taskName, "Archive.tar.zst")
        XCTAssertEqual(event.operationType, "compress")
        XCTAssertEqual(event.state, "running")
        XCTAssertEqual(event.priority, "userInitiated")
        XCTAssertEqual(event.bytesProcessed, 100_000_000)
        XCTAssertEqual(event.totalBytes, 200_000_000)
        XCTAssertEqual(event.fractionCompleted, 0.5)
        XCTAssertEqual(event.throughputMBs, 8500.0)
        XCTAssertEqual(event.estimatedTimeRemainingSeconds, 0.012)
    }
}
