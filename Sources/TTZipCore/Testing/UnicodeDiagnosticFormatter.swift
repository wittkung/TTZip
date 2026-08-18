// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unicode scalar expansion and string encoding diagnostic analyzer (aligned with libarchive `strdump` and `_utf8_to_unicode`).
public enum UnicodeDiagnosticFormatter: Sendable {
    
    /// Expands string into hexadecimal Unicode scalar sequences and charset metrics.
    public static func dumpScalars(_ string: String) -> String {
        var scalarHexes: [String] = []
        for scalar in string.unicodeScalars {
            if scalar.value <= 0xFFFF {
                scalarHexes.append(String(format: "%04X", scalar.value))
            } else {
                scalarHexes.append(String(format: "%06X", scalar.value))
            }
        }
        let scalarSeq = scalarHexes.joined(separator: " ")
        return "\"\(escapeNonPrintable(string))\" [\(scalarSeq)] (chars: \(string.count), scalars: \(string.unicodeScalars.count), utf8: \(string.utf8.count)B)"
    }
    
    /// Compares two strings and generates multi-dimensional divergence diagnostic reports.
    public static func analyzeStringMismatch(expected: String, actual: String) -> String {
        if expected.utf8.elementsEqual(actual.utf8) {
            return "Strings are strictly byte-for-byte identical."
        }
        
        var report = "⚠️ [String Mismatch Analysis]\n"
        report += "  Expected : " + dumpScalars(expected) + "\n"
        report += "  Actual   : " + dumpScalars(actual) + "\n"
        
        // APFS NFD (Decomposed) vs NFC (Precomposed) normalization analysis
        let expNFC = (expected as NSString).precomposedStringWithCanonicalMapping
        let actNFC = (actual as NSString).precomposedStringWithCanonicalMapping
        let expNFD = (expected as NSString).decomposedStringWithCanonicalMapping
        let actNFD = (actual as NSString).decomposedStringWithCanonicalMapping
        
        if expNFC.utf8.elementsEqual(actNFC.utf8) || expected == actual {
            report += "  \u{001B}[1;33m💡 [Root Cause Identified]\u{001B}[0m Unicode Normalization mismatch (APFS/HFS+ NFD vs Standard NFC).\n"
            report += "     Expected Form: \(expected.utf8.elementsEqual(expNFD.utf8) ? "NFD (Decomposed)" : "NFC (Precomposed)")\n"
            report += "     Actual Form  : \(actual.utf8.elementsEqual(actNFD.utf8) ? "NFD (Decomposed)" : "NFC (Precomposed)")\n"
        }
        
        return report
    }
    
    /// Escapes non-printable control characters.
    private static func escapeNonPrintable(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x07: result.append("\\a")
            case 0x08: result.append("\\b")
            case 0x09: result.append("\\t")
            case 0x0A: result.append("\\n")
            case 0x0D: result.append("\\r")
            case 0x20...0x7E:
                result.append(Character(scalar))
            default:
                if scalar.value <= 0xFF {
                    result.append(String(format: "\\x%02X", scalar.value))
                } else if scalar.value <= 0xFFFF {
                    result.append(String(format: "\\u%04X", scalar.value))
                } else {
                    result.append(String(format: "\\U%08X", scalar.value))
                }
            }
        }
        return result
    }
}
