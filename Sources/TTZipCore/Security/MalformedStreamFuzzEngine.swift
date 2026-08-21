// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - Deterministic PRNG

/// 64-bit deterministic pseudo-random number generator using the SplitMix64 algorithm.
/// Conforms to Swift's standard `RandomNumberGenerator` protocol for bit-exact reproducibility.
public struct DeterministicPRNG: RandomNumberGenerator, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Fuzz Mutation Configuration & Data Models

/// Configuration for deterministic stream mutation and security fuzzing.
public struct FuzzMutationConfig: Sendable, Equatable, Codable {
    /// Mutation operator enumeration covering realistic corruptions and attack vectors.
    public enum MutationOperator: String, Sendable, CaseIterable, Equatable, Codable {
        case bitFlip = "bit_flip"
        case byteReplace = "byte_replace"
        case corruptMagic = "corrupt_magic"
        case corruptCRC = "corrupt_crc"
        case truncateStream = "truncate_stream"
        case injectZipSlipPath = "zip_slip_path"
        case oversizeHeader = "oversize_header"
        case invalidDictSize = "invalid_dict_size"
        case shuffleChunk = "shuffle_chunk"
        case zeroRange = "zero_range"
    }

    public let seed: UInt64
    public let iterationCount: Int
    public let operators: [MutationOperator]
    public let targetFormat: ArchiveCompressionFormat
    public let crashDumpDirectory: String?

    public init(
        seed: UInt64 = 0x1337_C0DE_F00D,
        iterationCount: Int = 100,
        operators: [MutationOperator] = MutationOperator.allCases,
        targetFormat: ArchiveCompressionFormat = .zip,
        crashDumpDirectory: String? = nil
    ) {
        self.seed = seed
        self.iterationCount = iterationCount
        self.operators = operators
        self.targetFormat = targetFormat
        self.crashDumpDirectory = crashDumpDirectory
    }
}

public typealias MutationOperator = FuzzMutationConfig.MutationOperator

/// Result of a single deterministic fuzzing mutation iteration.
public struct FuzzIterationResult: Sendable, Equatable, Codable {
    public let iteration: Int
    public let seed: UInt64
    public let appliedOperator: FuzzMutationConfig.MutationOperator
    public let originalByteSize: Int
    public let mutatedByteSize: Int
    public let exitCode: Int32
    public let caughtSwiftError: String?
    public let isGracefullyRejected: Bool
    public let reproducerPath: String?

    public init(
        iteration: Int,
        seed: UInt64,
        appliedOperator: FuzzMutationConfig.MutationOperator,
        originalByteSize: Int,
        mutatedByteSize: Int,
        exitCode: Int32,
        caughtSwiftError: String? = nil,
        isGracefullyRejected: Bool,
        reproducerPath: String? = nil
    ) {
        self.iteration = iteration
        self.seed = seed
        self.appliedOperator = appliedOperator
        self.originalByteSize = originalByteSize
        self.mutatedByteSize = mutatedByteSize
        self.exitCode = exitCode
        self.caughtSwiftError = caughtSwiftError
        self.isGracefullyRejected = isGracefullyRejected
        self.reproducerPath = reproducerPath
    }
}

// MARK: - Malformed Stream Fuzz Engine

/// Core engine for generating deterministically mutated byte streams for security & robustness testing.
public enum MalformedStreamFuzzEngine {

    /// Applies a specific mutation operator to the archive data using the provided deterministic PRNG.
    /// - Parameters:
    ///   - data: Original valid archive byte stream.
    ///   - operator: Mutation strategy to apply.
    ///   - prng: Inout deterministic PRNG instance.
    /// - Returns: Corrupted byte stream.
    public static func mutate(
        data: Data,
        operator op: FuzzMutationConfig.MutationOperator,
        prng: inout DeterministicPRNG
    ) -> Data {
        guard !data.isEmpty else { return data }

        let opIndex: UInt32
        switch op {
        case .bitFlip: opIndex = 0
        case .byteReplace: opIndex = 1
        case .corruptMagic: opIndex = 2
        case .corruptCRC: opIndex = 3
        case .truncateStream: opIndex = 4
        case .injectZipSlipPath: opIndex = 5
        case .oversizeHeader: opIndex = 6
        case .invalidDictSize: opIndex = 7
        case .shuffleChunk: opIndex = 8
        case .zeroRange: opIndex = 9
        }

        let maxCap = data.count + 512
        var outBuf = Data(count: maxCap)
        var outLen = 0
        var nextSeed: UInt64 = prng.state

        let status = data.withUnsafeBytes { srcPtr in
            outBuf.withUnsafeMutableBytes { dstPtr in
                ttzip_rust_fuzz_mutate(
                    srcPtr.bindMemory(to: UInt8.self).baseAddress,
                    data.count,
                    opIndex,
                    prng.state,
                    dstPtr.bindMemory(to: UInt8.self).baseAddress,
                    maxCap,
                    &outLen,
                    &nextSeed
                )
            }
        }

        if status == TTZIP_STATUS_OK {
            prng = DeterministicPRNG(seed: nextSeed)
            return outBuf.prefix(outLen)
        }

        return data
    }

    /// Mutates archive data using a random operator from the given configuration.
    public static func mutate(
        data: Data,
        config: FuzzMutationConfig,
        prng: inout DeterministicPRNG
    ) -> (mutatedData: Data, appliedOperator: FuzzMutationConfig.MutationOperator) {
        guard !config.operators.isEmpty else {
            return (data, .bitFlip)
        }
        let opIndex = Int.random(in: 0..<config.operators.count, using: &prng)
        let selectedOp = config.operators[opIndex]
        let mutated = mutate(data: data, operator: selectedOp, prng: &prng)
        return (mutated, selectedOp)
    }

    /// Persists a crashing or anomalous mutated archive to disk as a reproducer fixture.
    @discardableResult
    public static func persistReproducer(
        data: Data,
        iteration: Int,
        seed: UInt64,
        appliedOperator: FuzzMutationConfig.MutationOperator,
        targetFormat: ArchiveCompressionFormat,
        dumpDirectory: String
    ) -> String? {
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: dumpDirectory) {
                try fileManager.createDirectory(atPath: dumpDirectory, withIntermediateDirectories: true)
            }
            let filename = String(
                format: "reproducer_iter%04d_%@_seed%016llx.%@",
                iteration,
                appliedOperator.rawValue,
                seed,
                targetFormat.rawValue
            )
            let destinationPath = (dumpDirectory as NSString).appendingPathComponent(filename)
            try data.write(to: URL(fileURLWithPath: destinationPath))
            return destinationPath
        } catch {
            return nil
        }
    }
}
