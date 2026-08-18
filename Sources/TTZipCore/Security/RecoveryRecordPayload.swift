// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Forward Error Correction (FEC) Recovery Record metadata payload.
public struct RecoveryRecordPayload: Sendable, Codable, Equatable {
    public let recoveryPercent: Double
    public let sliceSizeBytes: Int
    public let dataSlicesCount: Int
    public let paritySlicesCount: Int
    public let protectedPayloadLength: Int64
    public let rootChecksum: String
    public let eccAlgorithm: String

    public init(
        recoveryPercent: Double,
        sliceSizeBytes: Int,
        dataSlicesCount: Int,
        paritySlicesCount: Int,
        protectedPayloadLength: Int64,
        rootChecksum: String,
        eccAlgorithm: String = "cauchy_rs_gf16"
    ) {
        self.recoveryPercent = recoveryPercent
        self.sliceSizeBytes = sliceSizeBytes
        self.dataSlicesCount = dataSlicesCount
        self.paritySlicesCount = paritySlicesCount
        self.protectedPayloadLength = protectedPayloadLength
        self.rootChecksum = rootChecksum
        self.eccAlgorithm = eccAlgorithm
    }
}
