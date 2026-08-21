// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-level engine for embedding, detecting, and restoring archives using Reed-Solomon Recovery Records.
///
/// Fully delegates file-level streaming generation and in-place repair to Rust C-ABI.
public final class ArchiveRecoveryRecordEngine: @unchecked Sendable {
    public static let shared = ArchiveRecoveryRecordEngine()

    public static let magicHeader: [UInt8] = [0x54, 0x54, 0x5A, 0x52] // "TTZR"
    public static let magicFooter: [UInt8] = [0x54, 0x54, 0x52, 0x43] // "TTRC"

    private init() {}

    /// Appends a transparent Reed-Solomon recovery record trailer to an archive file streamingly (<4MB RAM).
    @discardableResult
    public func appendRecoveryRecord(
        to archivePath: String,
        redundancyPercent: Double = 5.0,
        sliceSize: Int = 65536
    ) throws -> RecoveryRecordPayload {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        var dataSlices: Int = 0
        var paritySlices: Int = 0
        var protectedLen: UInt64 = 0
        var rootHashBytes = [UInt8](repeating: 0, count: 32)

        let status = archivePath.withCString { cPath in
            rootHashBytes.withUnsafeMutableBufferPointer { hashBuf in
                ttzip_rust_rs_append_recovery_record_file(
                    cPath,
                    redundancyPercent,
                    sliceSize,
                    &dataSlices,
                    &paritySlices,
                    &protectedLen,
                    hashBuf.baseAddress
                )
            }
        }

        guard status == 0 else {
            if status == -2 {
                throw ArchiveError.fileNotFound
            } else if status == -1 {
                throw ArchiveError.invalidFormat
            } else {
                throw ArchiveError.readFailed(code: status)
            }
        }

        let rootHex = rootHashBytes.map { String(format: "%02x", $0) }.joined()
        let actualPercent = dataSlices > 0 ? (Double(paritySlices) / Double(dataSlices)) * 100.0 : redundancyPercent

        return RecoveryRecordPayload(
            recoveryPercent: actualPercent,
            sliceSizeBytes: sliceSize,
            dataSlicesCount: dataSlices,
            paritySlicesCount: paritySlices,
            protectedPayloadLength: Int64(protectedLen),
            rootChecksum: rootHex,
            eccAlgorithm: "cauchy_rs_gf16"
        )
    }

    /// Inspects and parses recovery record metadata if present at the end of the archive.
    public func inspectRecoveryRecord(archivePath: String) -> RecoveryRecordPayload? {
        guard FileManager.default.fileExists(atPath: archivePath) else {
            return nil
        }

        var sliceSize: Int = 0
        var dataSlices: Int = 0
        var paritySlices: Int = 0
        var protectedLen: UInt64 = 0
        var rootHashBytes = [UInt8](repeating: 0, count: 32)
        var hasRecord: Bool = false

        let status = archivePath.withCString { cPath in
            rootHashBytes.withUnsafeMutableBufferPointer { hashBuf in
                ttzip_rust_rs_inspect_recovery_record_file(
                    cPath,
                    &sliceSize,
                    &dataSlices,
                    &paritySlices,
                    &protectedLen,
                    hashBuf.baseAddress,
                    &hasRecord
                )
            }
        }

        guard status == 0, hasRecord else {
            return nil
        }

        let rootHex = rootHashBytes.map { String(format: "%02x", $0) }.joined()
        let percent = dataSlices > 0 ? (Double(paritySlices) / Double(dataSlices)) * 100.0 : 5.0

        return RecoveryRecordPayload(
            recoveryPercent: percent,
            sliceSizeBytes: sliceSize,
            dataSlicesCount: dataSlices,
            paritySlicesCount: paritySlices,
            protectedPayloadLength: Int64(protectedLen),
            rootChecksum: rootHex,
            eccAlgorithm: "cauchy_rs_gf16"
        )
    }

    /// Verifies and performs streaming in-place self-healing restoration on a corrupted archive file.
    public func repairArchive(archivePath: String) throws -> Bool {
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        var repaired: Bool = false
        let status = archivePath.withCString { cPath in
            ttzip_rust_rs_repair_archive_streaming(cPath, &repaired)
        }

        guard status == 0 else {
            return false
        }
        return repaired
    }
}
