// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// High-performance lock-free throughput rate formatting engine.
public enum ThroughputFormatter {
    
    /// Formats throughput rate in MB/s with locale-sensitive decimal formatting.
    public static func format(mbPerSec: Double, language: AppLanguage = .en) -> String {
        guard mbPerSec >= 0 else { return "0.0 MB/s" }
        
        let formattedVal: String
        if mbPerSec >= 10000.0 {
            formattedVal = String(format: "%.0f", mbPerSec)
        } else if mbPerSec >= 100.0 {
            formattedVal = String(format: "%.1f", mbPerSec)
        } else {
            formattedVal = String(format: "%.2f", mbPerSec)
        }
        
        let localizedVal: String
        switch language {
        case .de, .fr, .es:
            localizedVal = formattedVal.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            localizedVal = formattedVal
        }
        
        return "\(localizedVal) MB/s"
    }
}
