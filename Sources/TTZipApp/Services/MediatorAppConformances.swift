import Foundation
import TTZipCore

// MARK: - 【3.8 中介者模式 (Mediator Pattern)】GUI SwiftUI View Class 适配器组件

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
