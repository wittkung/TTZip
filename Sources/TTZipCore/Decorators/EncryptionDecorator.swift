// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete decorator adding transparent password encryption and decryption.
open class EncryptionDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var password: String?

    public init(inner: ArchiveEngineImplementorProtocol, password: String?) {
        self.password = password
        super.init(inner: inner)
    }

    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        guard let pwd = password, !pwd.isEmpty else {
            return try await super.compressStream(
                inputPaths: inputPaths,
                outputPath: outputPath,
                options: options
            )
        }

        var encryptedOptions = options.clone()
        if encryptedOptions.zipOptions.zipEncryptionMethod == "None" {
            encryptedOptions.zipOptions.zipEncryptionMethod = "AES256"
        }
        encryptedOptions.sevenZipOptions.encryptFileNames = true

        TTLogger.debug("[EncryptionDecorator] Applying archive encryption...")
        return try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: encryptedOptions
        )
    }

    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        if let pwd = password, !pwd.isEmpty {
            TTLogger.debug("[EncryptionDecorator] Applying archive decryption...")
        }
        return try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}
