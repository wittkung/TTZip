// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Pipeline assembler and orchestrator for archive pre-flight validation rules.
public final class ArchiveValidationPipeline: @unchecked Sendable {
    private var handlers: [ArchiveValidationHandlerProtocol]
    private let lock = NSLock()
    
    public init(handlers: [ArchiveValidationHandlerProtocol] = []) {
        self.handlers = handlers
    }
    
    /// Dynamically appends a validation handler to the pipeline.
    @discardableResult
    public func addHandler(_ handler: ArchiveValidationHandlerProtocol) -> ArchiveValidationPipeline {
        lock.lock()
        defer { lock.unlock() }
        if !handlers.contains(where: { $0 === handler }) {
            handlers.append(handler)
        }
        return self
    }
    
    /// Removes all configured handlers.
    public func clearHandlers() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }
    
    /// Returns the number of configured handlers in the pipeline.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return handlers.count
    }
    
    /// Executes all handlers sequentially against the provided context.
    public func validate(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        lock.lock()
        let pipelineHandlers = self.handlers
        lock.unlock()
        
        guard !pipelineHandlers.isEmpty else {
            return .success
        }
        
        for handler in pipelineHandlers {
            let result = try handler.process(context: context)
            if !result.isSuccess {
                return result
            }
        }
        
        return .success
    }
    
    /// Validates context and throws `ArchiveValidationError` upon failure.
    public func validateOrThrow(context: ArchiveValidationContext) throws {
        let result = try validate(context: context)
        if case .failure(let error) = result {
            throw error
        }
    }
    
    // MARK: - Pre-configured Pipeline Builders
    
    private static let _cachedCompressPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedExtractPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ArchiveHeaderMagicHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedInspectPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ArchiveHeaderMagicHandler(),
        ZipSlipSecurityHandler(),
        LicenseGatekeeperHandler()
    ])
    
    private static let _cachedRepairPipeline = ArchiveValidationPipeline(handlers: [
        FileExistenceHandler(),
        ZipSlipSecurityHandler(),
        DiskSpaceHandler(),
        LicenseGatekeeperHandler()
    ])
    
    /// Builds default pre-flight validation pipeline for compression operations.
    @inline(__always)
    public static func buildDefaultCompressPipeline() -> ArchiveValidationPipeline {
        return _cachedCompressPipeline
    }
    
    /// Builds default pre-flight validation pipeline for extraction operations.
    @inline(__always)
    public static func buildDefaultExtractPipeline() -> ArchiveValidationPipeline {
        return _cachedExtractPipeline
    }
    
    /// Builds default pre-flight validation pipeline for inspection operations.
    @inline(__always)
    public static func buildDefaultInspectPipeline() -> ArchiveValidationPipeline {
        return _cachedInspectPipeline
    }
    
    /// Builds default pre-flight validation pipeline for repair operations.
    @inline(__always)
    public static func buildDefaultRepairPipeline() -> ArchiveValidationPipeline {
        return _cachedRepairPipeline
    }
}
