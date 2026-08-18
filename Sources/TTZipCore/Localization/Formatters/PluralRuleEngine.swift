// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unicode CLDR plural categories.
public enum PluralCategory: Sendable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// Evaluator engine for Unicode CLDR plural rules across supported languages.
public enum PluralRuleEngine {
    
    /// Evaluates plural category given item count and language.
    public static func evaluate(count: Int64, language: AppLanguage) -> PluralCategory {
        switch language {
        case .zhHans, .zhHant, .ja:
            return .other
            
        case .en, .de, .es:
            return (count == 1) ? .one : .other
            
        case .fr:
            return (count == 0 || count == 1) ? .one : .other
        }
    }
}
