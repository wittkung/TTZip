// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive chunk model passed across producer-consumer streaming pipelines.
public struct ArchiveDataChunk: Sendable, Equatable, Identifiable {
    public var id: Int64 { chunkID }
    public let chunkID: Int64
    public let offset: Int64
    public let data: Data
    public let isEOF: Bool
    public let crc32: UInt32?
    public let metadata: [String: String]

    public init(
        chunkID: Int64,
        offset: Int64,
        data: Data,
        isEOF: Bool = false,
        crc32: UInt32? = nil,
        metadata: [String: String] = [:]
    ) {
        self.chunkID = chunkID
        self.offset = offset
        self.data = data
        self.isEOF = isEOF
        self.crc32 = crc32
        self.metadata = metadata
    }

    /// Factory generating an EOF terminal chunk.
    public static func eof(chunkID: Int64 = -1) -> ArchiveDataChunk {
        return ArchiveDataChunk(
            chunkID: chunkID,
            offset: -1,
            data: Data(),
            isEOF: true
        )
    }
}

/// Asynchronous producer interface protocol.
public protocol AsyncProducerProtocol: Sendable {
    /// Generates next chunk in data stream, returning nil or EOF chunk when done.
    func produce() async throws -> ArchiveDataChunk?
}

/// Asynchronous consumer interface protocol.
public protocol AsyncConsumerProtocol: Sendable {
    /// Consumes and processes a chunk from data stream.
    func consume(_ chunk: ArchiveDataChunk) async throws
}
