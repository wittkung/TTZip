// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Model representing a recently accessed archive file record.
public struct RecentArchiveRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let extensionName: String
    public let date: Date
    
    public init(path: String, date: Date = Date()) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.extensionName = (path as NSString).pathExtension.uppercased()
        self.date = date
    }
}
