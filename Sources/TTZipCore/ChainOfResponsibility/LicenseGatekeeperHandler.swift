// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Commercial license gatekeeper validation handler.
public final class LicenseGatekeeperHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let licenseManager: LicenseManager
    
    public init(licenseManager: LicenseManager = .shared, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.licenseManager = licenseManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        // 1. Split-volume feature gating
        if context.options.isSplit || (context.options.splitVolumeSizeBytes != nil && context.options.splitVolumeSizeBytes! > 0) {
            if !licenseManager.canUseFeature(.volumeSplit) {
                return .failure(.licenseRequired(feature: "Volume Splitting"))
            }
        }
        
        // 2. AES-256 encryption feature gating
        if context.options.isEncrypted || (context.password != nil && !context.password!.isEmpty) {
            if !licenseManager.canUseFeature(.aes256Encryption) {
                return .failure(.licenseRequired(feature: "AES-256 Encryption"))
            }
        }
        
        // 3. Ultra compression level feature gating
        if context.options.compressionLevel == .ultra {
            if !licenseManager.canUseFeature(.ultraCompression) {
                return .failure(.licenseRequired(feature: "Ultra Compression Level"))
            }
        }
        
        return .success
    }
}
