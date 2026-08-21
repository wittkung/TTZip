// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Differential Manifest Verifier

/// 5-dimension manifest differential verifier.
public enum DifferentialManifestVerifier: Sendable {
    
    /// Compares TTZip output manifest with reference oracle output manifest.
    public static func compare(
        ttzip: FileTreeManifest,
        oracle: FileTreeManifest,
        format: ArchiveCompressionFormat,
        oracleName: String
    ) -> DifferentialTestReport {
        var divergenceErrors: [String] = []
        var hexDiffOutput: String? = nil
        
        let ttzipKeys = Set(ttzip.entries.keys)
        let oracleKeys = Set(oracle.entries.keys)
        
        // 1. Missing entries
        let missingKeys = oracleKeys.subtracting(ttzipKeys).sorted()
        for key in missingKeys {
            let oracleEntry = oracle.entries[key]!
            divergenceErrors.append("Missing entry in TTZip output: '\(key)' (oracle type: \(oracleEntry.entryType.rawValue), size: \(oracleEntry.byteSize)B)")
        }
        
        // 2. Extra entries
        let extraKeys = ttzipKeys.subtracting(oracleKeys).sorted()
        for key in extraKeys {
            let ttzipEntry = ttzip.entries[key]!
            divergenceErrors.append("Unexpected extra entry in TTZip output: '\(key)' (ttzip type: \(ttzipEntry.entryType.rawValue), size: \(ttzipEntry.byteSize)B)")
        }
        
        // 3. 5-dimension comparison across common entries
        let commonKeys = ttzipKeys.intersection(oracleKeys).sorted()
        for key in commonKeys {
            let ttzipEntry = ttzip.entries[key]!
            let oracleEntry = oracle.entries[key]!
            
            // Dimension 1: Entry type
            if ttzipEntry.entryType != oracleEntry.entryType {
                divergenceErrors.append("Entry '\(key)' type mismatch: TTZip is \(ttzipEntry.entryType.rawValue), Oracle is \(oracleEntry.entryType.rawValue)")
                continue
            }
            
            // Dimension 2: File size & SHA-256
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
            
            // Dimension 3: Symlink target
            if ttzipEntry.entryType == .symbolicLink {
                if ttzipEntry.symlinkTarget != oracleEntry.symlinkTarget {
                    divergenceErrors.append("Entry '\(key)' symlink target mismatch: TTZip target='\(ttzipEntry.symlinkTarget ?? "nil")', Oracle target='\(oracleEntry.symlinkTarget ?? "nil")'")
                }
            }
            
            // Dimension 4: POSIX permissions
            if format == .tar {
                if ttzipEntry.posixMode != oracleEntry.posixMode {
                    divergenceErrors.append("Entry '\(key)' POSIX permission mismatch: TTZip=0o\(String(ttzipEntry.posixMode, radix: 8)), Oracle=0o\(String(oracleEntry.posixMode, radix: 8))")
                }
            } else {
                // For ZIP and 7Z containers, check executable bit parity across cross-platform oracles
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
