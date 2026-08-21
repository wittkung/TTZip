// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - Differential Manifest Verifier

/// 5-dimension manifest differential verifier, directly delegating to hardware-accelerated Safe Rust C-ABI.
public enum DifferentialManifestVerifier: Sendable {
    
    /// Compares TTZip output manifest with reference oracle output manifest across 5 dimensions.
    public static func compare(
        ttzip: FileTreeManifest,
        oracle: FileTreeManifest,
        format: ArchiveCompressionFormat,
        oracleName: String
    ) -> DifferentialTestReport {
        let isTar = (format == .tar || format == .tarGz || format == .tarBz2 || format == .tarXz || format == .tarZst)
        
        if let ttzipData = try? JSONEncoder().encode(ttzip),
           let ttzipJson = String(data: ttzipData, encoding: .utf8),
           let oracleData = try? JSONEncoder().encode(oracle),
           let oracleJson = String(data: oracleData, encoding: .utf8) {
            
            var outReportPtr: UnsafeMutablePointer<CChar>? = nil
            var isPassed: Bool = false
            let formatName = format.fileExtension.replacingOccurrences(of: ".", with: "")
            
            let status = ttzipJson.withCString { cTTZip in
                oracleJson.withCString { cOracle in
                    oracleName.withCString { cOracleName in
                        formatName.withCString { cFormatName in
                            ttzip_rust_differential_compare_manifests(
                                cTTZip,
                                cOracle,
                                isTar,
                                cOracleName,
                                cFormatName,
                                &outReportPtr,
                                &isPassed
                            )
                        }
                    }
                }
            }
            
            if status == TTZIP_STATUS_OK, let validPtr = outReportPtr {
                defer { ttzip_rust_free_differential_string(validPtr) }
                let reportJson = String(cString: validPtr)
                if let reportData = reportJson.data(using: .utf8),
                   let report = try? JSONDecoder().decode(DifferentialTestReport.self, from: reportData) {
                    return report
                }
            }
        }
        
        // Swift native comparison fallback
        return fallbackCompare(
            ttzip: ttzip,
            oracle: oracle,
            format: format,
            oracleName: oracleName,
            isTar: isTar
        )
    }
    
    private static func fallbackCompare(
        ttzip: FileTreeManifest,
        oracle: FileTreeManifest,
        format: ArchiveCompressionFormat,
        oracleName: String,
        isTar: Bool
    ) -> DifferentialTestReport {
        var divergenceErrors: [String] = []
        var hexDiffOutput: String? = nil
        
        let ttzipKeys = Set(ttzip.entries.keys)
        let oracleKeys = Set(oracle.entries.keys)
        
        for key in oracleKeys.subtracting(ttzipKeys).sorted() {
            let oracleEntry = oracle.entries[key]!
            divergenceErrors.append("Missing entry in TTZip output: '\(key)' (oracle type: \(oracleEntry.entryType.rawValue), size: \(oracleEntry.byteSize)B)")
        }
        
        for key in ttzipKeys.subtracting(oracleKeys).sorted() {
            let ttzipEntry = ttzip.entries[key]!
            divergenceErrors.append("Unexpected extra entry in TTZip output: '\(key)' (ttzip type: \(ttzipEntry.entryType.rawValue), size: \(ttzipEntry.byteSize)B)")
        }
        
        for key in ttzipKeys.intersection(oracleKeys).sorted() {
            let ttzipEntry = ttzip.entries[key]!
            let oracleEntry = oracle.entries[key]!
            
            if ttzipEntry.entryType != oracleEntry.entryType {
                divergenceErrors.append("Entry '\(key)' type mismatch: TTZip is \(ttzipEntry.entryType.rawValue), Oracle is \(oracleEntry.entryType.rawValue)")
                continue
            }
            
            if ttzipEntry.entryType == .regularFile {
                if ttzipEntry.byteSize != oracleEntry.byteSize {
                    divergenceErrors.append("Entry '\(key)' byte size mismatch: TTZip=\(ttzipEntry.byteSize)B, Oracle=\(oracleEntry.byteSize)B")
                }
                
                if ttzipEntry.sha256Checksum != oracleEntry.sha256Checksum {
                    divergenceErrors.append("Entry '\(key)' SHA-256 checksum mismatch: TTZip=\(ttzipEntry.sha256Checksum), Oracle=\(oracleEntry.sha256Checksum)")
                    
                    if hexDiffOutput == nil {
                        let ttzipFilePath = (ttzip.rootDirectory as NSString).appendingPathComponent(key)
                        let oracleFilePath = (oracle.rootDirectory as NSString).appendingPathComponent(key)
                        if let ttzipData = try? Data(contentsOf: URL(fileURLWithPath: ttzipFilePath), options: .mappedIfSafe),
                           let oracleData = try? Data(contentsOf: URL(fileURLWithPath: oracleFilePath), options: .mappedIfSafe) {
                            hexDiffOutput = FastHexDiffEngine.generateDiff(expected: oracleData, actual: ttzipData)
                        }
                    }
                }
            }
            
            if ttzipEntry.entryType == .symbolicLink {
                if ttzipEntry.symlinkTarget != oracleEntry.symlinkTarget {
                    divergenceErrors.append("Entry '\(key)' symlink target mismatch: TTZip target='\(ttzipEntry.symlinkTarget ?? "nil")', Oracle target='\(oracleEntry.symlinkTarget ?? "nil")'")
                }
            }
            
            if isTar {
                if ttzipEntry.posixMode != oracleEntry.posixMode {
                    divergenceErrors.append("Entry '\(key)' POSIX permission mismatch: TTZip=0o\(String(ttzipEntry.posixMode, radix: 8)), Oracle=0o\(String(oracleEntry.posixMode, radix: 8))")
                }
            } else {
                if (ttzipEntry.posixMode & 0o111) != (oracleEntry.posixMode & 0o111) {
                    divergenceErrors.append("Entry '\(key)' executable permission bit mismatch: TTZip=0o\(String(ttzipEntry.posixMode, radix: 8)), Oracle=0o\(String(oracleEntry.posixMode, radix: 8))")
                }
            }
        }
        
        let isPassed = divergenceErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracleName,
            isPassed: isPassed,
            ttzipManifest: ttzip,
            oracleManifest: oracle,
            divergenceErrors: divergenceErrors,
            hexDiffOutput: hexDiffOutput
        )
    }
}
