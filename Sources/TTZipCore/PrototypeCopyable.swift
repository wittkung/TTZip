// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Prototype Pattern: Standard interface for deep-copying configurations and component state.
public protocol PrototypeCopyable {
    /// Creates and returns an independent cloned copy of the receiver.
    func clone() -> Self
}
