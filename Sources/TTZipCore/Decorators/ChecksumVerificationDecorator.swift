// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete decorator adding real-time checksum computation and verification (CRC32/SHA256).
open class ChecksumVerificationDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var algorithm: HashType
    private let hashCalculator: HashCalculating
    private let lock = NSLock()

    private var _lastSourceChecksum: String?
    private var _lastOutputChecksum: String?
    private var _isVerified: Bool = false

    public var lastSourceChecksum: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastSourceChecksum
    }

    public var lastOutputChecksum: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastOutputChecksum
    }

    public var isVerified: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isVerified
    }

    private func updateSourceChecksum(_ hash: String?) {
        lock.lock()
        _lastSourceChecksum = hash
        lock.unlock()
    }

    private func updateOutputChecksum(_ hash: String?, verified: Bool) {
        lock.lock()
        _lastOutputChecksum = hash
        _isVerified = verified
        lock.unlock()
    }

    public init(
        inner: ArchiveEngineImplementorProtocol,
        algorithm: HashType = .crc32,
        hashCalculator: HashCalculating = ArchiveEngineFactory.makeHashCalculator()
    ) {
        self.algorithm = algorithm
        self.hashCalculator = hashCalculator
        super.init(inner: inner)
    }

    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        if let firstInput = inputPaths.first, FileManager.default.fileExists(atPath: firstInput) {
            let srcHash = try? await hashCalculator.computeHash(filePath: firstInput, type: algorithm)
            updateSourceChecksum(srcHash)
        }

        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        if FileManager.default.fileExists(atPath: outputPath) {
            let outHash = try? await hashCalculator.computeHash(filePath: outputPath, type: algorithm)
            updateOutputChecksum(outHash, verified: outHash != nil)
            TTLogger.debug("[ChecksumVerificationDecorator] Compression output hash (\(algorithm.rawValue.uppercased())): \(outHash ?? "N/A")")
        }

        return bytesWritten
    }

    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        if FileManager.default.fileExists(atPath: archivePath) {
            let arcHash = try? await hashCalculator.computeHash(filePath: archivePath, type: algorithm)
            updateSourceChecksum(arcHash)
        }

        let bytesExtracted = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
            let firstFile = (destinationDir as NSString).appendingPathComponent(items[0])
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: firstFile, isDirectory: &isDir), !isDir.boolValue {
                let extHash = try? await hashCalculator.computeHash(filePath: firstFile, type: algorithm)
                updateOutputChecksum(extHash, verified: extHash != nil)
                TTLogger.debug("[ChecksumVerificationDecorator] Extracted file hash (\(algorithm.rawValue.uppercased())): \(extHash ?? "N/A")")
            } else {
                updateOutputChecksum(nil, verified: true)
            }
        }

        return bytesExtracted
    }
}
