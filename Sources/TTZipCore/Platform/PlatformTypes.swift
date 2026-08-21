// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Cross-platform path sanitization and normalization analysis outcome.
public struct PlatformPathNormalizationResult: Sendable, Equatable {
    public let originalPath: String
    public let normalizedPath: String
    public let isAbsolute: Bool
    public let isUNCPath: Bool
    public let isLongPath: Bool
    public let containsWindowsReservedDeviceName: Bool
    public let strippedAlternateDataStream: String?
    public let win32FormattedPath: String
    public let hasTraversalAttack: Bool
    
    public init(
        originalPath: String,
        normalizedPath: String,
        isAbsolute: Bool,
        isUNCPath: Bool,
        isLongPath: Bool,
        containsWindowsReservedDeviceName: Bool,
        strippedAlternateDataStream: String? = nil,
        win32FormattedPath: String,
        hasTraversalAttack: Bool = false
    ) {
        self.originalPath = originalPath
        self.normalizedPath = normalizedPath
        self.isAbsolute = isAbsolute
        self.isUNCPath = isUNCPath
        self.isLongPath = isLongPath
        self.containsWindowsReservedDeviceName = containsWindowsReservedDeviceName
        self.strippedAlternateDataStream = strippedAlternateDataStream
        self.win32FormattedPath = win32FormattedPath
        self.hasTraversalAttack = hasTraversalAttack
    }
}

/// Unified cross-platform file system metadata attributes.
public struct PlatformFileAttributes: Sendable, Equatable {
    public let size: Int64
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let creationTimeUnixSec: Int64
    public let modificationTimeUnixSec: Int64
    public let posixPermissions: UInt32
    public let isReadOnly: Bool
    public let isHidden: Bool
    
    public init(
        size: Int64,
        isDirectory: Bool,
        isSymbolicLink: Bool,
        creationTimeUnixSec: Int64,
        modificationTimeUnixSec: Int64,
        posixPermissions: UInt32,
        isReadOnly: Bool,
        isHidden: Bool
    ) {
        self.size = size
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.creationTimeUnixSec = creationTimeUnixSec
        self.modificationTimeUnixSec = modificationTimeUnixSec
        self.posixPermissions = posixPermissions
        self.isReadOnly = isReadOnly
        self.isHidden = isHidden
    }
}

/// Virtual memory mapping descriptor.
public struct PlatformMmapResult: @unchecked Sendable {
    public let pointer: UnsafeRawPointer
    public let size: Int
    private let rawDescriptor: Int32
    
    public init(pointer: UnsafeRawPointer, size: Int, rawDescriptor: Int32) {
        self.pointer = pointer
        self.size = size
        self.rawDescriptor = rawDescriptor
    }
    
    public func unmap() {
        if size > 0 {
            let mutPtr = UnsafeMutableRawPointer(mutating: pointer)
            munmap(mutPtr, size)
        }
        if rawDescriptor >= 0 {
            close(rawDescriptor)
        }
    }
}

/// CPU architecture and SIMD hardware acceleration feature mask.
public struct CPUFeatureSet: Sendable, Equatable {
    public let architecture: String
    public let logicalCores: Int
    public let physicalPageSize: Int
    public let hasARMNeon: Bool
    public let hasARMCrypto: Bool
    public let hasAESNI: Bool
    public let hasAVX2: Bool
    public let hasAVX512: Bool
    public let hasHardwareCRC32: Bool
    
    public init(
        architecture: String,
        logicalCores: Int,
        physicalPageSize: Int,
        hasARMNeon: Bool,
        hasARMCrypto: Bool,
        hasAESNI: Bool,
        hasAVX2: Bool,
        hasAVX512: Bool,
        hasHardwareCRC32: Bool
    ) {
        self.architecture = architecture
        self.logicalCores = logicalCores
        self.physicalPageSize = physicalPageSize
        self.hasARMNeon = hasARMNeon
        self.hasARMCrypto = hasARMCrypto
        self.hasAESNI = hasAESNI
        self.hasAVX2 = hasAVX2
        self.hasAVX512 = hasAVX512
        self.hasHardwareCRC32 = hasHardwareCRC32
    }
}
