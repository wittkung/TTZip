// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit
import TTZipCore

/// Dispatcher responsible for classifying sanitized path destinations and routing navigation state within TTZip.
public final class DestinationDispatcher {
    
    /// Classifies the given filesystem path into a strongly-typed `PathResolutionResult`.
    ///
    /// - Parameters:
    ///   - path: The target POSIX path.
    ///   - rawInput: Optional original raw user input string (defaults to `path`).
    /// - Returns: A `PathResolutionResult` containing destination type, existence, and metadata.
    public static func classify(path: String, rawInput: String? = nil) -> PathResolutionResult {
        let raw = rawInput ?? path
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        let url = URL(fileURLWithPath: path)
        
        if exists {
            if isDir.boolValue {
                return PathResolutionResult(
                    rawInput: raw,
                    sanitizedPath: path,
                    destinationType: .directory,
                    exists: true,
                    isDirectory: true,
                    isArchive: false,
                    errorMessage: nil
                )
            } else {
                let isArchive = ArchiveCompressionFormat.isArchiveExtension(url.pathExtension, path: path)
                if isArchive {
                    return PathResolutionResult(
                        rawInput: raw,
                        sanitizedPath: path,
                        destinationType: .archive,
                        exists: true,
                        isDirectory: false,
                        isArchive: true,
                        errorMessage: nil
                    )
                } else {
                    return PathResolutionResult(
                        rawInput: raw,
                        sanitizedPath: path,
                        destinationType: .file,
                        exists: true,
                        isDirectory: false,
                        isArchive: false,
                        errorMessage: nil
                    )
                }
            }
        } else {
            return PathResolutionResult(
                rawInput: raw,
                sanitizedPath: path,
                destinationType: .notFound,
                exists: false,
                isDirectory: false,
                isArchive: false,
                errorMessage: "Path does not exist: \(path)"
            )
        }
    }
    
    /// Classifies the given file URL into a `PathResolutionResult`.
    public static func classify(url: URL, rawInput: String? = nil) -> PathResolutionResult {
        return classify(path: url.path, rawInput: rawInput ?? url.path)
    }
    
    /// Dispatches the evaluated `PathResolutionResult` to the target `AppViewState`.
    ///
    /// - Parameters:
    ///   - result: The resolution outcome.
    ///   - appViewState: The application view state to mutate upon successful resolution.
    /// - Returns: `true` if navigation/selection was successfully dispatched; `false` otherwise.
    @discardableResult
    @MainActor
    public static func dispatch(result: PathResolutionResult, appViewState: AppViewState) -> Bool {
        let url = URL(fileURLWithPath: result.sanitizedPath)
        switch result.destinationType {
        case .directory:
            RootFolderAccessManager.shared.ensureAccess(for: url, promptIfMissing: true)
            appViewState.currentDirectory = url
            appViewState.selectedDiskItem = nil
            return true
            
        case .archive:
            appViewState.openArchiveAsFolder(url: url)
            return true
            
        case .file:
            appViewState.currentDirectory = url.deletingLastPathComponent()
            appViewState.selectedDiskItem = DiskItemInfo(url: url)
            return true
            
        case .notFound:
            return false
            
        case .permissionRequired:
            let granted = RootFolderAccessManager.shared.ensureAccess(for: url, promptIfMissing: true)
            if granted {
                let reclassified = classify(path: result.sanitizedPath, rawInput: result.rawInput)
                if reclassified.destinationType != .notFound && reclassified.destinationType != .permissionRequired {
                    return dispatch(result: reclassified, appViewState: appViewState)
                }
            }
            return false
        }
    }
    
    /// Classifies and immediately dispatches the target path to `AppViewState`.
    @discardableResult
    @MainActor
    public static func dispatch(path: String, appViewState: AppViewState) -> Bool {
        let result = classify(path: path)
        return dispatch(result: result, appViewState: appViewState)
    }
    
    /// Backward-compatible alias for `dispatch(path:appViewState:)`.
    @discardableResult
    @MainActor
    public static func directDispatch(path: String, appViewState: AppViewState) -> Bool {
        return dispatch(path: path, appViewState: appViewState)
    }
}
