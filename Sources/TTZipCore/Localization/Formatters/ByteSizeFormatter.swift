// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Storage capacity formatting standard.
public enum ByteSizeStandard: Sendable {
    /// International decimal SI standard (1 KB = 1000 B, 1 MB = 1000 KB, macOS default).
    case metricSI
    /// International binary IEC standard (1 KiB = 1024 B, 1 MiB = 1024 KiB).
    case binaryIEC
}

/// Zero-heap-allocation byte capacity formatting engine.
public enum ByteSizeFormatter {
    
    private static let metricUnits = ["B", "KB", "MB", "GB", "TB", "PB"]
    private static let binaryUnits = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    
    /// Formats byte count according to standard and localized decimal conventions.
    public static func format(bytes: Int64, style: ByteSizeStandard = .metricSI, language: AppLanguage = .en) -> String {
        guard bytes >= 0 else { return "0 B" }
        if bytes < 1000 && style == .metricSI { return "\(bytes) B" }
        if bytes < 1024 && style == .binaryIEC { return "\(bytes) B" }
        
        let base: Double = (style == .metricSI) ? 1000.0 : 1024.0
        let units = (style == .metricSI) ? metricUnits : binaryUnits
        
        var val = Double(bytes)
        var unitIdx = 0
        
        while val >= base && unitIdx < units.count - 1 {
            val /= base
            unitIdx += 1
        }
        
        let formattedVal = String(format: "%.1f", val)
        let localizedVal = formatDecimalString(formattedVal, for: language)
        return "\(localizedVal) \(units[unitIdx])"
    }
    
    private static func formatDecimalString(_ str: String, for language: AppLanguage) -> String {
        switch language {
        case .de, .fr, .es:
            return str.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            return str
        }
    }
}
