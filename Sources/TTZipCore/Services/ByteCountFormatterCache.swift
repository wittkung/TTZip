// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Thread-safe ByteCountFormatter cache service delegating to the Flyweight provider.
public enum ByteCountFormatterCache {
    public static func string(fromByteCount byteCount: Int64) -> String {
        return ByteCountFormatterFlyweight.shared.string(fromByteCount: byteCount)
    }
}
