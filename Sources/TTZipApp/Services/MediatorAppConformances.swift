// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public final class CompressModalMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    public let componentId: String = "CompressModalView"
    public var mediator: ArchiveMediatorProtocol?
    
    public init(mediator: ArchiveMediatorProtocol? = ArchiveAppMediator.shared) {
        self.mediator = mediator
        mediator?.register(component: self)
    }
    
    public func receive(event: AppMediatorEvent) {}
    public func receive(event: CoreEngineMediatorEvent) {}
}

public final class ExtractModalMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    public let componentId: String = "ExtractModalView"
    public var mediator: ArchiveMediatorProtocol?
    
    public init(mediator: ArchiveMediatorProtocol? = ArchiveAppMediator.shared) {
        self.mediator = mediator
        mediator?.register(component: self)
    }
    
    public func receive(event: AppMediatorEvent) {}
    public func receive(event: CoreEngineMediatorEvent) {}
}

public final class PasswordPromptMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    public let componentId: String = "PasswordPromptSheetView"
    public var mediator: ArchiveMediatorProtocol?
    
    public init(mediator: ArchiveMediatorProtocol? = ArchiveAppMediator.shared) {
        self.mediator = mediator
        mediator?.register(component: self)
    }
    
    public func receive(event: AppMediatorEvent) {}
    public func receive(event: CoreEngineMediatorEvent) {}
}
