// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Thread-safe global JSONEncoder and JSONDecoder cache service avoiding redundant instantiations in hot serialization paths.
public final class JSONCoderCache: @unchecked Sendable {
    public static let shared = JSONCoderCache()
    
    public let encoder = JSONEncoder()
    public let prettyEncoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        return enc
    }()
    public let decoder = JSONDecoder()
    
    private init() {}
}
