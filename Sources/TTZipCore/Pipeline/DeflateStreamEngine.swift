// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - DeflateStreamEngine

/// High-level facade for streaming Deflate transformations.
public enum DeflateStreamEngine: Sendable {
    
    /// In-memory one-shot compression.
    public static func compress(
        data: Data,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let compressor = try DeflateStreamCompressor(config: config)
        var result = try compressor.compress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !compressor.isFinished {
            let tail = try compressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// In-memory one-shot decompression.
    public static func decompress(
        data: Data,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
        var result = try decompressor.decompress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !decompressor.isFinished {
            let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// Asynchronous streaming compression pipeline (`AsyncSequence` -> `AsyncThrowingStream`).
    public static func compressStream<S: AsyncSequence>(
        _ sequence: S,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let compressor = try DeflateStreamCompressor(config: config)
                    defer { compressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let compressedChunk = try compressor.compress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !compressedChunk.isEmpty {
                            continuation.yield(compressedChunk)
                        }
                    }
                    
                    let tail = try compressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    /// Asynchronous streaming decompression pipeline (`AsyncSequence` -> `AsyncThrowingStream`).
    public static func decompressStream<S: AsyncSequence>(
        _ sequence: S,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
                    defer { decompressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let decompressedChunk = try decompressor.decompress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !decompressedChunk.isEmpty {
                            continuation.yield(decompressedChunk)
                        }
                    }
                    
                    let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
