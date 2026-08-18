// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive validation error cases.
public enum ArchiveValidationError: Error, LocalizedError, Equatable, Sendable {
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case zipSlipDetected(path: String, detail: String)
    case symlinkEscapeDetected(path: String)
    case insufficientDiskSpace(requiredBytes: UInt64, availableBytes: UInt64)
    case invalidHeaderMagic(expected: String, actual: String)
    case licenseRequired(feature: String)
    case custom(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Validation failed: target path does not exist [\(path)]"
        case .fileNotReadable(let path):
            return "Validation failed: target file lacks read permissions [\(path)]"
        case .zipSlipDetected(let path, let detail):
            return "Security violation: Zip Slip / path traversal escape detected [path: \(path), detail: \(detail)]"
        case .symlinkEscapeDetected(let path):
            return "Security violation: symlink escape detected [\(path)]"
        case .insufficientDiskSpace(let required, let available):
            let reqMB = String(format: "%.2f MB", Double(required) / 1024.0 / 1024.0)
            let availMB = String(format: "%.2f MB", Double(available) / 1024.0 / 1024.0)
            return "Validation failed: insufficient disk space (required \(reqMB), available \(availMB))"
        case .invalidHeaderMagic(let expected, let actual):
            return "Validation failed: header magic bytes corrupted or mismatched (expected: \(expected), actual: \(actual))"
        case .licenseRequired(let feature):
            return "License gatekeeper: feature [\(feature)] requires a valid commercial license"
        case .custom(let message):
            return "Validation failed: \(message)"
        }
    }
    
    /// Converts to standard `ArchiveError` for legacy compatibility.
    public var asArchiveError: ArchiveError {
        switch self {
        case .fileNotFound, .fileNotReadable:
            return .fileNotFound
        case .invalidHeaderMagic:
            return .invalidFormat
        case .licenseRequired:
            return .readFailed(code: -403)
        case .zipSlipDetected, .symlinkEscapeDetected:
            return .readFailed(code: -901)
        case .insufficientDiskSpace:
            return .readFailed(code: -902)
        case .custom:
            return .readFailed(code: -999)
        }
    }
}

/// Archive validation result type.
public enum ArchiveValidationResult: Equatable, Sendable {
    case success
    case failure(ArchiveValidationError)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    public var error: ArchiveValidationError? {
        if case .failure(let err) = self { return err }
        return nil
    }
}

/// Chain of Responsibility handler protocol for archive pre-flight validation.
public protocol ArchiveValidationHandlerProtocol: AnyObject, Sendable {
    /// Next handler in the chain.
    var nextHandler: ArchiveValidationHandlerProtocol? { get set }
    
    /// Configures the next handler in the pipeline and returns it for chaining.
    @discardableResult
    func setNext(handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationHandlerProtocol
    
    /// Handles validation dispatch across the pipeline.
    func handle(context: ArchiveValidationContext) throws -> ArchiveValidationResult
    
    /// Executes the concrete validation logic for this handler.
    func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult
}

/// Base class implementation for Chain of Responsibility validation handlers.
open class BaseArchiveValidationHandler: ArchiveValidationHandlerProtocol, @unchecked Sendable {
    private var _nextHandler: ArchiveValidationHandlerProtocol?
    private let lock = NSLock()
    
    public var nextHandler: ArchiveValidationHandlerProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _nextHandler
        }
        set {
            lock.lock()
            _nextHandler = newValue
            lock.unlock()
        }
    }
    
    public init(nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self._nextHandler = nextHandler
    }
    
    @discardableResult
    public func setNext(handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationHandlerProtocol {
        guard handler !== self else { return handler }
        self.nextHandler = handler
        return handler
    }
    
    public func handle(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        let result = try process(context: context)
        guard result.isSuccess else {
            return result
        }
        if let next = nextHandler {
            return try next.handle(context: context)
        }
        return .success
    }
    
    open func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        return .success
    }
}
