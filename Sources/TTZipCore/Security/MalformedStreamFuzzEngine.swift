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
        var mutated = data

        switch op {
        case .corruptMagic:
            let flipLen = min(4, mutated.count)
            for i in 0..<flipLen {
                mutated[i] ^= 0xFF
            }

        case .truncateStream:
            if mutated.count <= 2 {
                return Data()
            }
            let minCut = max(1, Int(Double(mutated.count) * 0.1))
            let maxCut = max(minCut + 1, min(mutated.count - 1, Int(Double(mutated.count) * 0.9)))
            let cutPoint = Int.random(in: minCut..<maxCut, using: &prng)
            return mutated.prefix(cutPoint)

        case .corruptCRC:
            if mutated.count >= 18 {
                for i in 14..<18 {
                    mutated[i] ^= 0xFF
                }
            } else {
                let mid = mutated.count / 2
                let end = min(mutated.count, mid + 4)
                for i in mid..<end {
                    mutated[i] ^= 0xFF
                }
            }

        case .bitFlip:
            let byteIndex = Int.random(in: 0..<mutated.count, using: &prng)
            let bitPosition = Int.random(in: 0..<8, using: &prng)
            mutated[byteIndex] ^= (1 << bitPosition)

        case .byteReplace:
            let byteIndex = Int.random(in: 0..<mutated.count, using: &prng)
            let replacement: UInt8 = (prng.next() % 2 == 0) ? 0x00 : 0xFF
            mutated[byteIndex] = replacement

        case .injectZipSlipPath:
            let evilPath = "../../../../../../etc/passwd\0"
            let evilBytes = Array(evilPath.utf8)

            let pkHeader: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
            if let headerOffset = findSignature(in: mutated, signature: pkHeader),
               headerOffset + 30 <= mutated.count {
                let nameLenOffset = headerOffset + 26
                let nameLen = Int(mutated[nameLenOffset]) | (Int(mutated[nameLenOffset + 1]) << 8)
                
                var newBuffer = Data()
                newBuffer.append(mutated.prefix(headerOffset + 26))
                
                let newLen = UInt16(evilBytes.count)
                newBuffer.append(UInt8(newLen & 0xFF))
                newBuffer.append(UInt8((newLen >> 8) & 0xFF))
                
                newBuffer.append(mutated[(headerOffset + 28)..<(headerOffset + 30)])
                newBuffer.append(contentsOf: evilBytes)
                
                let remainingOffset = headerOffset + 30 + nameLen
                if remainingOffset < mutated.count {
                    newBuffer.append(mutated[remainingOffset...])
                }
                return newBuffer
            } else {
                let overwriteLen = min(evilBytes.count, mutated.count)
                for i in 0..<overwriteLen {
                    mutated[i] = evilBytes[i]
                }
            }

        case .oversizeHeader:
            let pkHeader: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
            if let headerOffset = findSignature(in: mutated, signature: pkHeader),
               headerOffset + 26 <= mutated.count {
                for i in 18..<26 {
                    mutated[headerOffset + i] = 0xFF
                }
            } else if mutated.count >= 512 {
                let octalMax = Array("77777777777\0".utf8)
                for i in 0..<min(octalMax.count, 12) {
                    mutated[124 + i] = octalMax[i]
                }
            } else {
                let targetOffset = min(16, max(0, mutated.count - 4))
                for i in 0..<min(4, mutated.count - targetOffset) {
                    mutated[targetOffset + i] = 0xFF
                }
            }

        case .invalidDictSize:
            let sevenZipHeader: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
            let xzHeader: [UInt8] = [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]
            let zstdHeader: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD]

            if findSignature(in: mutated, signature: sevenZipHeader) != nil && mutated.count > 10 {
                mutated[6] = 0xFF
                mutated[7] = 0xFF
            } else if findSignature(in: mutated, signature: xzHeader) != nil && mutated.count > 8 {
                mutated[6] = 0xFF
                mutated[7] = 0xFF
            } else if findSignature(in: mutated, signature: zstdHeader) != nil && mutated.count > 5 {
                mutated[4] = 0xFF
            } else {
                let targetIndex = min(6, mutated.count - 1)
                mutated[targetIndex] = 0xFF
            }
        }

        return mutated
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

    // MARK: - Internal Helpers

    private static func findSignature(in data: Data, signature: [UInt8]) -> Int? {
        guard data.count >= signature.count, !signature.isEmpty else { return nil }
        let maxSearch = min(data.count - signature.count, 4096)
        for i in 0...maxSearch {
            var match = true
            for j in 0..<signature.count {
                if data[i + j] != signature[j] {
                    match = false
                    break
                }
            }
            if match {
                return i
            }
        }
        return nil
    }
}
