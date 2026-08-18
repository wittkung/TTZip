// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance adapter for Apple UDIF DMG extraction and LZFSE chunk penetration.
public final class DMGVirtualStreamAdapter: Sendable {
    public static let shared = DMGVirtualStreamAdapter()
    
    private init() {}
    
    /// Probes if the target archive is an Apple UDIF DMG file with valid koly trailer.
    public func isUDIFDmg(at archivePath: String) -> Bool {
        return CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            guard let cPath = cPath else { return false }
            return ttzip_dmg_probe(cPath)
        }
    }
    
    /// Extracts an Apple DMG (UDIF with LZFSE, ZLIB, RAW, LZMA chunks) directly into target destination directory.
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true
    ) throws -> Bool {
        // Fast Probe
        guard isUDIFDmg(at: archivePath) else {
            return false
        }
        
        let tempRawImg = FileManager.default.temporaryDirectory
            .appendingPathComponent("dmg_raw_\(UUID().uuidString).img").path
        defer {
            try? FileManager.default.removeItem(atPath: tempRawImg)
        }
        
        // 1. Decompress UDIF LZFSE/ZLIB/RAW chunks to raw disk partition stream
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cSrc in
            CUnsafeBufferAdapter.withCString(tempRawImg) { cDst in
                guard let cSrc = cSrc, let cDst = cDst else { return Int32(TTZIP_ERR_INVALID_PARAM.rawValue) }
                return Int32(ttzip_dmg_decompress_to_raw(cSrc, cDst))
            }
        }
        
        guard status == 0 else {
            TTLogger.debug("[DMGVirtualStreamAdapter] ttzip_dmg_decompress_to_raw failed with status: \(status)")
            return false
        }
        
        // 2. Extract raw partition filesystem (APFS / HFS+ / ISO9660 / FAT) into destination directory
        try FileManager.default.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        
        // Try SevenZipEngine first for APFS/HFS+ file tree extraction
        if let ok = try? SevenZipEngine.shared.extract(archivePath: tempRawImg, destinationDir: destinationDir, password: password), ok {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
            if !items.isEmpty {
                return true
            }
        }
        
        // Fallback to libarchive extraction on raw disk image
        let libarcStatus = CUnsafeBufferAdapter.withCString(tempRawImg) { cRaw in
            CUnsafeBufferAdapter.withCString(destinationDir) { cDest in
                CUnsafeBufferAdapter.withCString(password) { cPwd in
                    guard let cRaw = cRaw, let cDest = cDest else { return Int32(TTZIP_ERR_INVALID_PARAM.rawValue) }
                    return Int32(ttzip_extract_archive_advanced(cRaw, cDest, skipMacJunk, cPwd))
                }
            }
        }
        
        if libarcStatus == 0 {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
            return !items.isEmpty
        }
        
        return false
    }
}
